defmodule ExecutionPlane.Process.TreRhaiTest do
  use ExUnit.Case, async: false

  alias ExecutionPlane.Process.TreRhai

  setup do
    tmp_root =
      Path.join(
        System.tmp_dir!(),
        "execution-plane-tre-test-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_root)

    runner_path = Path.join(tmp_root, "fake-rex-runner")

    File.write!(runner_path, fake_runner_script())
    File.chmod!(runner_path, 0o755)

    on_exit(fn -> File.rm_rf(tmp_root) end)

    {:ok, runner_path: runner_path, tmp_root: tmp_root}
  end

  test "local TRE lane runs a read-only Rhai helper with no ambient environment", %{
    runner_path: runner_path
  } do
    previous = System.get_env("TRE_TEST_SECRET")
    System.put_env("TRE_TEST_SECRET", "ambient-secret")

    try do
      assert {:ok, receipt} =
               TreRhai.execute(read_only_envelope(),
                 runner_path: runner_path,
                 materializer: materializer(read_only_script(), read_only_policy()),
                 cleanup?: true
               )

      assert receipt["status"] == "succeeded"
      assert receipt["runner_output"]["status"] == "SUCCESS"
      assert receipt["runner_output"]["output"] == "readonly-ok"
      assert receipt["script_ref"] == "script:tre:read-only:v1"
      assert receipt["policy_bundle_ref"] == "tre-policy-bundle://phase14/read-only"
      assert receipt["runner_envelope_hash"] =~ "sha256:"
      assert receipt["spawned?"] == true
      assert receipt["env_policy"] == "clear"
    after
      restore_env("TRE_TEST_SECRET", previous)
    end
  end

  test "local TRE lane denies forbidden helper declarations before runner spawn", %{
    tmp_root: tmp_root
  } do
    marker_path = Path.join(tmp_root, "forbidden-effect")

    runner_that_writes =
      Path.join(tmp_root, "effect-runner")

    File.write!(runner_that_writes, """
    #!/bin/sh
    printf effect > #{marker_path}
    printf '{"output":"bad","status":"SUCCESS"}'
    """)

    File.chmod!(runner_that_writes, 0o755)

    assert {:error, receipt} =
             TreRhai.execute(
               read_only_envelope(%{
                 "script_ref" => "script:tre:forbidden-write:v1",
                 "declared_actions" => ["fs.write"],
                 "allowed_actions" => ["fs.read"]
               }),
               runner_path: runner_that_writes,
               materializer: materializer(write_script(marker_path), read_only_policy()),
               cleanup?: true
             )

    assert receipt["status"] == "denied"
    assert receipt["failure_class"] == "policy_denied"
    assert receipt["spawned?"] == false
    refute File.exists?(marker_path)
  end

  defp materializer(script_source, policy_source) do
    fn _envelope ->
      {:ok,
       %{
         script_source: script_source,
         policy_source: policy_source,
         script_arguments: %{
           "file_path" => %{"stringValue" => "README.md"}
         }
       }}
    end
  end

  defp read_only_envelope(overrides \\ %{}) do
    Map.merge(
      %{
        "version" => "nshkr.execution_plane.tre.v1",
        "authority_ref" => "authority://phase14/read-only",
        "policy_bundle_ref" => "tre-policy-bundle://phase14/read-only",
        "policy_bundle_hash" =>
          "sha256:1111111111111111111111111111111111111111111111111111111111111111",
        "cedar_schema_ref" => "cedar-schema://phase14/read-only",
        "cedar_schema_hash" =>
          "sha256:2222222222222222222222222222222222222222222222222222222222222222",
        "script_ref" => "script:tre:read-only:v1",
        "script_hash" => sha256(read_only_script()),
        "trace_id" => "trace-phase14",
        "declared_actions" => ["fs.read"],
        "allowed_actions" => ["fs.read"],
        "resource_scope_refs" => ["workspace://phase14/read-only"],
        "limits" => %{
          "max_operations" => 1_000,
          "wall_clock_ms" => 30_000,
          "max_output_bytes" => 65_536,
          "max_artifact_bytes" => 1_048_576,
          "max_network_calls" => 0,
          "max_process_spawns" => 0
        }
      },
      overrides
    )
  end

  defp read_only_script do
    ~s|let contents = cat(file_path); contents|
  end

  defp write_script(marker_path) do
    ~s|write([write::replace], "#{marker_path}", "effect")|
  end

  defp read_only_policy do
    """
    permit(principal, action, resource)
    when { action == file_system::Action::"read" };
    """
  end

  defp sha256(value) do
    "sha256:" <> Base.encode16(:crypto.hash(:sha256, value), case: :lower)
  end

  defp fake_runner_script do
    """
    #!/bin/sh
    set -eu

    script_file=""
    policy_file=""
    args_file=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --script-file|-s)
          script_file="$2"
          shift 2
          ;;
        --policy-file|-p)
          policy_file="$2"
          shift 2
          ;;
        --script-arguments-file|-a)
          args_file="$2"
          shift 2
          ;;
        --output-format|-o)
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done

    if [ "${TRE_TEST_SECRET:-}" != "" ]; then
      printf '{"output":"","status":"ERROR","error":{"error_type":"VALIDATION_EXCEPTION","message":"ambient secret leaked"}}'
      exit 0
    fi

    if [ ! -f "$script_file" ] || [ ! -f "$policy_file" ] || [ ! -f "$args_file" ]; then
      printf '{"output":"","status":"ERROR","error":{"error_type":"VALIDATION_EXCEPTION","message":"missing runner input file"}}'
      exit 0
    fi

    if grep -q 'cat(' "$script_file"; then
      printf '{"output":"readonly-ok","status":"SUCCESS"}'
    else
      printf '{"output":"","status":"ERROR","error":{"error_type":"ACCESS_DENIED_EXCEPTION","message":"denied by Cedar policy"}}'
    fi
    """
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
