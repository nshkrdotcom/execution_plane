defmodule ExecutionPlane.Boundary do
  @moduledoc false

  defmacro defcontract(fields) do
    quote bind_quoted: [fields: fields] do
      @fields fields
      defstruct fields
      @type t :: %__MODULE__{}

      @spec new(map() | keyword() | struct()) :: {:ok, struct()} | {:error, Exception.t()}
      def new(%__MODULE__{} = value), do: {:ok, value}

      def new(attrs) do
        attrs = ExecutionPlane.Boundary.attrs(attrs)

        values =
          Enum.map(@fields, fn {key, default} ->
            {key, ExecutionPlane.Boundary.fetch(attrs, key, default)}
          end)

        {:ok, struct(__MODULE__, values)}
      rescue
        error in ArgumentError -> {:error, error}
      end

      @spec new!(map() | keyword() | struct()) :: struct()
      def new!(attrs \\ %{}) do
        case new(attrs) do
          {:ok, value} -> value
          {:error, error} -> raise error
        end
      end

      @spec load(map() | keyword() | struct()) :: {:ok, struct()} | {:error, Exception.t()}
      def load(attrs), do: new(attrs)

      @spec load!(map() | keyword() | struct()) :: struct()
      def load!(attrs), do: new!(attrs)

      @spec dump(struct()) :: map()
      def dump(%__MODULE__{} = value), do: ExecutionPlane.Boundary.dump(value, @fields)

      @spec to_json!(struct()) :: String.t()
      def to_json!(%__MODULE__{} = value), do: ExecutionPlane.Codec.encode!(value)

      @spec from_json!(String.t()) :: struct()
      def from_json!(json), do: ExecutionPlane.Codec.decode!(json, __MODULE__)

      defoverridable new: 1, new!: 1, load: 1, load!: 1, dump: 1
    end
  end

  @spec attrs(map() | keyword() | struct()) :: map()
  def attrs(%_{} = struct), do: Map.from_struct(struct)
  def attrs(attrs) when is_map(attrs), do: attrs

  def attrs(attrs) when is_list(attrs) do
    if Keyword.keyword?(attrs) do
      Map.new(attrs)
    else
      raise ArgumentError, "expected keyword list, got: #{inspect(attrs)}"
    end
  end

  def attrs(attrs),
    do: raise(ArgumentError, "expected map or keyword list, got: #{inspect(attrs)}")

  @spec fetch(map(), atom(), term()) :: term()
  def fetch(attrs, key, default) do
    Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
  end

  @spec dump(struct(), keyword()) :: map()
  def dump(value, fields) do
    Map.new(fields, fn {key, _default} ->
      {Atom.to_string(key), dump_value(Map.fetch!(value, key))}
    end)
  end

  @spec dump_value(term()) :: term()
  def dump_value(nil), do: nil
  def dump_value(true), do: true
  def dump_value(false), do: false

  def dump_value(%_{} = struct) do
    if function_exported?(struct.__struct__, :dump, 1) do
      struct.__struct__.dump(struct)
    else
      Map.from_struct(struct)
    end
  end

  def dump_value(value) when is_map(value) do
    Map.new(value, fn {key, nested} -> {to_string(key), dump_value(nested)} end)
  end

  def dump_value(value) when is_list(value), do: Enum.map(value, &dump_value/1)
  def dump_value(value) when is_atom(value), do: Atom.to_string(value)
  def dump_value(value), do: value

  @spec required_string(map(), atom()) :: String.t()
  def required_string(attrs, key) do
    case fetch(attrs, key, nil) do
      value when is_binary(value) and value != "" -> value
      value when is_atom(value) -> Atom.to_string(value)
      other -> raise ArgumentError, "#{key} must be a non-empty string, got: #{inspect(other)}"
    end
  end

  @spec string_list(term()) :: [String.t()]
  def string_list(nil), do: []
  def string_list(values) when is_list(values), do: Enum.map(values, &to_string/1)
  def string_list(value), do: raise(ArgumentError, "expected list, got: #{inspect(value)}")

  @spec stable_id(String.t()) :: String.t()
  def stable_id(prefix) when is_binary(prefix) do
    unique =
      :erlang.unique_integer([:positive, :monotonic])
      |> Integer.to_string()

    "#{prefix}-#{System.system_time(:millisecond)}-#{unique}"
  end
