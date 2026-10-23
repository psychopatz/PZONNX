# PZONNX Roadmap

Status: experimental, active.

## P0 — Binary and protobuf foundation

Goal: establish byte-correct binary input and the protobuf primitives needed to parse ONNX.

Acceptance:

- PZONNX loads as an ordinary Build 42.20 Lua mod.
- A binary fixture can be opened from the supported mod/runtime path.
- byte reads, offsets, varints, fixed32/fixed64 handling, and length-delimited fields are tested;
- malformed/truncated fields fail explicitly;
- unknown protobuf fields can be skipped safely;
- at least one real ONNX fixture can be inspected far enough to prove the parser is reading the intended ModelProto structure.

## P1 — ONNX model loading and compatibility inspection

Goal: parse the subset of ModelProto, GraphProto, NodeProto, TensorProto, AttributeProto, ValueInfoProto, and opset imports required by the first fixtures.

Acceptance:

- graph inputs/outputs/nodes/initializers are represented;
- tensor metadata and raw-data locations are correct;
- model loader emits an operator/opset inventory;
- unsupported wire/model features report actionable errors;
- a trusted external inspector agrees with PZONNX's graph metadata.

## P2 — Tiny graph execution

Goal: execute a genuine small ONNX network in Kahlua.

Initial target: one linear graph such as `MatMul -> Add`.

Acceptance:

- input tensor supplied through PZONNX Session;
- required initializer values decoded correctly;
- graph executes entirely in Lua/Kahlua;
- result matches ONNX Runtime reference within documented tolerance;
- no native/custom-Java inference path is involved.

This is the first hard end-to-end proof.

## P3 — Reusable operator runtime

Goal: move from a one-off graph to reusable tensor/operator infrastructure.

Candidate capabilities are earned from fixtures, not predeclared. Likely early operators include Add, Mul, MatMul/Gemm, Gather, Reshape, Transpose, Softmax, Concat, Slice, Cast, reductions, normalization, and activation functions.

Acceptance:

- operator registry with explicit opset/type/attribute support;
- deterministic shape/broadcast rules;
- multi-op fixture matrix;
- reusable temporary buffers;
- compatibility report accurately rejects unsupported cases.

## P4 — Transformer coverage

Goal: support the exact exported ONNX graph of a selected tiny transformer.

Acceptance:

- model operator inventory is recorded;
- every required operator/type path has a focused fixture;
- one forward pass reaches logits matching the trusted reference;
- context length is deliberately bounded during the first proof;
- tokenizer/model adapter is separate from generic ONNX execution.

## P5 — Tiny LLM one-token proof

Goal: produce one correct next token from a selected tiny model inside PZ.

Candidate target: a TinyStories-class model around 15M parameters, subject to export/operator feasibility.

Acceptance:

- model loads without converting the full weight set into boxed Lua scalars;
- a fixed prompt produces reference-consistent logits/token choice;
- generation uses the PZONNX runtime only;
- elapsed time and peak/runtime memory observations are recorded honestly.

Performance is not a gate for the first one-token proof.

## P6 — Resumable and quantized inference

Goal: make long inference cooperative with the game loop and explore meaningful speed/memory reductions.

Acceptance:

- bounded `InferenceJob.step(...)` execution;
- cancellation and cleanup;
- no frame-long unbounded loop in the supported path;
- measured baseline before optimization;
- at least one verified optimization (buffer reuse, blockwise weight access, quantization, cache reuse, or equivalent) preserves accepted numerical behavior.

## P7 — TTS proof

Goal: execute a selected small ONNX TTS path in PZONNX.

The first proof may begin from precomputed phoneme/token IDs so neural inference is isolated from text normalization/phonemization.

Acceptance:

- selected TTS model compatibility inventory;
- fixed input reaches PCM/numeric audio output through PZONNX;
- output is compared with a trusted reference;
- runtime remains free of native/custom-Java inference dependencies;
- infeasible model stages are documented rather than hidden.

## P8 — Integration and hardening

Goal: make PZONNX consumable by Project Hoomans/PBrainz or another mod without coupling the runtime to that adopter.

Acceptance:

- stable small public API;
- model compatibility inspection;
- bounded job lifecycle;
- diagnostics suitable for headless/harness testing;
- adopter integration uses PZONNX as a dependency, not copied runtime code;
- failure degrades cleanly to the adopter's existing non-LLM/non-TTS path.

## Completion rule

Finishing a phase is not finishing PZONNX.

The parent experiment remains active until all mandatory approved phases are complete, or a hard technical limitation is demonstrated with reproducible evidence and documented as the reason the goal cannot continue.
