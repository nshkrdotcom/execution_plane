# Service Runtime Family Design

## End-State Ownership

### Execution Plane process/runtime packages

Provide:

- spawned process lifecycle
- service attach semantics
- local / SSH / guest process placement
- raw readiness and liveness execution facts

### Service-runtime family kit

Repo:

- `/home/home/p/g/n/self_hosted_inference_core`

Keeps ownership of:

- runtime readiness interpretation
- health semantics
- lease reuse policy
- endpoint publication
- service lifecycle truth above transport

It consumes raw execution facts from the Execution Plane and projects durable meaning through the Spine.

### Backend packages

Repo:

- `/home/home/p/g/n/llama_cpp_sdk`

Keeps ownership of:

- backend-specific startup specs
- backend-specific readiness interpretation
- backend-specific config and docs

## Lifecycle Rule

Do not collapse service-runtime lifecycle into the Execution Plane.

The Execution Plane owns unsafe mechanics.

`self_hosted_inference_core` owns service-runtime semantics.

Durable service descriptors, attachability, and lease lineage must remain expressible through Spine-owned contracts rather than hidden in process state.

## Capability Waves For This Slice

### Minimal service lane

- process-backed service startup
- raw readiness / liveness facts
- attachable service handles

### Broader placement lane

- SSH and guest placement
- reusable leases
- backend-specific startup and readiness convergence

### Stronger isolation lane

- container and microVM integrations when real backends exist
- honest docs about what is actually enforced at each isolation level
