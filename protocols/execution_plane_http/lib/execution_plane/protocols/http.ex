defmodule ExecutionPlane.Protocols.HTTP do
  @moduledoc """
  Minimal unary HTTP execution for the lower substrate.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.Failure
  alias ExecutionPlane.Kernel.DispatchPlan
  alias ExecutionPlane.LowerSimulation

  @http_method_aliases %{
    "delete" => :delete,
    "get" => :get,
    "head" => :head,
    "options" => :options,
    "patch" => :patch,
    "post" => :post,
    "put" => :put,
    "trace" => :trace
  }
  @http_methods Map.values(@http_method_aliases)

  @spec protocol() :: String.t()
  def protocol, do: "http"

  @spec supported_stream_modes() :: [String.t(), ...]
  def supported_stream_modes, do: ["unary", "sse"]

  @spec supports_intent?(struct() | map() | keyword()) :: boolean()
  def supports_intent?(%{__struct__: ExecutionPlane.Contracts.HttpExecutionIntent.V1}), do: true
  def supports_intent?(_other), do: false

  @spec execute(DispatchPlan.t(), keyword()) :: {:ok, map()} | {:error, map()}
  def execute(
        %DispatchPlan{
          intent: %{__struct__: ExecutionPlane.Contracts.HttpExecutionIntent.V1} = intent,
          route: route,
          timeout_ms: timeout_ms
        },
        _opts
      ) do
    url = Contracts.fetch_value(route.resolved_target, :url)
    headers = normalize_headers(intent.headers)
    body = normalize_body(intent.body)
    content_type = content_type(headers, body)
    start_ms = System.monotonic_time(:millisecond)

    case route.resolved_target |> Contracts.fetch_value(:method) |> normalize_method() do
      {:ok, method} ->
        case LowerSimulation.execute_if_configured("http", intent, route, start_ms) do
          :not_configured ->
            execute_http_request(method, url, headers, content_type, body, timeout_ms, start_ms)

          {:ok, execution} ->
            {:ok, execution}

          {:error, execution} ->
            {:error, execution}
        end

      {:error, {:invalid_http_method, method}} ->
        invalid_method_result(method, start_ms)
    end
  end

  defp execute_http_request(method, url, headers, content_type, body, timeout_ms, start_ms) do
    ensure_http_started()

    case do_request(method, url, headers, content_type, body, timeout_ms) do
      {:ok, status_code, response_headers, response_body} ->
        {:ok,
         %{
           family: "http",
           raw_payload: %{
             status_code: status_code,
             headers: response_headers,
             body: response_body
           },
           metrics: %{"duration_ms" => System.monotonic_time(:millisecond) - start_ms},
           failure: nil
         }}

      {:error, reason} ->
        {:error,
         %{
           family: "http",
           raw_payload: %{error: inspect(reason)},
           metrics: %{"duration_ms" => System.monotonic_time(:millisecond) - start_ms},
           failure:
             Failure.new!(%{
               failure_class: :transport_failed,
               reason: "http request failed"
             })
         }}
    end
  end

  defp ensure_http_started do
    _ = Application.ensure_all_started(:inets)
    _ = Application.ensure_all_started(:ssl)
    :ok
  end

  defp normalize_method(nil), do: {:ok, :post}

  defp normalize_method(method) when is_atom(method) do
    if method in @http_methods do
      {:ok, method}
    else
      {:error, {:invalid_http_method, method}}
    end
  end

  defp normalize_method(method) when is_binary(method) do
    case Map.fetch(@http_method_aliases, String.downcase(method)) do
      {:ok, normalized_method} -> {:ok, normalized_method}
      :error -> {:error, {:invalid_http_method, method}}
    end
  end

  defp normalize_method(method), do: {:error, {:invalid_http_method, method}}

  defp normalize_headers(headers) when is_map(headers) do
    Enum.map(headers, fn {key, value} ->
      {String.to_charlist(to_string(key)), String.to_charlist(to_string(value))}
    end)
  end

  defp normalize_body(body) when body in [%{}, []], do: ""
  defp normalize_body(body) when is_binary(body), do: body
  defp normalize_body(body) when is_map(body) or is_list(body), do: Jason.encode!(body)
  defp normalize_body(body), do: to_string(body)

  defp content_type(headers, body) do
    Enum.find_value(headers, "application/json", fn
      {~c"content-type", value} -> to_string(value)
      _other -> nil
    end)
    |> case do
      "application/json" = content_type when body != "" -> content_type
      content_type when is_binary(content_type) -> content_type
      _other -> "text/plain"
    end
  end

  defp do_request(method, url, headers, content_type, body, timeout_ms) do
    request =
      if body == "" and method in [:get, :delete] do
        {String.to_charlist(url), headers}
      else
        {String.to_charlist(url), headers, String.to_charlist(content_type), body}
      end

    http_options = [timeout: timeout_ms, connect_timeout: timeout_ms]
    options = [body_format: :binary]

    case :httpc.request(method, request, http_options, options) do
      {:ok, {{_version, status_code, _reason_phrase}, response_headers, response_body}} ->
        {:ok, status_code,
         Enum.into(response_headers, %{}, fn {key, value} ->
           {to_string(key), to_string(value)}
         end), IO.iodata_to_binary(response_body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp invalid_method_result(method, start_ms) do
    {:error,
     %{
       family: "http",
       raw_payload: %{error: "invalid_http_method: #{inspect(method)}"},
       metrics: %{"duration_ms" => System.monotonic_time(:millisecond) - start_ms},
       failure:
         Failure.new!(%{
           failure_class: :transport_failed,
           reason: "invalid http method"
         })
     }}
  end
end
