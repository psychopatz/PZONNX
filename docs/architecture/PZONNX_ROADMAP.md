# PZONNX Roadmap

Status: **experimental — active**

The roadmap is one parent implementation assignment. Completing a phase does not complete the parent goal. The agent should continue through all developer-implementable mandatory phases without waiting for a new `/goal`.

See `PZONNX_ACCEPTANCE.md` for the evidence-lane and non-blocking-native-gate rules.

## P0 — Binary and protobuf foundation

Goal: establish byte-correct binary input and the protobuf primitives needed to parse real ONNX files.

### P0A — packaged binary path

Acceptance:

- Build 42.20 mod loads;
- deterministic binary fixture exists;
- byte reads, offsets, varints, fixed32, float32, and length-delimited fields are implemented;
- malformed/truncated fields fail explicitly;
- unknown protobuf fields can be skipped safely;
- a bounded in-game probe exists.

Current status: **source implemented; native PZ runtime evidence open**.

The open P0A native gate does not prevent developer-side P0B work.

### P0B — real ONNX top-level parse

Acceptance:

- development tooling generates a genuine minimal ONNX fixture;
- PZONNX parses enough ModelProto structure to identify IR version, producer metadata, opset imports, and graph envelope;
- trusted external inspection agrees with those values;
- unknown fields remain skippable;
- truncation/malformed input produces actionable errors;
- a PZ runtime probe exists for the same fixture.

P0 is fully accepted only when the required native evidence is eventually captured, but developer work may continue while native gates remain open.

## P1 — ONNX model loading and compatibility inspection

Goal: parse the subset of ModelProto, GraphProto, NodeProto, TensorProto, AttributeProto, ValueInfoProto, and opset imports required by actual target fixtures/models.

Acceptance:

- graph inputs/outputs/nodes/initializers are represented;
- tensor metadata and raw-data locations are correct;
- loader emits an operator/opset/datatype inventory;
- unsupported features report actionable errors;
- trusted external inspection agrees with the loaded graph metadata;
- large initializers are indexed/lazy where needed rather than blindly expanded into boxed Lua scalars;
- bounded PZ runtime probe exists.

## P2 — tiny graph execution

Goal: execute a genuine small ONNX neural network in Kahlua.

Initial target: a linear graph such as `MatMul -> Add`.

Acceptance:

- input tensor supplied through a PZONNX Session-like public API;
- required initializer values decode correctly;
- graph executes through PZONNX operator code only;
- result matches ONNX Runtime reference within documented tolerance;
- no native/custom-Java/external inference path is involved;
- a bounded in-game execution probe exists.

This is the first hard end-to-end inference proof.

## P3 — reusable operator runtime

Goal: move from a one-off graph to reusable tensor/operator infrastructure.

Operator support is earned from real exported model requirements, not speculative breadth.

Likely families include:

- elementwise/broadcast arithmetic;
- MatMul/Gemm;
- Gather;
- Reshape/Transpose/Concat/Slice;
- Softmax;
- Cast;
- reductions;
- normalization;
- activation functions.

Acceptance:

- operator registry declares supported opset/type/attribute combinations;
- deterministic shape/broadcast semantics;
- focused fixture matrix per supported path;
- explicit rejection of unsupported combinations;
- reusable/bounded scratch buffers;
- compatibility report accurately predicts whether the selected model can execute.

## P4 — transformer coverage

Goal: support the exact exported ONNX graph of one selected tiny transformer.

Acceptance:

- selected model/export is frozen and documented;
- operator inventory is recorded;
- every required operator/type path has focused reference fixtures;
- one forward pass reaches logits matching the trusted reference;
- initial context length is deliberately bounded;
- tokenizer/model adapter remains separate from the generic runtime;
- memory behavior is measured honestly.

## P5 — tiny LLM one-token proof

Goal: produce one correct next token from a selected tiny model inside PZONNX.

Candidate target: a TinyStories-class model around 15M parameters, subject to actual export/operator/memory feasibility.

Acceptance:

- model loads without expanding the full weight set into boxed Lua scalars;
- fixed prompt produces reference-consistent logits and token choice;
- generation uses only PZONNX runtime execution;
- elapsed time and observed memory behavior are recorded;
- a one-token result is accepted for correctness even if it is initially very slow.

Performance is not the first proof gate.

## P6 — resumable and quantized inference

Goal: make long inference cooperative with the game loop and reduce memory/compute cost without losing accepted correctness.

Acceptance:

- bounded `InferenceJob.step(...)` execution;
- cancellation and cleanup;
- no unbounded frame-blocking loop in the supported path;
- baseline measurements exist before optimization;
- at least one meaningful optimization is demonstrated, such as buffer reuse, blockwise initializer access, quantization, or cache reuse;
- optimized path remains within declared numerical acceptance.

## P7 — TTS proof

Goal: execute a selected small ONNX TTS path through PZONNX.

The first neural proof may start from precomputed phoneme/token IDs to isolate neural inference from phonemization.

Acceptance:

- selected model and operator inventory documented;
- fixed input reaches PCM/numeric audio output through PZONNX;
- output is compared with a trusted reference;
- no native/custom-Java/external inference dependency;
- infeasible stages are documented precisely rather than hidden;
- runtime scheduling remains bounded.

## P8 — integration and hardening

Goal: make PZONNX consumable by Project Hoomans/PBrainz or another adopter without coupling the generic runtime to that project.

Acceptance:

- stable small public API;
- model compatibility inspection API;
- bounded job lifecycle;
- useful diagnostics and probe surfaces;
- adopter integrates PZONNX as a dependency rather than copying runtime code;
- runtime failure degrades cleanly to the adopter's existing non-LLM/non-TTS path;
- required native gates are collected for final handoff.

## Parent completion rule

The parent goal is complete only when:

- all approved mandatory developer-side phases are implemented;
- required host/reference acceptance is satisfied;
- required native PZ probes are ready and, where available, have passed;
- real-model LLM and TTS proofs are either accepted or a hard technical limitation has been reproducibly demonstrated;
- no mandatory roadmap item remains silently deferred.

If only final user-owned native checks remain, report **READY FOR USER LIVE TEST**, not COMPLETED and not BLOCKED.
