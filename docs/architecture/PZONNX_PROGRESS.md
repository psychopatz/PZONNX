# PZONNX Progress

Last reconciled: repository bootstrap.

## Current phase

**P0 — Binary and protobuf foundation**

State: IN PROGRESS.

## Verified foundation

- Repository exists and is writable.
- Project identity is PZONNX.
- Build target is Project Zomboid 42.20.
- Runtime constraint is pure supported Lua/Kahlua; development-time external reference tooling is allowed.

## Implemented in bootstrap

- Build 42.20 mod descriptor.
- Lua bootstrap/diagnostics module.
- byte reader primitives intended for Java `DataInputStream`-like objects exposed to Lua;
- protobuf wire tag/skip primitives;
- host-side fake-stream smoke test for the binary primitives.

These are source-level bootstrap components. They are **not yet live-game accepted**.

## Not yet proven

- exact supported PZ file-open path for a packaged binary fixture;
- real in-game binary read behavior;
- parsing a real ONNX ModelProto;
- tensor loading;
- any ONNX operator execution;
- inference of any neural model.

## Next Chunk — P0A: real binary fixture path

1. Add a tiny deterministic binary/protobuf fixture and trusted expected values.
2. Implement a PZ-facing file opener behind the IO boundary using only supported APIs.
3. Add an in-game diagnostic probe that reads the fixture, validates byte offsets and varints, and emits compact pass/fail evidence.
4. Run host smoke tests where available.
5. Do not move to ONNX semantic parsing until the PZ binary read path is evidenced.

## Phase exit

P0 exits only when a genuine ONNX file is read through the supported game path and its top-level protobuf structure is correctly identified.

## Evidence labels

Use these labels in future updates:

- source-verified;
- host-test verified;
- PZ runtime verified;
- reference-runtime verified;
- partial;
- unsupported/unproven.
