defmodule Mix.Tasks.ExecutionPlane.Release.Bootstrap do
  use Mix.Task

  @shortdoc "Bootstrap the canonical Weld tracking bundle before Ground is published"

  @moduledoc """
  Creates the pre-parent tracking bundle required by `release.track` without
  changing the generated project's canonical Hex dependencies.

  This task is only for the interval in which the two Ground packages are
  unpublished. Once they resolve from Hex, use `mix release.prepare` instead.
  """

  @repo_root Path.expand("../../..", __DIR__)
  @manifest_path Path.join(@repo_root, "build_support/weld.exs")
  @artifact "execution_plane"
  @selected_projects [
    "core/execution_plane",
    "protocols/execution_plane_jsonrpc",
    "runtimes/execution_plane_process"
  ]

  @impl Mix.Task
  def run(args) do
    {opts, positional, invalid} = OptionParser.parse(args, strict: [artifact: :string])

    if positional != [] or invalid != [] do
      Mix.raise("Usage: mix execution_plane.release.bootstrap [--artifact execution_plane]")
    end

    artifact = opts[:artifact] || @artifact

    if artifact != @artifact do
      Mix.raise("unsupported bootstrap artifact: #{artifact}")
    end

    projection = Weld.project!(@manifest_path, artifact: artifact)
    validate_canonical_projection!(projection.build_path)

    bundle_path = Weld.release_bundle_path!(@manifest_path, artifact: artifact)
    project_target = Path.join(bundle_path, "project")

    File.rm_rf!(bundle_path)
    File.mkdir_p!(bundle_path)
    File.cp_r!(projection.build_path, project_target)

    metadata = release_metadata(project_target)

    bundle_path
    |> Path.join("release.json")
    |> File.write!([Jason.encode_to_iodata!(metadata, pretty: true), "\n"])

    Mix.shell().info("Bootstrapped unpublished-parent tracking bundle in #{bundle_path}")
  end

  defp validate_canonical_projection!(build_path) do
    mix_source = File.read!(Path.join(build_path, "mix.exs"))
    lock = build_path |> Path.join("projection.lock.json") |> File.read!() |> Jason.decode!()

    unless lock["graph"]["selected_projects"] == @selected_projects do
      Mix.raise("projection selection differs from the frozen three-project distribution")
    end

    unless mix_source =~ ~s({:ground_plane_contracts, "~> 0.1.0"}) and
             mix_source =~ ~s({:ground_plane_persistence_policy, "~> 0.1.0"}) do
      Mix.raise("generated Ground dependencies are not canonical Hex requirements")
    end

    if Regex.match?(~r/[\s\[,](?:path|git|github):\s/, mix_source) do
      Mix.raise("generated project contains a path or Git dependency")
    end

    if Enum.any?(lock["projection"]["copied_files"], &cache_file?/1) do
      Mix.raise("generated project contains build or Dialyzer cache material")
    end
  end

  defp release_metadata(project_target) do
    %{
      artifact: @artifact,
      package: %{name: "execution_plane", version: "0.1.0", otp_app: :execution_plane},
      source_revision: git_revision!(),
      manifest_path: Path.relative_to(@manifest_path, @repo_root),
      manifest_digest: sha256_file(@manifest_path),
      weld_version: Weld.version(),
      elixir_version: System.version(),
      otp_release: List.to_string(:erlang.system_info(:otp_release)),
      prepared_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      project_path: Path.basename(project_target),
      tarball_path: nil,
      bootstrap: %{
        reason: "unpublished_ground_parents",
        replacement_gate: "rerun release.prepare after both Ground packages resolve from Hex",
        verified_by: "packaging/weld/execution_plane/consumer"
      }
    }
  end

  defp cache_file?(path) do
    path =~ "/_build/" or path =~ "/deps/" or path =~ "/plts/" or
      String.ends_with?(path, [".beam", ".plt", ".plt.hash"])
  end

  defp git_revision! do
    case System.cmd("git", ["rev-parse", "HEAD"], cd: @repo_root, stderr_to_stdout: true) do
      {revision, 0} -> String.trim(revision)
      {output, _status} -> Mix.raise("unable to read source revision: #{String.trim(output)}")
    end
  end

  defp sha256_file(path) do
    path
    |> File.read!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
