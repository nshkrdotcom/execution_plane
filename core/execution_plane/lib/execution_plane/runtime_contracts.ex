defmodule ExecutionPlane.Runtime.ContractSupport do
  @moduledoc false

  def attrs(%_{} = value), do: Map.from_struct(value)
  def attrs(value) when is_list(value), do: Map.new(value)
  def attrs(value) when is_map(value), do: value

  def known_fields?(attrs, fields) do
    allowed = MapSet.new(Enum.flat_map(fields, &[&1, Atom.to_string(&1)]))
    Enum.all?(Map.keys(attrs), &MapSet.member?(allowed, &1))
  end
end

defmodule ExecutionPlane.Runtime.Error do
  @moduledoc "Bounded Runtime Client error envelope."

  @categories ~w(
    invalid_request rejected unavailable timeout backpressure cancelled
    transport_lost ambiguous terminal
  )
  alias ExecutionPlane.Runtime.ContractSupport

  @fields [:category, :message, :retryable, :ambiguous, :evidence_ref]
  @enforce_keys [:category, :message, :retryable, :ambiguous]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = ContractSupport.attrs(attrs)
    category = attrs |> value(:category) |> normalize_string()
    message = value(attrs, :message)
    retryable = value(attrs, :retryable, false)
    ambiguous = value(attrs, :ambiguous, false)
    evidence_ref = value(attrs, :evidence_ref)

    if ContractSupport.known_fields?(attrs, @fields) and category in @categories and
         present_string?(message) and is_boolean(retryable) and
         is_boolean(ambiguous) and optional_string?(evidence_ref) do
      {:ok,
       %__MODULE__{
         category: category,
         message: message,
         retryable: retryable,
         ambiguous: ambiguous,
         evidence_ref: evidence_ref
       }}
    else
      {:error, :invalid_runtime_error}
    end
  end

  def new(_attrs), do: {:error, :invalid_runtime_error}

  def new!(attrs) do
    case new(attrs) do
      {:ok, error} -> error
      {:error, reason} -> raise ArgumentError, Atom.to_string(reason)
    end
  end

  def categories, do: @categories

  defp value(attrs, key, default \\ nil),
    do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))

  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value), do: value
  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
  defp optional_string?(nil), do: true
  defp optional_string?(value), do: present_string?(value)
end

defmodule ExecutionPlane.ActiveExecution do
  @moduledoc "Opaque admitted execution/session identity returned by Runtime Client start."

  alias ExecutionPlane.ExecutionRef
  alias ExecutionPlane.Runtime.ContractSupport

  @states ~w(accepted running backpressured completed failed cancelled ambiguous)
  @terminal_states ~w(completed failed cancelled ambiguous)
  @fields [
    :contract_version,
    :execution_ref,
    :session_ref,
    :admission_decision_ref,
    :node_id,
    :lane_id,
    :state,
    :started_at,
    :fence,
    :receipt_ref
  ]
  @required @fields -- [:receipt_ref]
  @enforce_keys @required
  defstruct @fields

  @type t :: %__MODULE__{}

  def states, do: @states
  def terminal_states, do: @terminal_states

  def new(%__MODULE__{} = active), do: validate(active)

  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = ContractSupport.attrs(attrs)

    with true <- ContractSupport.known_fields?(attrs, @fields),
         {:ok, execution_ref} <- execution_ref(value(attrs, :execution_ref)) do
      active = %__MODULE__{
        contract_version:
          value(attrs, :contract_version, ExecutionPlane.ContractVersion.current()),
        execution_ref: execution_ref,
        session_ref: value(attrs, :session_ref),
        admission_decision_ref: value(attrs, :admission_decision_ref),
        node_id: value(attrs, :node_id),
        lane_id: value(attrs, :lane_id),
        state: normalize_string(value(attrs, :state)),
        started_at: value(attrs, :started_at),
        fence: value(attrs, :fence),
        receipt_ref: value(attrs, :receipt_ref)
      }

      validate(active)
    else
      false -> {:error, :invalid_active_execution}
      {:error, _reason} = error -> error
    end
  end

  def new(_attrs), do: {:error, :invalid_active_execution}

  def new!(attrs) do
    case new(attrs) do
      {:ok, active} -> active
      {:error, reason} -> raise ArgumentError, "invalid active execution: #{inspect(reason)}"
    end
  end

  def dump(%__MODULE__{} = active) do
    active
    |> Map.from_struct()
    |> Map.update!(:execution_ref, &ExecutionRef.dump/1)
    |> Map.reject(fn {_key, nested} -> is_nil(nested) end)
  end

  def terminal?(%__MODULE__{state: state}), do: state in @terminal_states

  defp validate(%__MODULE__{} = active) do
    strings = [active.session_ref, active.admission_decision_ref, active.node_id, active.lane_id]
    terminal_receipt? = not terminal?(active) or present_string?(active.receipt_ref)

    if ExecutionPlane.ContractVersion.compatible?(active.contract_version) and
         Enum.all?(strings, &present_string?/1) and active.state in @states and
         is_struct(active.started_at, DateTime) and is_integer(active.fence) and active.fence >= 0 and
         optional_string?(active.receipt_ref) and terminal_receipt? do
      {:ok, active}
    else
      {:error, :invalid_active_execution}
    end
  end

  defp execution_ref(%ExecutionRef{} = ref), do: ExecutionRef.new(ref)
  defp execution_ref(value) when is_binary(value), do: ExecutionRef.new(ref: value)
  defp execution_ref(nil), do: {:error, :invalid_execution_ref}
  defp execution_ref(value), do: ExecutionRef.new(value)

  defp value(attrs, key, default \\ nil),
    do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))

  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value), do: value
  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
  defp optional_string?(nil), do: true
  defp optional_string?(value), do: present_string?(value)
