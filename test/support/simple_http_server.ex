defmodule ExecutionPlane.TestSupport.SimpleHTTPServer do
  @moduledoc false

  def start(owner, responder) when is_pid(owner) and is_function(responder, 1) do
    {:ok, listen_socket} =
      :gen_tcp.listen(0, [:binary, {:active, false}, {:packet, :raw}, {:reuseaddr, true}])

    {:ok, port} = :inet.port(listen_socket)

    pid =
      spawn_link(fn ->
        {:ok, socket} = :gen_tcp.accept(listen_socket)
        request = read_request(socket, "")
        send(owner, {:simple_http_request, request})

        {status, headers, body} = responder.(request)

        response = [
          "HTTP/1.1 ",
          Integer.to_string(status),
          " ",
          reason_phrase(status),
          "\r\n",
          Enum.map(headers, fn {key, value} -> [key, ": ", value, "\r\n"] end),
          "content-length: ",
          Integer.to_string(byte_size(body)),
          "\r\n",
          "connection: close\r\n",
          "\r\n",
          body
        ]

        :ok = :gen_tcp.send(socket, response)
        :gen_tcp.close(socket)
        :gen_tcp.close(listen_socket)
      end)

    %{pid: pid, url: "http://127.0.0.1:#{port}"}
  end

  defp read_request(socket, buffer) do
    case :binary.match(buffer, "\r\n\r\n") do
      {headers_end, 4} ->
        header_block = binary_part(buffer, 0, headers_end)
        body_start = headers_end + 4
        body = binary_part(buffer, body_start, byte_size(buffer) - body_start)
        content_length = content_length(header_block)

        if byte_size(body) >= content_length do
          request_from_parts(header_block, binary_part(body, 0, content_length))
        else
          {:ok, chunk} = :gen_tcp.recv(socket, 0, 1_000)
          read_request(socket, buffer <> chunk)
        end

      :nomatch ->
        {:ok, chunk} = :gen_tcp.recv(socket, 0, 1_000)
        read_request(socket, buffer <> chunk)
    end
  end

  defp request_from_parts(header_block, body) do
    [request_line | header_lines] = String.split(header_block, "\r\n", trim: true)
    [method, path, _http_version] = String.split(request_line, " ", parts: 3)

    headers =
      Enum.reduce(header_lines, %{}, fn line, acc ->
        [name, value] = String.split(line, ":", parts: 2)
        Map.put(acc, String.downcase(name), String.trim(value))
      end)

    %{
      method: method,
      path: path,
      headers: headers,
      body: body
    }
  end

  defp content_length(header_block) do
    header_block
    |> String.split("\r\n", trim: true)
    |> Enum.find_value(0, fn line ->
      case String.split(line, ":", parts: 2) do
        [name, value] ->
          if String.downcase(name) == "content-length" do
            value |> String.trim() |> String.to_integer()
          end

        _other ->
          nil
      end
    end)
  end

  defp reason_phrase(200), do: "OK"
  defp reason_phrase(201), do: "Created"
  defp reason_phrase(400), do: "Bad Request"
  defp reason_phrase(408), do: "Request Timeout"
  defp reason_phrase(500), do: "Internal Server Error"
  defp reason_phrase(_status), do: "Response"
end