end

defmodule ExecutionPlane.Codec do
  @moduledoc """
  Canonical JSON codec helpers for root boundary contracts.
  """

  @spec encode!(struct() | map()) :: String.t()
  def encode!(%_{} = value) do
    value
    |> value.__struct__.dump()
    |> Jason.encode!()
  end

  def encode!(value) when is_map(value),
    do: Jason.encode!(ExecutionPlane.Boundary.dump_value(value))

  @spec decode!(String.t(), module()) :: struct()
  def decode!(json, module) when is_binary(json) and is_atom(module) do
    json
    |> Jason.decode!()
    |> module.load!()
  end

  @spec round_trip!(struct(), module()) :: struct()
  def round_trip!(%_{} = value, module \\ nil) do
    module = module || value.__struct__

    value
    |> encode!()
    |> decode!(module)
  end
end

defmodule ExecutionPlane.ContractVersion do
  @moduledoc """
  Root Execution Plane boundary contract version.
  """

  @current 1
  @stability "stable"

  @spec current() :: non_neg_integer()
  def current, do: @current

  @spec stability() :: String.t()
  def stability, do: @stability

  @spec supported_range() :: %{required(String.t()) => non_neg_integer()}
  def supported_range, do: %{"min" => @current, "max" => @current}

  @spec compatible?(term()) :: boolean()
  def compatible?(version), do: normalize(version) == @current

  @spec normalize(term()) :: non_neg_integer() | nil
  def normalize(version) when is_integer(version), do: version

  def normalize(version) when is_binary(version) do
    case Integer.parse(version) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  def normalize(_version), do: nil
end

defmodule ExecutionPlane.Provenance do
  @moduledoc """
  Execution provenance for governed node admission and direct lower-lane owners.
  """

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    kind: "node_admitted",
    owner: nil,
    admission_ref: nil,
    details: %{}
  )

  @spec node_admitted(map() | keyword()) :: t()
  def node_admitted(attrs \\ %{}),
    do: attrs |> Map.new() |> Map.put(:kind, "node_admitted") |> new!()

  @spec direct_lower_lane_owner(String.t() | atom(), map()) :: t()
  def direct_lower_lane_owner(owner, details \\ %{}) do
    new!(kind: "direct_lower_lane_owner", owner: to_string(owner), details: details)
  end

  @spec direct?(t()) :: boolean()
  def direct?(%__MODULE__{kind: "direct_lower_lane_owner"}), do: true
  def direct?(_provenance), do: false
end

defmodule ExecutionPlane.ExecutionRef do
  @moduledoc "Opaque execution reference."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    ref: nil
  )

  def new(attrs \\ %{}) do
    attrs = ExecutionPlane.Boundary.attrs(attrs)

    ref =
      ExecutionPlane.Boundary.fetch(attrs, :ref, nil) || ExecutionPlane.Boundary.stable_id("exec")

    {:ok, %__MODULE__{contract_version: ExecutionPlane.ContractVersion.current(), ref: ref}}
  rescue
    error in ArgumentError -> {:error, error}
  end
end

defmodule ExecutionPlane.Authority.Ref do
  @moduledoc "Opaque authority reference. The root carries it and never interprets policy semantics."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    ref: nil,
    payload_hash: nil,
    audience: nil,
    issued_at: nil,
    expires_at: nil,
    metadata: %{}
  )
end

defmodule ExecutionPlane.Authority.Verifier do
  @moduledoc "Authority verifier behaviour registered by node hosts."

  @callback verifier_id() :: String.t()
  @callback verify(ExecutionPlane.Authority.Ref.t() | map(), keyword()) ::
              {:ok, map()} | {:error, ExecutionPlane.Admission.Rejection.t()}
