defmodule ExecutionPlane.Process.TreRhai do
  @moduledoc """
  Local TRE/Rhai process lane for invoking `rex-runner`.

  The caller supplies a governed TRE envelope with refs and hashes. This module
  resolves script/policy material through an explicit materializer, writes a
  bounded local runner workspace, invokes the runner with a cleared environment,
  and returns a structured receipt. It does not accept raw policy/script material
  in the public envelope.
  """

  alias ExecutionPlane.Runtimes.Process, as: ProcessRuntime
  alias ExecutionPlane.Runtimes.Process.{Exit, RunResult}

  @version "nshkr.execution_plane.tre.v1"
  @receipt_contract "ExecutionPlane.TreRhaiReceipt.v1"
  @runner_output_format "json"
  @default_max_wall_clock_ms 30_000
  @lane_max_wall_clock_ms 300_000
  @lane_max_output_bytes 1_048_576
  @lane_max_artifact_bytes 104_857_600
  @raw_material_keys MapSet.new(~w(
    cedar_entities
    cedar_policy
    cedar_policy_source
    cedar_policy_text
    cedar_schema
    cedar_schema_text
    policy_source
    policy_text
    schema_text
    script_source
  ))

  @required_refs ~w(
    authority_ref
    policy_bundle_ref
    policy_bundle_hash
    cedar_schema_ref
    cedar_schema_hash
    script_ref
    script_hash
    trace_id
  )

  @type receipt :: map()
  @type materializer :: (map() -> {:ok, map()} | {:error, term()})

  @spec execute(map() | keyword(), keyword()) :: {:ok, receipt()} | {:error, receipt()}
  def execute(envelope_attrs, opts \\ []) when is_list(opts) do
    envelope = normalize_map(envelope_attrs)

    case validate_envelope(envelope) do
      :ok ->
        execute_validated(envelope, opts)

      {:deny, failure_class, reason} ->
        {:error, receipt(envelope, "denied", false, failure_class, reason, %{})}

      {:error, failure_class, reason} ->
        {:error, receipt(envelope, "failed", false, failure_class, reason, %{})}
    end
  end

  defp execute_validated(envelope, opts) do
    root = Keyword.get_lazy(opts, :work_root, &default_work_root/0)
    cleanup? = Keyword.get(opts, :cleanup?, true)

    File.mkdir_p!(root)

    try do
      with {:ok, material} <- materialize(envelope, opts),
           :ok <- verify_material(envelope, material, opts),
           {:ok, files} <- write_runner_files(root, envelope, material),
           {:ok, runner_path} <- runner_path(opts),
           {:ok, run_result} <- run_runner(runner_path, files, envelope) do
        receipt_from_runner(envelope, run_result, files, runner_path)
      else
        {:error, failure_class, reason} ->
          {:error, receipt(envelope, "failed", false, failure_class, reason, %{})}
      end
    after
      if cleanup?, do: File.rm_rf(root)
    end
  end

  defp validate_envelope(envelope) do
    with :ok <- require_version(envelope),
         :ok <- reject_raw_material(envelope),
         :ok <- require_refs(envelope),
         :ok <- require_limits(envelope),
         :ok <- reject_unresolved_scopes(envelope) do
      require_declared_actions_allowed(envelope)
    end
  end

  defp require_version(%{"version" => @version}), do: :ok

  defp require_version(%{"version" => version}) do
    {:error, "invalid_envelope", "unsupported TRE envelope version #{inspect(version)}"}
  end

  defp require_version(_envelope),
    do: {:error, "invalid_envelope", "missing TRE envelope version"}

  defp require_refs(envelope) do
    missing =
      Enum.reject(@required_refs, fn key ->
        present_string?(Map.get(envelope, key))
      end)

    case missing do
      [] -> :ok
      keys -> {:error, "invalid_envelope", "missing required TRE refs: #{Enum.join(keys, ", ")}"}
    end
  end

  defp require_limits(envelope) do
    case Map.get(envelope, "limits") do
      %{} = limits ->
        validate_limits(limits)

      _other ->
        {:error, "limits_missing", "TRE limits are required"}
    end
  end

  defp validate_limits(limits) do
    with :ok <- validate_positive_limit(limits, "wall_clock_ms", @lane_max_wall_clock_ms),
         :ok <- validate_positive_limit(limits, "max_output_bytes", @lane_max_output_bytes),
         :ok <- validate_positive_limit(limits, "max_artifact_bytes", @lane_max_artifact_bytes) do
      validate_zero_limit(limits, "max_process_spawns")
    end
  end

  defp validate_positive_limit(limits, key, max) do
    value = Map.get(limits, key)

    cond do
      not positive_int?(value) ->
        {:error, "limits_invalid", "limits.#{key} must be positive"}

      value > max ->
        {:error, "limits_invalid", "limits.#{key} exceeds lane maximum"}

      true ->
        :ok
    end
  end

  defp validate_zero_limit(limits, key) do
    value = Map.get(limits, key)

    cond do
      not non_negative_int?(value) ->
        {:error, "limits_invalid", "limits.#{key} must be present"}

      value != 0 ->
        {:deny, "policy_denied", "local TRE lane requires #{key}=0"}

      true ->
        :ok
    end
  end

  defp reject_unresolved_scopes(envelope) do
    envelope
    |> string_list("resource_scope_refs")
    |> Enum.any?(&String.starts_with?(&1, "unresolved://"))
    |> case do
      true -> {:deny, "resource_scope_unresolvable", "resource scope refs must resolve"}
      false -> :ok
    end
  end

  defp require_declared_actions_allowed(envelope) do
    declared = string_list(envelope, "declared_actions")
    allowed = string_list(envelope, "allowed_actions")

    denied = declared -- allowed

    case denied do
      [] ->
        :ok

      actions ->
        {:deny, "policy_denied", "declared actions not allowed: #{Enum.join(actions, ", ")}"}
    end
  end

  defp reject_raw_material(value) do
    if raw_material?(value) do
      {:deny, "raw_material_rejected",
       "TRE envelope must carry refs and hashes, not raw Cedar/Rhai material"}
    else
      :ok
    end
  end

  defp materialize(envelope, opts) do
    case Keyword.get(opts, :materializer) do
      fun when is_function(fun, 1) ->
        case fun.(envelope) do
          {:ok, %{} = material} ->
            {:ok, normalize_map(material)}

          {:error, reason} ->
            {:error, "materialization_failed", inspect(reason)}

          other ->
            {:error, "materialization_failed", "invalid materializer result #{inspect(other)}"}
        end

      _other ->
        {:error, "materializer_missing", "TRE lane requires an explicit materializer"}
    end
  end

  defp verify_material(envelope, material, opts) do
    with {:ok, script_source} <- material_source(material, "script_source"),
         {:ok, _policy_source} <- material_source(material, "policy_source") do
      if Keyword.get(opts, :verify_script_hash?, true) do
        verify_hash("script_hash", envelope["script_hash"], script_source)
      else
        :ok
      end
    end
  end

  defp material_source(material, key) do
    case Map.get(material, key) do
      source when is_binary(source) and source != "" -> {:ok, source}
      _other -> {:error, "materialization_failed", "#{key} is required"}
    end
  end

  defp verify_hash(field, expected, source) do
    actual = sha256(source)

    if actual == expected do
      :ok
    else
      {:error, "hash_mismatch", "#{field} #{expected} does not match materialized source"}
    end
  end

  defp write_runner_files(root, envelope, material) do
    script_file = Path.join(root, "script.rhai")
    policy_file = Path.join(root, "policy.cedar")
    args_file = Path.join(root, "script-arguments.json")
    envelope_file = Path.join(root, "runner-envelope.json")

    script_source = Map.fetch!(material, "script_source")
    policy_source = Map.fetch!(material, "policy_source")
    script_arguments = Map.get(material, "script_arguments", %{})

    runner_envelope =
      envelope
      |> Map.take(
        @required_refs ++ ["declared_actions", "allowed_actions", "resource_scope_refs", "limits"]
      )
      |> Map.put("runner_contract", @version)
      |> Map.put("script_arguments_hash", sha256(Jason.encode!(script_arguments)))
      |> Map.put("materialized_files", %{
        "script_file" => "script.rhai",
        "policy_file" => "policy.cedar",
        "script_arguments_file" => "script-arguments.json"
      })

    File.write!(script_file, script_source)
    File.write!(policy_file, policy_source)
    File.write!(args_file, Jason.encode!(script_arguments))
    File.write!(envelope_file, Jason.encode!(runner_envelope))

    {:ok,
     %{
       "script_file" => script_file,
       "policy_file" => policy_file,
       "script_arguments_file" => args_file,
       "runner_envelope_file" => envelope_file,
       "runner_envelope_hash" => sha256(Jason.encode!(runner_envelope))
     }}
  rescue
    error -> {:error, "materialization_failed", Exception.message(error)}
  end

  defp runner_path(opts) do
    case Keyword.get(opts, :runner_path) || System.find_executable("rex-runner") do
      path when is_binary(path) and path != "" ->
        if File.exists?(path) do
          {:ok, path}
        else
          {:error, "runner_unavailable", "TRE runner not found at #{path}"}
        end

      _other ->
        {:error, "runner_unavailable", "rex-runner was not found"}
    end
  end

  defp run_runner(runner_path, files, envelope) do
    timeout_ms = get_in(envelope, ["limits", "wall_clock_ms"]) || @default_max_wall_clock_ms

    case ProcessRuntime.run(
           command: runner_path,
           argv: [
             "--script-file",
             files["script_file"],
             "--policy-file",
             files["policy_file"],
             "--script-arguments-file",
             files["script_arguments_file"],
             "--output-format",
             @runner_output_format
           ],
           cwd: Path.dirname(files["runner_envelope_file"]),
           env: %{},
           clear_env?: true,
           timeout: timeout_ms,
           stderr: :separate,
           close_stdin: true,
           surface_kind: "local_subprocess"
         ) do
      {:ok, %RunResult{} = result} -> {:ok, result}
      {:error, reason} -> {:error, "runner_failed", inspect(reason)}
    end
  end

  defp receipt_from_runner(envelope, %RunResult{} = result, files, runner_path) do
    max_output_bytes = get_in(envelope, ["limits", "max_output_bytes"]) || @lane_max_output_bytes

    cond do
      byte_size(result.stdout) > max_output_bytes ->
        {:error,
         receipt(
           envelope,
           "failed",
           true,
           "output_limit_exceeded",
           "runner output exceeded limit",
           files
         )}

      not Exit.successful?(result.exit) ->
        {:error,
         receipt(
           envelope,
           "failed",
           true,
           "runner_failed",
           "runner exited non-zero",
           files,
           %{result: result, runner_path: runner_path}
         )}

      true ->
        classify_runner_output(envelope, result, files, runner_path)
    end
  end

  defp classify_runner_output(envelope, %RunResult{} = result, files, runner_path) do
    runtime = %{result: result, runner_path: runner_path}

    case Jason.decode(result.stdout) do
      {:ok, %{"status" => "SUCCESS"} = output} ->
        {:ok,
         receipt(
           envelope,
           "succeeded",
           true,
           nil,
           nil,
           files,
           Map.put(runtime, :runner_output, output)
         )}

      {:ok,
       %{"status" => "ERROR", "error" => %{"error_type" => "ACCESS_DENIED_EXCEPTION"} = error} =
           output} ->
        {:error,
         receipt(
           envelope,
           "denied",
           true,
           "policy_denied",
           Map.get(error, "message", "runner denied operation"),
           files,
           Map.put(runtime, :runner_output, output)
         )}

      {:ok, %{"status" => "ERROR", "error" => %{} = error} = output} ->
        {:error,
         receipt(
           envelope,
           "failed",
           true,
           "runner_error",
           Map.get(error, "message", "runner returned error"),
           files,
           Map.put(runtime, :runner_output, output)
         )}

      {:ok, output} ->
        {:error,
         receipt(
           envelope,
           "failed",
           true,
           "runner_error",
           "runner returned unsupported output status",
           files,
           Map.put(runtime, :runner_output, output)
         )}

      {:error, error} ->
        {:error,
         receipt(
           envelope,
           "failed",
           true,
           "runner_output_invalid",
           Exception.message(error),
           files,
           runtime
         )}
    end
  end

  defp receipt(envelope, status, spawned?, failure_class, failure_reason, files, runtime \\ %{})

  defp receipt(
         envelope,
         status,
         spawned?,
         failure_class,
         failure_reason,
         files,
         runtime
       ) do
    result = Map.get(runtime, :result)
    runner_path = Map.get(runtime, :runner_path)
    runner_output = Map.get(runtime, :runner_output, %{})

    receipt_ref =
      "execution-plane-tre-receipt://#{URI.encode_www_form(envelope["trace_id"] || "unknown")}/#{status}"

    %{
      "contract_version" => @receipt_contract,
      "receipt_ref" => receipt_ref,
      "status" => status,
      "spawned?" => spawned?,
      "env_policy" => "clear",
      "runner" => "rex-runner",
      "runner_name" => runner_path && Path.basename(runner_path),
      "runner_exit" => runner_exit(result),
      "runner_output" => runner_output,
      "runner_output_hash" => result && sha256(result.stdout || ""),
      "runner_stderr_hash" => result && sha256(result.stderr || ""),
      "runner_envelope_hash" => Map.get(files, "runner_envelope_hash"),
      "authority_ref" => envelope["authority_ref"],
      "policy_bundle_ref" => envelope["policy_bundle_ref"],
      "policy_bundle_hash" => envelope["policy_bundle_hash"],
      "cedar_schema_ref" => envelope["cedar_schema_ref"],
      "cedar_schema_hash" => envelope["cedar_schema_hash"],
      "script_ref" => envelope["script_ref"],
      "script_hash" => envelope["script_hash"],
      "trace_id" => envelope["trace_id"],
      "resource_scope_refs" => string_list(envelope, "resource_scope_refs"),
      "declared_actions" => string_list(envelope, "declared_actions"),
      "allowed_actions" => string_list(envelope, "allowed_actions"),
      "limits" => Map.get(envelope, "limits", %{}),
      "artifact_refs" => artifact_refs(envelope, status),
      "event_refs" => event_refs(envelope, status),
      "failure_class" => failure_class,
      "failure_reason" => failure_reason
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp artifact_refs(envelope, "succeeded") do
    ["tre-artifact://#{URI.encode_www_form(envelope["trace_id"])}/runner-output"]
  end

  defp artifact_refs(_envelope, _status), do: []

  defp event_refs(envelope, status) do
    ["tre-event://#{URI.encode_www_form(envelope["trace_id"] || "unknown")}/#{status}"]
  end

  defp runner_exit(nil), do: nil

  defp runner_exit(%RunResult{exit: %Exit{} = exit}) do
    Exit.to_map(exit)
    |> stringify_keys()
  end

  defp normalize_map(attrs) when is_list(attrs), do: attrs |> Map.new() |> normalize_map()

  defp normalize_map(%{} = attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), normalize_value(value)} end)
  end

  defp normalize_value(%{} = value), do: normalize_map(value)
  defp normalize_value(values) when is_list(values), do: Enum.map(values, &normalize_value/1)
  defp normalize_value(value), do: value

  defp stringify_keys(%{} = attrs),
    do: Map.new(attrs, fn {key, value} -> {to_string(key), value} end)

  defp string_list(envelope, key) do
    case Map.get(envelope, key, []) do
      values when is_list(values) -> Enum.map(values, &to_string/1)
      nil -> []
      value -> [to_string(value)]
    end
  end

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
  defp positive_int?(value), do: is_integer(value) and value > 0
  defp non_negative_int?(value), do: is_integer(value) and value >= 0

  defp raw_material?(%{} = value) do
    Enum.any?(value, fn {key, nested_value} ->
      MapSet.member?(@raw_material_keys, to_string(key)) or raw_material?(nested_value)
    end)
  end

  defp raw_material?(values) when is_list(values), do: Enum.any?(values, &raw_material?/1)
  defp raw_material?(_value), do: false

  defp sha256(value) do
    "sha256:" <> Base.encode16(:crypto.hash(:sha256, IO.iodata_to_binary(value)), case: :lower)
  end

  defp default_work_root do
    Path.join(System.tmp_dir!(), "execution-plane-tre-#{System.unique_integer([:positive])}")
  end
end
