defmodule ExecutionPlane.WebSocket do
  @moduledoc """
  Execution Plane-owned WebSocket connection lifecycle helper.

  Semantic families keep provider-specific frame decoding locally while this
  module owns handshake, receive, ping/pong, timeout, and close behavior.
  """

  @default_receive_timeout 30_000

  @type stream_item ::
          {:frame, {:text, binary()} | {:binary, binary()}}
          | {:close, non_neg_integer() | nil, binary() | nil}
          | {:transport_error, term()}
          | :transport_timeout

  @spec stream(String.t(), list()) ::
          {:ok, %{status: non_neg_integer(), headers: list(), stream: Enumerable.t()}}
          | {:error, term()}
  def stream(url, headers), do: stream(url, headers, [], [])

  @spec stream(String.t(), list(), [binary() | {:text | :binary, binary()}]) ::
          {:ok, %{status: non_neg_integer(), headers: list(), stream: Enumerable.t()}}
          | {:error, term()}
  def stream(url, headers, outbound_frames), do: stream(url, headers, outbound_frames, [])

  @spec stream(String.t(), list(), [binary() | {:text | :binary, binary()}], keyword()) ::
          {:ok, %{status: non_neg_integer(), headers: list(), stream: Enumerable.t()}}
          | {:error, term()}
  def stream(url, headers, outbound_frames, opts)
      when is_binary(url) and is_list(headers) and is_list(outbound_frames) and is_list(opts) do
    receive_timeout = Keyword.get(opts, :receive_timeout, @default_receive_timeout)

    with {:ok, conn, ref, uri} <- connect(url, headers),
         {:ok, conn, status, response_headers} <- await_upgrade(conn, ref, receive_timeout),
         {:ok, conn, websocket} <-
           Mint.WebSocket.new(conn, ref, status, response_headers, mode: :passive),
         {:ok, conn, websocket} <- send_outbound_frames(conn, ref, websocket, outbound_frames) do
      stream =
        Stream.resource(
          fn ->
            %{
              conn: conn,
              done?: false,
              receive_timeout: receive_timeout,
              ref: ref,
              request_uri: uri,
              websocket: websocket
            }
          end,
          &next_item/1,
          &cleanup/1
        )

      {:ok, %{headers: response_headers, status: status, stream: stream}}
    end
  end

  defp connect(url, headers) do
    uri = URI.parse(url)
    port = uri.port || default_port(uri.scheme)
    connect_scheme = connect_scheme(uri.scheme)
    upgrade_scheme = upgrade_scheme(uri.scheme)
    request_path = request_path(uri)

    with {:ok, conn} <-
           Mint.HTTP.connect(connect_scheme, uri.host, port, mode: :passive, protocols: [:http1]),
         {:ok, conn, ref} <- Mint.WebSocket.upgrade(upgrade_scheme, conn, request_path, headers) do
      {:ok, conn, ref, uri}
    end
  end

  defp await_upgrade(conn, ref, timeout, acc \\ %{done?: false, headers: nil, status: nil}) do
    with {:ok, conn, responses} <- Mint.WebSocket.recv(conn, 0, timeout) do
      next_acc =
        Enum.reduce(responses, acc, fn
          {:status, ^ref, status}, state -> %{state | status: status}
          {:headers, ^ref, headers}, state -> %{state | headers: headers}
          {:done, ^ref}, state -> %{state | done?: true}
          _other, state -> state
        end)

      if next_acc.status && next_acc.headers && next_acc.done? do
        {:ok, conn, next_acc.status, next_acc.headers}
      else
        await_upgrade(conn, ref, timeout, next_acc)
      end
    end
  end

  defp send_outbound_frames(conn, ref, websocket, outbound_frames) do
    Enum.reduce_while(outbound_frames, {:ok, conn, websocket}, fn frame,
                                                                  {:ok, next_conn, next_ws} ->
      send_outbound_frame(next_conn, ref, next_ws, frame)
    end)
  end

  defp send_outbound_frame(conn, ref, websocket, frame) do
    case encode_frame(websocket, frame) do
      {:ok, next_ws, payload} -> send_encoded_frame(conn, ref, next_ws, payload)
      {:error, next_ws, reason} -> {:halt, {:error, {:frame_encode_failed, reason, next_ws}}}
    end
  end

  defp send_encoded_frame(conn, ref, websocket, payload) do
    case Mint.WebSocket.stream_request_body(conn, ref, payload) do
      {:ok, next_conn} -> {:cont, {:ok, next_conn, websocket}}
      {:error, _next_conn, reason} -> {:halt, {:error, reason}}
    end
  end

  defp next_item(%{done?: true} = state), do: {:halt, state}

  defp next_item(%{conn: conn, receive_timeout: timeout} = state) do
    case Mint.WebSocket.recv(conn, 0, timeout) do
      {:ok, conn, responses} ->
        handle_responses(%{state | conn: conn}, responses)
    end
  end

  defp handle_responses(state, responses) do
    case Enum.reduce_while(responses, {:ok, state, []}, &reduce_response/2) do
      {:ok, next_state, []} ->
        next_item(next_state)

      {:ok, next_state, items} ->
        {items, next_state}

      {:halt, next_state, items} ->
        {items, %{next_state | done?: true}}
    end
  end

  defp reduce_response(response, {:ok, state, items}) do
    case handle_response(response, state) do
      {:ok, next_state, next_items} -> {:cont, {:ok, next_state, items ++ next_items}}
      {:halt, next_state, next_items} -> {:halt, {:halt, next_state, items ++ next_items}}
    end
  end

  defp handle_response({:data, ref, data}, %{ref: ref} = state) do
    case Mint.WebSocket.decode(state.websocket, data) do
      {:ok, websocket, frames} ->
        handle_frames(frames, %{state | websocket: websocket})

      {:error, websocket, reason} ->
        {:halt, %{state | websocket: websocket}, [{:transport_error, {:decode_failed, reason}}]}
    end
  end

  defp handle_response(_response, state), do: {:ok, state, []}

  defp handle_frames([], state), do: {:ok, state, []}

  defp handle_frames([frame | rest], state) do
    case frame do
      {:text, payload} -> append_frame_item(rest, state, {:frame, {:text, payload}})
      {:binary, payload} -> append_frame_item(rest, state, {:frame, {:binary, payload}})
      {:ping, payload} -> handle_ping_frame(rest, state, payload)
      {:close, code, reason} -> {:halt, state, [{:close, code, reason}]}
      _other -> handle_frames(rest, state)
    end
  end

  defp handle_ping_frame(rest, state, payload) do
    case Mint.WebSocket.encode(state.websocket, {:pong, payload}) do
      {:ok, websocket, pong} ->
        send_pong_frame(rest, state, websocket, pong)

      {:error, _websocket, reason} ->
        {:halt, state, [{:transport_error, {:pong_encode_failed, reason}}]}
    end
  end

  defp send_pong_frame(rest, state, websocket, pong) do
    case Mint.WebSocket.stream_request_body(state.conn, state.ref, pong) do
      {:ok, conn} -> handle_frames(rest, %{state | conn: conn, websocket: websocket})
      {:error, _conn, reason} -> {:halt, state, [{:transport_error, {:pong_failed, reason}}]}
    end
  end

  defp append_frame_item(rest, state, item) do
    case handle_frames(rest, state) do
      {:ok, next_state, items} -> {:ok, next_state, [item | items]}
      {:halt, next_state, items} -> {:halt, next_state, [item | items]}
    end
  end

  defp cleanup(%{conn: conn}) do
    Mint.HTTP.close(conn)
    :ok
  end

  defp encode_frame(websocket, {:text, payload}) when is_binary(payload) do
    Mint.WebSocket.encode(websocket, {:text, payload})
  end

  defp encode_frame(websocket, {:binary, payload}) when is_binary(payload) do
    Mint.WebSocket.encode(websocket, {:binary, payload})
  end

  defp encode_frame(websocket, payload) when is_binary(payload) do
    Mint.WebSocket.encode(websocket, {:text, payload})
  end

  defp request_path(%URI{path: nil, query: nil}), do: "/"
  defp request_path(%URI{path: nil, query: query}), do: "/?" <> query
  defp request_path(%URI{path: path, query: nil}) when is_binary(path) and path != "", do: path
  defp request_path(%URI{path: "", query: nil}), do: "/"
  defp request_path(%URI{path: "", query: query}), do: "/?" <> query
  defp request_path(%URI{path: path, query: query}), do: path <> "?" <> query

  defp connect_scheme("wss"), do: :https
  defp connect_scheme("ws"), do: :http
  defp connect_scheme("https"), do: :https
  defp connect_scheme("http"), do: :http

  defp upgrade_scheme("wss"), do: :wss
  defp upgrade_scheme("ws"), do: :ws
  defp upgrade_scheme("https"), do: :wss
  defp upgrade_scheme("http"), do: :ws

  defp default_port("wss"), do: 443
  defp default_port("https"), do: 443
  defp default_port("ws"), do: 80
  defp default_port("http"), do: 80
end