end

defmodule ExecutionPlane.Runtime.Status do
  @moduledoc "Serializable Runtime Client lifecycle status."

  alias ExecutionPlane.{ActiveExecution, ExecutionRef}
  alias ExecutionPlane.Runtime.{ContractSupport, Error}

  @fields [:execution_ref, :state, :sequence, :input_open, :output_open, :receipt_ref, :error]
  @enforce_keys [:execution_ref, :state, :sequence, :input_open, :output_open]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = ContractSupport.attrs(attrs)

    with true <- ContractSupport.known_fields?(attrs, @fields),
         {:ok, execution_ref} <- execution_ref(value(attrs, :execution_ref)),
         {:ok, error} <- optional_error(value(attrs, :error)) do
      status = %__MODULE__{
        execution_ref: execution_ref,
        state: normalize_string(value(attrs, :state)),
        sequence: value(attrs, :sequence),
        input_open: value(attrs, :input_open),
        output_open: value(attrs, :output_open),
        receipt_ref: value(attrs, :receipt_ref),
        error: error
      }

      validate(status)
    else
      false -> {:error, :invalid_runtime_status}
      {:error, _reason} = error -> error
    end
  end

  def new(_attrs), do: {:error, :invalid_runtime_status}

  def new!(attrs) do
    case new(attrs) do
      {:ok, status} -> status
      {:error, reason} -> raise ArgumentError, "invalid runtime status: #{inspect(reason)}"
    end
  end

  def terminal?(%__MODULE__{state: state}), do: state in ActiveExecution.terminal_states()

  defp validate(%__MODULE__{} = status) do
    terminal_closed? = not terminal?(status) or (not status.input_open and not status.output_open)
    terminal_receipt? = not terminal?(status) or present_string?(status.receipt_ref)

    if status.state in ActiveExecution.states() and is_integer(status.sequence) and
         status.sequence >= 0 and is_boolean(status.input_open) and is_boolean(status.output_open) and
         optional_string?(status.receipt_ref) and terminal_closed? and terminal_receipt? do
      {:ok, status}
    else
      {:error, :invalid_runtime_status}
    end
  end

  defp execution_ref(%ExecutionRef{} = ref), do: ExecutionRef.new(ref)
  defp execution_ref(value) when is_binary(value), do: ExecutionRef.new(ref: value)
  defp execution_ref(nil), do: {:error, :invalid_execution_ref}
  defp execution_ref(value), do: ExecutionRef.new(value)
  defp optional_error(nil), do: {:ok, nil}
  defp optional_error(%Error{} = error), do: {:ok, error}
  defp optional_error(attrs), do: Error.new(attrs)
  defp value(attrs, key), do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value), do: value
  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
  defp optional_string?(nil), do: true
  defp optional_string?(value), do: present_string?(value)
