defmodule ExecutionPlane.Process.Transport.SurfaceTest do
  use ExUnit.Case, async: true

  alias ExecutionPlane.Process.Transport.Surface

  describe "capabilities/1 with a keyword list" do
    # `nil` is an atom, so guarding the `with` clause on `is_atom/1` alone let a
    # missing surface_kind through to the registry lookup instead of reporting
    # an invalid surface. It also made the function's own `nil ->` error clause
    # unreachable, which is how the compiler found it.
    test "a missing surface_kind is an invalid surface, not a registry lookup" do
      opts = [contract_version: 1]

      assert {:error, {:invalid_execution_surface, ^opts}} = Surface.capabilities(opts)
    end

    test "an explicitly nil surface_kind is rejected the same way" do
      opts = [surface_kind: nil]

      assert {:error, {:invalid_execution_surface, ^opts}} = Surface.capabilities(opts)
    end

    test "an unknown surface_kind still reaches the registry and reports its own error" do
      assert {:error, reason} = Surface.capabilities(surface_kind: :no_such_surface)
      refute reason == {:invalid_execution_surface, [surface_kind: :no_such_surface]}
    end
  end
end