end

defmodule ExecutionPlane.Sandbox.Profile do
  @moduledoc """
  Opaque signed governance bundle authored upstream.
  """

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    profile_ref: nil,
    bundle_hash: nil,
    opaque_bundle: nil,
    metadata: %{}
  )
end

defmodule ExecutionPlane.Sandbox.AcceptableAttestation do
  @moduledoc """
  Closed set of acceptable Target attestation classes for one admission request.
  """

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    classes: [],
    priority_order: []
  )

  def new(attrs \\ %{}) do
    attrs = ExecutionPlane.Boundary.attrs(attrs)

    classes =
      attrs
      |> ExecutionPlane.Boundary.fetch(:classes, [])
      |> ExecutionPlane.Boundary.string_list()

    priority_order =
      attrs
      |> ExecutionPlane.Boundary.fetch(:priority_order, classes)
      |> ExecutionPlane.Boundary.string_list()

    {:ok,
     %__MODULE__{
       contract_version: ExecutionPlane.ContractVersion.current(),
       classes: Enum.uniq(classes),
       priority_order: Enum.uniq(priority_order)
     }}
  rescue
    error in ArgumentError -> {:error, error}
  end

  @spec intersect(t(), [String.t()]) :: [String.t()]
  def intersect(%__MODULE__{} = acceptable, attested_classes) when is_list(attested_classes) do
    attested = MapSet.new(Enum.map(attested_classes, &to_string/1))

    acceptable.priority_order
    |> Enum.filter(&MapSet.member?(attested, &1))
    |> case do
      [] ->
        acceptable.classes
        |> Enum.filter(&MapSet.member?(attested, &1))

      ordered ->
        ordered
    end
  end

  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{classes: classes}), do: classes == []
end

defmodule ExecutionPlane.Placement.Surface do
  @moduledoc "Lane-neutral placement surface contract."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    surface_kind: "local",
    family: "local",
    metadata: %{}
  )
end

defmodule ExecutionPlane.Runtime.Constraint do
  @moduledoc "Serializable runtime constraint."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    name: nil,
    value: nil,
    metadata: %{}
  )
end

defmodule ExecutionPlane.Lane.Capabilities do
  @moduledoc "Lane adapter capability descriptor."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    lane_id: nil,
    protocols: [],
    surfaces: [],
    supports_execute: true,
    supports_stream: false,
    metadata: %{}
  )
end

defmodule ExecutionPlane.Lane.Adapter do
  @moduledoc "Transport lane adapter behaviour."

  @callback lane_id() :: atom()
  @callback capabilities() :: ExecutionPlane.Lane.Capabilities.t()
  @callback validate(ExecutionPlane.ExecutionRequest.t()) ::
              :ok | {:error, ExecutionPlane.Admission.Rejection.t()}
  @callback execute(ExecutionPlane.ExecutionRequest.t(), keyword()) ::
              {:ok, ExecutionPlane.ExecutionResult.t()}
              | {:error, ExecutionPlane.ExecutionResult.t()}
  @callback stream(ExecutionPlane.ExecutionRequest.t(), keyword()) ::
              {:ok, Enumerable.t()} | {:error, ExecutionPlane.Admission.Rejection.t()}
end

defmodule ExecutionPlane.Target.Attestation do
  @moduledoc "Raw Target attestation evidence presented before routing-table admission."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    attestation_id: nil,
    attestation_type: nil,
    evidence: %{},
    presented_at: nil,
    claimed_capability_classes: [],
    metadata: %{}
  )
end