end

defmodule ExecutionPlane.Runtime.Event do
  @moduledoc "Ordered incremental event emitted after Runtime Client subscription."

  alias ExecutionPlane.ExecutionRef
  alias ExecutionPlane.Runtime.ContractSupport

  @kinds ~w(started output backpressure input_closed status receipt error)
  @fields [:execution_ref, :sequence, :kind, :emitted_at, :payload]
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = ContractSupport.attrs(attrs)

    with true <- ContractSupport.known_fields?(attrs, @fields),
         {:ok, execution_ref} <- execution_ref(value(attrs, :execution_ref)),
         {:ok, _encoded} <- ExecutionPlane.Codec.encode(value(attrs, :payload)) do
      event = %__MODULE__{
        execution_ref: execution_ref,
        sequence: value(attrs, :sequence),
        kind: normalize_string(value(attrs, :kind)),
        emitted_at: value(attrs, :emitted_at),
        payload: value(attrs, :payload)
      }

      if is_integer(event.sequence) and event.sequence > 0 and event.kind in @kinds and
           is_struct(event.emitted_at, DateTime) do
        {:ok, event}
      else
        {:error, :invalid_runtime_event}
      end
    else
      false -> {:error, :invalid_runtime_event}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_attrs), do: {:error, :invalid_runtime_event}

  def new!(attrs) do
    case new(attrs) do
      {:ok, event} -> event
      {:error, reason} -> raise ArgumentError, "invalid runtime event: #{inspect(reason)}"
    end
  end

  defp execution_ref(%ExecutionRef{} = ref), do: ExecutionRef.new(ref)
  defp execution_ref(value) when is_binary(value), do: ExecutionRef.new(ref: value)
  defp execution_ref(nil), do: {:error, :invalid_execution_ref}
  defp execution_ref(value), do: ExecutionRef.new(value)
  defp value(attrs, key), do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value), do: value
end

defmodule ExecutionPlane.Runtime.Lifecycle do
  @moduledoc "Pure lifecycle validation shared by Runtime Client implementations."

  alias ExecutionPlane.ActiveExecution

  @transitions %{
    "accepted" => ~w(running failed cancelled ambiguous),
    "running" => ~w(backpressured completed failed cancelled ambiguous),
    "backpressured" => ~w(running completed failed cancelled ambiguous),
    "completed" => [],
    "failed" => [],
    "cancelled" => [],
    "ambiguous" => []
  }

  def transition(%ActiveExecution{} = active, next_state, receipt_ref \\ nil) do
    next_state = if is_atom(next_state), do: Atom.to_string(next_state), else: next_state

    if next_state in Map.fetch!(@transitions, active.state) do
      ActiveExecution.new(%{active | state: next_state, receipt_ref: receipt_ref})
    else
      {:error, :invalid_execution_transition}
    end
  end
end

defmodule ExecutionPlane.Family.Support do
  @moduledoc false

  def attrs(%_{} = value), do: Map.from_struct(value)
  def attrs(value) when is_list(value), do: Map.new(value)
  def attrs(value) when is_map(value), do: value
  def attrs(_value), do: %{}

  def value(attrs, key, default \\ nil),
    do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))

  def string?(value), do: is_binary(value) and String.trim(value) != ""
  def string_list?(values), do: is_list(values) and Enum.all?(values, &string?/1)
  def datetime?(%DateTime{}), do: true
  def datetime?(_value), do: false

  def known_fields?(attrs, fields) do
    allowed = MapSet.new(Enum.flat_map(fields, &[&1, Atom.to_string(&1)]))
    Enum.all?(Map.keys(attrs), &MapSet.member?(allowed, &1))
  end

  def safe_map?(value) when is_map(value) do
    match?({:ok, _encoded}, ExecutionPlane.Codec.encode(value))
  end

  def safe_map?(_value), do: false
end

