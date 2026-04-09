# ADR-010: `self_hosted_inference_core` And `llama_cpp_sdk` Stay As Service-Family Layers

## Decision

- `/home/home/p/g/n/self_hosted_inference_core` remains the service-runtime family kit
- `/home/home/p/g/n/llama_cpp_sdk` remains a backend package

They adopt Execution Plane process/runtime contracts below them.

## Rationale

This preserves the existing good family layering while unifying the lower substrate.

Durable readiness, health, attachability, and lease meaning stay above the lower runtime plane.
