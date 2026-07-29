defmodule ExecutionPlane.HTTP.ActiveSession do
  @moduledoc false

  use GenServer, restart: :temporary

  alias ExecutionPlane.ExecutionResult
  alias ExecutionPlane.HTTP.RuntimeClientGateway

  @max_demand 1_024
  @default_chunk_bytes 1_024
  @methods %{
    "DELETE" => :delete,
    "GET" => :get,
    "HEAD" => :head,
    "OPTIONS" => :options,
    "PATCH" => :patch,
    "POST" => :post,
    "PUT" => :put,
    "TRACE" => :trace
  }

  def start_link(request, owner, opts),
    do: GenServer.start_link(__MODULE__, {request, owner, opts})

  def start(request, owner, opts), do: GenServer.start(__MODULE__, {request, owner, opts})

  def send_input(session, input), do: GenServer.call(session, {:input, input})
  def end_input(session), do: GenServer.call(session, :end_input)
  def cancel(session, reason), do: GenServer.call(session, {:cancel, reason})

  @impl true
  def init({request, owner, opts}) do
    with {:ok, family_request} <- decode_family_request(request.payload),
         {:ok, invocation} <- materialize_request(family_request, opts) do
      state = %{
        request: request,
        family_request: family_request,
        invocation: invocation,
        owner: owner,
        opts: opts,
        request_id: nil,
        result: nil,
        chunks: nil,
        demand: 0,
        terminal_sent?: false
      }

      {:ok, state, {:continue, :request}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:request, state) do
    _ = Application.ensure_all_started(:inets)
    _ = Application.ensure_all_started(:ssl)

    case start_http_request(state.invocation) do
      {:ok, request_id} ->
        {:noreply, %{state | request_id: request_id}}

      {:error, reason} ->
        send(state.owner, {:execution_plane_http_active, {:error, reason}})
        {:noreply, state}
    end
  end

  @impl true
  def handle_call({:input, input}, _from, state) do
    case demand(input) do
      {:ok, count} ->
        next_state = state |> Map.update!(:demand, &min(&1 + count, @max_demand)) |> deliver()
        {:reply, :ok, next_state}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  def handle_call(:end_input, _from, state), do: {:reply, :ok, state}

  def handle_call({:cancel, _reason}, _from, state) do
    case cancel_http_request(state.request_id) do
      :ok -> {:stop, :normal, :ok, state}
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_info({:http, {request_id, response}}, %{request_id: request_id} = state) do
    result = execution_result(state.request, response)

    next_state =
      state
      |> Map.put(:request_id, nil)
      |> Map.put(:result, result)
      |> Map.put(:chunks, response_chunks(result, state.family_request.response_mode, state.opts))
      |> deliver()

    {:noreply, next_state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp deliver(%{result: nil} = state), do: state
  defp deliver(%{demand: demand} = state) when demand <= 0, do: state
  defp deliver(%{terminal_sent?: true} = state), do: state

  defp deliver(%{family_request: %{response_mode: "unary"}} = state) do
    send(
      state.owner,
      {:execution_plane_http_active,
       {:output, %{"family" => "http", "execution_result" => state.result}}}
    )

    send_terminal(%{state | demand: state.demand - 1})
  end

  defp deliver(%{chunks: []} = state), do: send_terminal(state)

  defp deliver(%{chunks: [chunk | rest]} = state) do
    send(
      state.owner,
      {:execution_plane_http_active,
       {:output, %{"family" => "http", "stream" => "body", "data" => chunk}}}
    )

    next_state = %{state | chunks: rest, demand: state.demand - 1}

    if rest == [] do
      send_terminal(next_state)
    else
      deliver(next_state)
    end
  end

  defp send_terminal(state) do
    terminal_state = if state.result.status == "succeeded", do: "completed", else: "failed"

    send(
      state.owner,
      {:execution_plane_http_active, {:terminal, terminal_state, state.result}}
    )

    %{state | terminal_sent?: true}
  end

  defp start_http_request(invocation) do
    case Map.fetch(@methods, invocation.method) do
      {:ok, method} ->
        headers =
          Enum.map(invocation.headers, fn {key, value} ->
            {String.to_charlist(to_string(key)), String.to_charlist(to_string(value))}
          end)

        request =
          if is_nil(invocation.body) and method in [:get, :delete, :head, :options] do
            {String.to_charlist(invocation.url), headers}
          else
            content_type = content_type(invocation.headers)
            body = encode_body(invocation.body)

            {String.to_charlist(invocation.url), headers, String.to_charlist(content_type), body}
          end

        http_options = [
          timeout: invocation.timeout_ms,
          connect_timeout: invocation.timeout_ms
        ]

        :httpc.request(method, request, http_options,
          sync: false,
          receiver: self(),
          body_format: :binary
        )

      :error ->
        {:error, :invalid_http_method}
    end
  end

  defp execution_result(request, {{_version, status_code, _reason}, headers, body}) do
    ExecutionResult.new!(
      execution_ref: request.execution_ref,
      status: "succeeded",
      output: %{
        "status_code" => status_code,
        "headers" => normalize_response_headers(headers),
        "body" => IO.iodata_to_binary(body)
      },
      provenance: request.provenance
    )
  end

  defp execution_result(request, {:error, reason}) do
    ExecutionResult.new!(
      execution_ref: request.execution_ref,
      status: "failed",
      error: %{"reason" => inspect(reason)},
      provenance: request.provenance
    )
  end

  defp response_chunks(_result, "unary", _opts), do: []

  defp response_chunks(result, "incremental", opts) do
    body = Map.get(result.output, "body", "")
    chunk_bytes = Keyword.get(opts, :http_chunk_bytes, @default_chunk_bytes)

    body
    |> chunk_binary(chunk_bytes, [])
    |> Enum.reverse()
  end

  defp chunk_binary("", _size, acc), do: acc

  defp chunk_binary(binary, size, acc)
       when is_integer(size) and size > 0 and byte_size(binary) <= size,
       do: [binary | acc]

  defp chunk_binary(binary, size, acc) when is_integer(size) and size > 0 do
    <<chunk::binary-size(size), rest::binary>> = binary
    chunk_binary(rest, size, [chunk | acc])
  end

  defp decode_family_request(%{"family" => "http", "request" => request}),
    do: RuntimeClientGateway.decode_request(request)

  defp decode_family_request(%{family: "http", request: request}),
    do: RuntimeClientGateway.decode_request(request)

  defp decode_family_request(_payload), do: {:error, :invalid_http_family_payload}

  defp materialize_request(request, opts) do
    with {:ok, endpoint} <- fetch_materialization(opts, :endpoints, request.endpoint_ref),
         {:ok, headers} <-
           fetch_materialization(opts, :header_policies, request.header_policy_ref),
         {:ok, body} <- optional_materialization(opts, :body_artifacts, request.body_artifact_ref),
         {:ok, url} <- trusted_url(endpoint, request.path),
         true <- is_map(headers) do
      {:ok,
       %{
         url: url,
         method: request.method,
         headers: headers,
         body: body,
         timeout_ms: max(DateTime.diff(request.deadline_at, DateTime.utc_now(), :millisecond), 1)
       }}
    else
      false -> {:error, :invalid_http_header_policy}
      {:error, _reason} = error -> error
    end
  end

  defp fetch_materialization(opts, key, ref) do
    case opts |> Keyword.get(key, %{}) |> Map.fetch(ref) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:unknown_http_materialization, key, ref}}
    end
  rescue
    BadMapError -> {:error, {:invalid_http_materializations, key}}
  end

  defp optional_materialization(_opts, _key, nil), do: {:ok, nil}
  defp optional_materialization(opts, key, ref), do: fetch_materialization(opts, key, ref)

  defp trusted_url(endpoint, path) when is_binary(endpoint) and is_binary(path) do
    uri = URI.parse(endpoint)

    if uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != "" do
      url =
        endpoint
        |> ensure_trailing_slash()
        |> URI.merge(String.trim_leading(path, "/"))
        |> URI.to_string()

      {:ok, url}
    else
      {:error, :invalid_trusted_http_endpoint}
    end
  end

  defp trusted_url(_endpoint, _path), do: {:error, :invalid_trusted_http_endpoint}

  defp ensure_trailing_slash(endpoint) do
    if String.ends_with?(endpoint, "/"), do: endpoint, else: endpoint <> "/"
  end

  defp content_type(headers) do
    Enum.find_value(headers, "application/json", fn {key, value} ->
      if String.downcase(to_string(key)) == "content-type", do: to_string(value)
    end)
  end

  defp encode_body(nil), do: ""
  defp encode_body(body) when is_binary(body), do: body
  defp encode_body(body) when is_map(body) or is_list(body), do: Jason.encode!(body)
  defp encode_body(body), do: to_string(body)

  defp normalize_response_headers(headers) do
    Map.new(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp demand(%{"control" => "demand", "count" => count})
       when is_integer(count) and count > 0 and count <= @max_demand,
       do: {:ok, count}

  defp demand(%{control: "demand", count: count})
       when is_integer(count) and count > 0 and count <= @max_demand,
       do: {:ok, count}

  defp demand(_input), do: {:error, :invalid_http_demand}

  defp cancel_http_request(nil), do: :ok

  defp cancel_http_request(request_id) do
    case :httpc.cancel_request(request_id) do
      :ok -> :ok
      {:error, :not_found} -> :ok
      {:error, _reason} = error -> error
    end
  end
end