defmodule ExecutionPlane.Family.ProcessRequest do
  @moduledoc "Validated process-family start contract."

  alias ExecutionPlane.Family.Support, as: S

  @stdin_modes ~w(none pipe pty)
  @fields [
    :command_ref,
    :executable,
    :arguments,
    :working_directory_ref,
    :environment_materialization_ref,
    :stdin_mode,
    :deadline_at
  ]
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = S.attrs(attrs)
    stdin_mode = attrs |> S.value(:stdin_mode) |> normalize_string()

    request = %__MODULE__{
      command_ref: S.value(attrs, :command_ref),
      executable: S.value(attrs, :executable),
      arguments: S.value(attrs, :arguments, []),
      working_directory_ref: S.value(attrs, :working_directory_ref),
      environment_materialization_ref: S.value(attrs, :environment_materialization_ref),
      stdin_mode: stdin_mode,
      deadline_at: S.value(attrs, :deadline_at)
    }

    strings = [
      request.command_ref,
      request.executable,
      request.working_directory_ref,
      request.environment_materialization_ref
    ]

    if S.known_fields?(attrs, @fields) and Enum.all?(strings, &S.string?/1) and
         S.string_list?(request.arguments) and
         request.stdin_mode in @stdin_modes and S.datetime?(request.deadline_at) do
      {:ok, request}
    else
      {:error, :invalid_process_request}
    end
  end

  def new(_attrs), do: {:error, :invalid_process_request}
  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value), do: value
end

defmodule ExecutionPlane.Family.HTTPRequest do
  @moduledoc "Validated unary or incremental HTTP-family request contract."

  alias ExecutionPlane.Family.Support, as: S

  @methods ~w(GET POST PUT PATCH DELETE)
  @response_modes ~w(unary incremental)
  @required [
    :request_ref,
    :endpoint_ref,
    :method,
    :path,
    :header_policy_ref,
    :response_mode,
    :idempotency_key,
    :deadline_at
  ]
  @fields @required ++ [:body_artifact_ref]
  @enforce_keys @required
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = S.attrs(attrs)

    request = %__MODULE__{
      request_ref: S.value(attrs, :request_ref),
      endpoint_ref: S.value(attrs, :endpoint_ref),
      method: attrs |> S.value(:method) |> normalize_method(),
      path: S.value(attrs, :path),
      header_policy_ref: S.value(attrs, :header_policy_ref),
      response_mode: attrs |> S.value(:response_mode) |> normalize_string(),
      idempotency_key: S.value(attrs, :idempotency_key),
      deadline_at: S.value(attrs, :deadline_at),
      body_artifact_ref: S.value(attrs, :body_artifact_ref)
    }

    strings = [
      request.request_ref,
      request.endpoint_ref,
      request.path,
      request.header_policy_ref,
      request.idempotency_key
    ]

    if S.known_fields?(attrs, @fields) and Enum.all?(strings, &S.string?/1) and
         String.starts_with?(request.path, "/") and
         request.method in @methods and request.response_mode in @response_modes and
         (is_nil(request.body_artifact_ref) or S.string?(request.body_artifact_ref)) and
         S.datetime?(request.deadline_at) do
      {:ok, request}
    else
      {:error, :invalid_http_request}
    end
  end

  def new(_attrs), do: {:error, :invalid_http_request}

  defp normalize_method(value) when is_atom(value),
    do: value |> Atom.to_string() |> String.upcase()

  defp normalize_method(value) when is_binary(value), do: String.upcase(value)
  defp normalize_method(value), do: value
  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value), do: value
end

