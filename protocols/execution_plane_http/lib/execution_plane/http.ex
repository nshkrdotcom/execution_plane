defmodule ExecutionPlane.HTTP do
  @moduledoc """
  Helper surface for unary HTTP request/response execution.

  Callers provide semantic request data plus optional lineage or envelope
  overrides. This helper emits `HttpExecutionIntent.v1`, resolves the matching
  minimal route, and executes the request through the kernel.
  """

  alias ExecutionPlane.Contracts
  alias ExecutionPlane.Contracts.HttpExecutionIntent.V1, as: HttpExecutionIntent
  alias ExecutionPlane.Kernel
  alias ExecutionPlane.Kernel.ExecutionResult
  alias ExecutionPlane.LaneSupport

  @spec unary(map() | keyword(), keyword()) ::
          {:ok, ExecutionResult.t()} | {:error, ExecutionResult.t()}
  def unary(request, opts \\ []) do
    request = Contracts.normalize_attrs(request)
    url = Contracts.fetch_required_stringish!(request, :url)
    timeout_ms = timeout_ms(request)
    lineage = LaneSupport.build_lineage("http", Keyword.get(opts, :lineage, %{}))

    intent =
      HttpExecutionIntent.new!(%{
        envelope:
          LaneSupport.build_envelope(
            "http",
            "http",
            "http.unary",
            lineage,
            Keyword.get(opts, :envelope, %{})
          ),
        request_shape:
          Contracts.fetch_optional_stringish!(request, :request_shape, "request_response"),
        stream_mode: Contracts.fetch_optional_stringish!(request, :stream_mode, "unary"),
        headers: normalize_headers(Contracts.fetch_value(request, :headers) || %{}),
        body: Contracts.fetch_value(request, :body),
        egress_surface:
          request
          |> execution_surface(url)
          |> Contracts.ensure_map!("egress_surface"),
        timeouts: request_timeouts(request, timeout_ms),
        retry_class: Contracts.fetch_optional_stringish!(request, :retry_class)
      })

    route =
      LaneSupport.build_route(
        "http",
        "http",
        "http",
        "local",
        %{
          "url" => url,
          "method" => Contracts.fetch_optional_stringish!(request, :method, "POST")
        },
        timeout_ms,
        lineage,
        Keyword.get(opts, :route, %{})
      )

    Kernel.execute(intent, route, LaneSupport.kernel_opts(opts))
  end

  defp normalize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    Map.new(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_headers(_headers), do: %{}

  defp request_timeouts(request, timeout_ms) do
    request
    |> Contracts.fetch_optional_map!(:timeouts, %{})
    |> maybe_put_timeout(timeout_ms)
  end

  defp timeout_ms(request) do
    case Contracts.fetch_value(request, :timeout_ms) do
      timeout when is_integer(timeout) and timeout > 0 -> timeout
      _other -> nil
    end
  end

  defp execution_surface(request, url) do
    case Contracts.fetch_value(request, :egress_surface) do
      nil -> %{"surface_kind" => uri_surface_kind(url)}
      surface -> surface
    end
  end

  defp uri_surface_kind(url) do
    case URI.parse(url).scheme do
      "http" -> "http"
      "https" -> "https"
      _other -> "https"
    end
  end

  defp maybe_put_timeout(timeouts, timeout_ms) when is_integer(timeout_ms) and timeout_ms > 0 do
    Map.put(timeouts, "request_timeout_ms", timeout_ms)
  end

  defp maybe_put_timeout(timeouts, _timeout_ms), do: timeouts
end
