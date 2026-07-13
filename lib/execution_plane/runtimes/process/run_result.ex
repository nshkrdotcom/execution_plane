defmodule ExecutionPlane.Runtimes.Process.RunResult do
  @moduledoc """
  Captured output and normalized exit data for one-shot process execution.
  """

  alias ExecutionPlane.Runtimes.Process.Exit

  @enforce_keys [:exit, :invocation]
  defstruct invocation: %{},
            output: "",
            stdout: "",
            stderr: "",
            exit: nil,
            stderr_mode: :separate

  @type t :: %__MODULE__{
          invocation: map(),
          output: binary(),
          stdout: binary(),
          stderr: binary(),
          exit: Exit.t(),
          stderr_mode: :separate | :stdout
        }
end