defmodule ExecutionPlane.Family.WebSocketRequest do
  @moduledoc "Validated WebSocket connect and resume contract."

  alias ExecutionPlane.Family.Support, as: S

  @required [
    :connection_ref,
    :endpoint_ref,
    :subprotocols,
    :materialization_ref,
    :backpressure_limit,
    :deadline_at
  ]
  @fields @required ++ [:resume_ref]
  @enforce_keys @required
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = S.attrs(attrs)

    request = %__MODULE__{
      connection_ref: S.value(attrs, :connection_ref),
      endpoint_ref: S.value(attrs, :endpoint_ref),
      subprotocols: S.value(attrs, :subprotocols, []),
      materialization_ref: S.value(attrs, :materialization_ref),
      backpressure_limit: S.value(attrs, :backpressure_limit),
      deadline_at: S.value(attrs, :deadline_at),
      resume_ref: S.value(attrs, :resume_ref)
    }

    strings = [request.connection_ref, request.endpoint_ref, request.materialization_ref]

    if S.known_fields?(attrs, @fields) and Enum.all?(strings, &S.string?/1) and
         S.string_list?(request.subprotocols) and
         is_integer(request.backpressure_limit) and request.backpressure_limit > 0 and
         (is_nil(request.resume_ref) or S.string?(request.resume_ref)) and
         S.datetime?(request.deadline_at) do
      {:ok, request}
    else
      {:error, :invalid_websocket_request}
    end
  end

  def new(_attrs), do: {:error, :invalid_websocket_request}
end

defmodule ExecutionPlane.Family.ProcessGateway do
  @moduledoc "Process lifecycle without flattening interactive input and termination."
  @callback start(ExecutionPlane.Family.ProcessRequest.t(), keyword()) ::
              {:ok, ExecutionPlane.ActiveExecution.t()} | {:error, term()}
  @callback attach(ExecutionPlane.ExecutionRef.t(), pid(), keyword()) :: :ok | {:error, term()}
  @callback send_input(ExecutionPlane.ExecutionRef.t(), iodata(), keyword()) ::
              :ok | {:error, term()}
  @callback end_input(ExecutionPlane.ExecutionRef.t(), keyword()) :: :ok | {:error, term()}
  @callback status(ExecutionPlane.ExecutionRef.t(), keyword()) ::
              {:ok, ExecutionPlane.Runtime.Status.t()} | {:error, term()}
  @callback cancel(ExecutionPlane.ExecutionRef.t(), keyword()) :: :ok | {:error, term()}
  @callback terminate(ExecutionPlane.ExecutionRef.t(), keyword()) :: :ok | {:error, term()}
end

defmodule ExecutionPlane.Family.HTTPGateway do
  @moduledoc "HTTP unary/incremental lifecycle with explicit demand and cancellation."
  @callback unary(ExecutionPlane.Family.HTTPRequest.t(), keyword()) ::
              {:ok, ExecutionPlane.ExecutionResult.t()} | {:error, term()}
  @callback stream(ExecutionPlane.Family.HTTPRequest.t(), pid(), keyword()) ::
              {:ok, ExecutionPlane.ActiveExecution.t()} | {:error, term()}
  @callback demand(ExecutionPlane.ExecutionRef.t(), pos_integer(), keyword()) ::
              :ok | {:error, term()}
  @callback status(ExecutionPlane.ExecutionRef.t(), keyword()) ::
              {:ok, ExecutionPlane.Runtime.Status.t()} | {:error, term()}
  @callback cancel(ExecutionPlane.ExecutionRef.t(), keyword()) :: :ok | {:error, term()}
end

defmodule ExecutionPlane.Family.WebSocketGateway do
  @moduledoc "WebSocket connect/send/backpressure/reconnect/revocation/close lifecycle."
  @callback connect(ExecutionPlane.Family.WebSocketRequest.t(), keyword()) ::
              {:ok, ExecutionPlane.ActiveExecution.t()} | {:error, term()}
  @callback subscribe(ExecutionPlane.ExecutionRef.t(), pid(), keyword()) :: :ok | {:error, term()}
  @callback send(ExecutionPlane.ExecutionRef.t(), iodata() | map(), keyword()) ::
              :ok | {:error, term()}
  @callback demand(ExecutionPlane.ExecutionRef.t(), pos_integer(), keyword()) ::
              :ok | {:error, term()}
  @callback reconnect(
              ExecutionPlane.ExecutionRef.t(),
              ExecutionPlane.Family.WebSocketRequest.t(),
              keyword()
            ) ::
              {:ok, ExecutionPlane.ActiveExecution.t()} | {:error, term()}
  @callback status(ExecutionPlane.ExecutionRef.t(), keyword()) ::
              {:ok, ExecutionPlane.Runtime.Status.t()} | {:error, term()}
  @callback close(ExecutionPlane.ExecutionRef.t(), keyword()) :: :ok | {:error, term()}
end