defmodule ExecutionPlane.Target.Descriptor do
  @moduledoc "Verifier-validated Target routing descriptor."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    target_id: nil,
    lane_id: nil,
    attested_capability_classes: [],
    verifier_id: nil,
    attestation_id: nil,
    attested_at: nil,
    expires_at: nil,
    metadata: %{},
    signature: nil
  )

  def new(attrs \\ %{}) do
    attrs = ExecutionPlane.Boundary.attrs(attrs)

    {:ok,
     %__MODULE__{
       contract_version: ExecutionPlane.ContractVersion.current(),
       target_id: ExecutionPlane.Boundary.required_string(attrs, :target_id),
       lane_id: ExecutionPlane.Boundary.required_string(attrs, :lane_id),
       attested_capability_classes:
         attrs
         |> ExecutionPlane.Boundary.fetch(:attested_capability_classes, [])
         |> ExecutionPlane.Boundary.string_list(),
       verifier_id: ExecutionPlane.Boundary.required_string(attrs, :verifier_id),
       attestation_id: ExecutionPlane.Boundary.fetch(attrs, :attestation_id, nil),
       attested_at: ExecutionPlane.Boundary.fetch(attrs, :attested_at, nil),
       expires_at: ExecutionPlane.Boundary.fetch(attrs, :expires_at, nil),
       metadata: ExecutionPlane.Boundary.fetch(attrs, :metadata, %{}),
       signature: ExecutionPlane.Boundary.fetch(attrs, :signature, nil)
     }}
  rescue
    error in ArgumentError -> {:error, error}
  end
end

defmodule ExecutionPlane.Target.Verifier do
  @moduledoc "Target attestation verifier behaviour."

  @callback verifier_id() :: String.t()
  @callback attestation_types() :: [String.t()]
  @callback capability_classes() :: [String.t()]
  @callback handles?(ExecutionPlane.Target.Attestation.t() | map()) :: boolean()
  @callback verify(ExecutionPlane.Target.Attestation.t() | map(), keyword()) ::
              {:ok, ExecutionPlane.Target.Descriptor.t()}
              | {:error, ExecutionPlane.Admission.Rejection.t()}
end

defmodule ExecutionPlane.Target.Client do
  @moduledoc "Node-to-Target execution client behaviour."

  @callback describe(keyword()) :: {:ok, map()} | {:error, term()}
  @callback execute(ExecutionPlane.ExecutionRequest.t(), keyword()) ::
              {:ok, ExecutionPlane.ExecutionResult.t()}
              | {:error, ExecutionPlane.ExecutionResult.t()}
  @callback stream(ExecutionPlane.ExecutionRequest.t(), keyword()) ::
              {:ok, Enumerable.t()} | {:error, ExecutionPlane.Admission.Rejection.t()}
  @callback cancel(ExecutionPlane.ExecutionRef.t(), keyword()) :: :ok | {:error, term()}
end

defmodule ExecutionPlane.Admission.Request do
  @moduledoc "Runtime-client admission request."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    request_id: nil,
    lane_id: nil,
    operation: nil,
    payload: %{},
    authority_ref: nil,
    sandbox_profile: nil,
    acceptable_attestation: ExecutionPlane.Sandbox.AcceptableAttestation.new!(),
    placement: nil,
    constraints: [],
    provenance: ExecutionPlane.Provenance.new!(),
    metadata: %{}
  )

  def new(attrs \\ %{}) do
    attrs = ExecutionPlane.Boundary.attrs(attrs)

    acceptable =
      attrs
      |> ExecutionPlane.Boundary.fetch(:acceptable_attestation, %{})
      |> ExecutionPlane.Sandbox.AcceptableAttestation.new!()

    provenance =
      attrs
      |> ExecutionPlane.Boundary.fetch(:provenance, %{})
      |> ExecutionPlane.Provenance.new!()

    {:ok,
     %__MODULE__{
       contract_version:
         ExecutionPlane.Boundary.fetch(
           attrs,
           :contract_version,
           ExecutionPlane.ContractVersion.current()
         ),
       request_id:
         ExecutionPlane.Boundary.fetch(attrs, :request_id, nil) ||
           ExecutionPlane.Boundary.stable_id("adm"),
       lane_id: ExecutionPlane.Boundary.required_string(attrs, :lane_id),
       operation: ExecutionPlane.Boundary.fetch(attrs, :operation, nil),
       payload: ExecutionPlane.Boundary.fetch(attrs, :payload, %{}),
       authority_ref: maybe_contract(attrs, :authority_ref, ExecutionPlane.Authority.Ref),
       sandbox_profile: maybe_contract(attrs, :sandbox_profile, ExecutionPlane.Sandbox.Profile),
       acceptable_attestation: acceptable,
       placement: maybe_contract(attrs, :placement, ExecutionPlane.Placement.Surface),
       constraints: ExecutionPlane.Boundary.fetch(attrs, :constraints, []),
       provenance: provenance,
       metadata: ExecutionPlane.Boundary.fetch(attrs, :metadata, %{})
     }}
  rescue
    error in ArgumentError -> {:error, error}
  end

  defp maybe_contract(attrs, key, module) do
    case ExecutionPlane.Boundary.fetch(attrs, key, nil) do
      nil -> nil
      %_{} = value -> if value.__struct__ == module, do: value, else: module.new!(value)
      value -> module.new!(value)
    end
  end
end

defmodule ExecutionPlane.Admission.Decision do
  @moduledoc "Admission decision."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    request_id: nil,
    status: "accepted",
    execution_ref: nil,
    target_id: nil,
    lane_id: nil,
    attestation_class: nil,
    reason: nil,
    evidence: []
  )
end

defmodule ExecutionPlane.Admission.Rejection do
  @moduledoc "Admission rejection."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    request_id: nil,
    reason: nil,
    message: nil,
    details: %{}
  )

  @spec new(atom() | String.t(), String.t(), map()) :: t()
  def new(reason, message, details \\ %{}) do
    new!(reason: to_string(reason), message: message, details: details)
  end
end

defmodule ExecutionPlane.ExecutionRequest do
  @moduledoc "Lane/Target execution request produced after admission."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    execution_ref: nil,
    admission_request: nil,
    target_descriptor: nil,
    lane_id: nil,
    operation: nil,
    payload: %{},
    provenance: ExecutionPlane.Provenance.new!(),
    metadata: %{}
  )
end

defmodule ExecutionPlane.ExecutionEvent do
  @moduledoc "Serializable execution event envelope."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    event_id: nil,
    execution_ref: nil,
    event_type: nil,
    payload: %{},
    emitted_at: nil,
    evidence: []
  )

  def new(attrs \\ %{}) do
    attrs = ExecutionPlane.Boundary.attrs(attrs)

    event_id =
      ExecutionPlane.Boundary.fetch(attrs, :event_id, nil) ||
        ExecutionPlane.Boundary.stable_id("event")

    {:ok,
     %__MODULE__{
       contract_version:
         ExecutionPlane.Boundary.fetch(
           attrs,
           :contract_version,
           ExecutionPlane.ContractVersion.current()
         ),
       event_id: event_id,
       execution_ref: ExecutionPlane.Boundary.fetch(attrs, :execution_ref, nil),
       event_type: ExecutionPlane.Boundary.fetch(attrs, :event_type, nil),
       payload: ExecutionPlane.Boundary.fetch(attrs, :payload, %{}),
       emitted_at: ExecutionPlane.Boundary.fetch(attrs, :emitted_at, nil),
       evidence: ExecutionPlane.Boundary.fetch(attrs, :evidence, [])
     }}
  rescue
    error in ArgumentError -> {:error, error}
  end
end

defmodule ExecutionPlane.Evidence do
  @moduledoc "Serializable execution evidence envelope."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    evidence_id: nil,
    evidence_type: nil,
    execution_ref: nil,
    request_id: nil,
    policy_bundle_hash: nil,
    target_id: nil,
    target_verifier_id: nil,
    attestation_class: nil,
    lane_id: nil,
    authority_verifier_id: nil,
    payload: %{},
    emitted_at: nil
  )

  def new(attrs \\ %{}) do
    attrs = ExecutionPlane.Boundary.attrs(attrs)

    evidence_id =
      ExecutionPlane.Boundary.fetch(attrs, :evidence_id, nil) ||
        ExecutionPlane.Boundary.stable_id("ev")

    {:ok,
     %__MODULE__{
       contract_version:
         ExecutionPlane.Boundary.fetch(
           attrs,
           :contract_version,
           ExecutionPlane.ContractVersion.current()
         ),
       evidence_id: evidence_id,
       evidence_type: ExecutionPlane.Boundary.fetch(attrs, :evidence_type, nil),
       execution_ref: ExecutionPlane.Boundary.fetch(attrs, :execution_ref, nil),
       request_id: ExecutionPlane.Boundary.fetch(attrs, :request_id, nil),
       policy_bundle_hash: ExecutionPlane.Boundary.fetch(attrs, :policy_bundle_hash, nil),
       target_id: ExecutionPlane.Boundary.fetch(attrs, :target_id, nil),
       target_verifier_id: ExecutionPlane.Boundary.fetch(attrs, :target_verifier_id, nil),
       attestation_class: ExecutionPlane.Boundary.fetch(attrs, :attestation_class, nil),
       lane_id: ExecutionPlane.Boundary.fetch(attrs, :lane_id, nil),
       authority_verifier_id: ExecutionPlane.Boundary.fetch(attrs, :authority_verifier_id, nil),
       payload: ExecutionPlane.Boundary.fetch(attrs, :payload, %{}),
       emitted_at: ExecutionPlane.Boundary.fetch(attrs, :emitted_at, nil)
     }}
  rescue
    error in ArgumentError -> {:error, error}
  end
end

defmodule ExecutionPlane.Evidence.Sink do
  @moduledoc "Evidence sink behaviour registered by node hosts."

  @callback sink_id() :: String.t()
  @callback emit(ExecutionPlane.Evidence.t(), keyword()) :: :ok | {:error, term()}
  @callback flush(keyword()) :: :ok | {:error, term()}
end

defmodule ExecutionPlane.ExecutionResult do
  @moduledoc "Serializable execution result."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    execution_ref: nil,
    status: "succeeded",
    output: %{},
    events: [],
    evidence: [],
    error: nil,
    provenance: ExecutionPlane.Provenance.new!()
  )
end

defmodule ExecutionPlane.Runtime.NodeDescriptor do
  @moduledoc "Runtime client descriptor returned by describe/1."

  import ExecutionPlane.Boundary, only: [defcontract: 1]

  defcontract(
    contract_version: ExecutionPlane.ContractVersion.current(),
    node_id: nil,
    contract_version_range: ExecutionPlane.ContractVersion.supported_range(),
    registered_lanes: [],
    registered_target_verifiers: [],
    verified_targets: [],
    authority_verifier: nil,
    registration_complete: false,
    metadata: %{}
  )
end

defmodule ExecutionPlane.Runtime.Client do
  @moduledoc "Consumer-to-node runtime client behaviour."

  @callback describe(keyword()) ::
              {:ok, ExecutionPlane.Runtime.NodeDescriptor.t()} | {:error, term()}
  @callback admit(ExecutionPlane.Admission.Request.t(), keyword()) ::
              {:ok, ExecutionPlane.Admission.Decision.t()}
              | {:error, ExecutionPlane.Admission.Rejection.t()}
  @callback execute(ExecutionPlane.Admission.Request.t(), keyword()) ::
              {:ok, ExecutionPlane.ExecutionResult.t()}
              | {:error, ExecutionPlane.ExecutionResult.t()}
  @callback stream(ExecutionPlane.Admission.Request.t(), keyword()) ::
              {:ok, Enumerable.t()} | {:error, ExecutionPlane.Admission.Rejection.t()}
  @callback cancel(ExecutionPlane.ExecutionRef.t(), keyword()) :: :ok | {:error, term()}
end
