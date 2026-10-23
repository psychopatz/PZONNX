# PZONNX Roadmap

Status: **experimental — active**

## Phase history

P0-P8 established the first execution foundation:

- P0 binary/protobuf and real ONNX parsing;
- P1 model indexing/compatibility;
- P2/P3 graph/operator execution;
- P4 transformer-style fixture;
- P5 one-token tiny-LM fixture;
- P6 resumable/quantized execution;
- P7 numeric TTS fixture;
- P8 public/fallback integration surface.

A later real-model probe executed a 408-node quantized tiny-LLM ONNX graph in host Lua and produced reference-consistent next-token evidence. Native testing then exposed main-thread stalls; MatMul/MatMulInteger now have resumable kernel state.

These are preserved foundation, **not parent-goal completion**.

The prior "P8 complete / only live testing remains" roadmap conclusion is superseded by the clarified objective: a model-agnostic generative inference runtime.

## P9 — Model Store & Model-Agnostic Discovery

Goal: make user-supplied models discoverable without filesystem enumeration or source-code edits.

### P9A — user model store + ledger

Authoritative user location:

```text
Zomboid/Lua/Models/
Zomboid/Lua/Models/ledger.txt
```

Acceptance:

- separate user-file IO adapter from packaged fixture IO;
- ledger reads one relative model entry path per nonblank/non-comment line;
- traversal, absolute paths, drive/network paths, and root escape are rejected;
- missing/invalid entries remain visible individually and do not abort registry refresh;
- registry startup is lightweight and does not parse all ONNX models;
- public refresh/list/get entry APIs exist;
- host tests and bounded PZ probe cover ledger parsing and path safety.

### P9B — ModelPackage

Acceptance:

- entry file defines package root;
- known config/tokenizer companion files can be probed without directory enumeration;
- multiple ONNX entry conventions can be represented;
- external tensor file paths are resolved relative to the package/model under strict root safety;
- package metadata remains lazy.

### P9C — ModelProfile

Acceptance:

- profile identifies task/generation shape where evidence supports it;
- input/output roles are mapped without TinyLLM-specific source edits;
- profile records logits, attention/position inputs, cache patterns, layer/cache counts where derivable;
- special-token/context/vocab metadata is captured when available;
- detection source/confidence/missing fields are explicit;
- incompatible models remain inspectable.

### P9D — generic model probe

Acceptance:

- one generic probe can inspect an arbitrary ledger-selected model and emit parse/profile/compatibility/input-output evidence;
- TinyLLM is only one regression target;
- at least one second structurally different decoder export is inspected without adding a model-specific adapter.

## P10 — ONNX Compliance Expansion & Model Package IO

Goal: close generic execution gaps exposed by real model profiles.

Acceptance includes:

- external initializer loading;
- opset-aware operator dispatch/semantics;
- required initializer/runtime datatypes such as FP16/BF16/int32/int64 when demanded by selected models;
- optional/missing graph inputs handled according to ONNX semantics;
- multi-file/split model representation when required;
- compatibility report distinguishes parse, profile, datatype, operator, and execution gaps.

Do not implement speculative breadth; prioritize requirements observed in real target models.

## P11 — Tokenizer Runtime

Goal: convert user text to/from model token IDs entirely inside the supported runtime.

Acceptance:

- tokenizer assets are loaded through ModelPackage;
- at least the tokenizer format required by the selected real decoder model is implemented with reference vectors;
- BOS/EOS/PAD/special-token rules are profile/config driven;
- encode/decode round trips have trusted external references;
- unsupported tokenizer features fail explicitly.

Additional tokenizer families are added from real model demand.

## P12 — Generic Decoder Runtime

Goal: perform actual autoregressive text generation rather than one forward-pass token probing.

Acceptance:

- prompt prefill from tokenized text;
- automatic construction of model input tensors from ModelProfile;
- KV-cache initialization, capture, reuse, and update;
- subsequent decode sends only the new token/cache state where the model contract permits;
- output logits are taken from the correct final sequence position;
- multi-token generation advances incrementally;
- EOS/maximum-token cancellation works;
- no TinyLLM-specific adapter is required for a recognized compatible decoder.

## P13 — Sampling & Generation Controls

Goal: provide standard model-agnostic token selection.

Acceptance:

- deterministic greedy path;
- temperature;
- top-k;
- top-p;
- repetition/logit penalties only where semantics are explicitly defined;
- seedable/random behavior where PZ Lua permits deterministic testing;
- EOS and stop handling;
- generation configuration can come from model metadata plus caller overrides.

## P14 — Performance Planner, Profiler & Optimized Kernels

Goal: make inference measurable, responsive, and materially faster while preserving correctness.

### P14A profiler

Record per-node/per-operator:

- invocation count;
- dimensions/element counts;
- elapsed time where supported;
- scheduler work;
- initializer/storage behavior;
- major allocation/liveness observations.

Optimization priority must be driven by measured hotspots.

### P14B cooperative kernels

Extend sub-node resumability beyond MatMul/MatMulInteger to any real-model hotspot capable of blocking a frame.

### P14C optimized execution

Candidate work:

- specialized flat-index MatMul/MatMulInteger paths;
- fused quantized linear kernels;
- constant folding;
- safe graph/subgraph fusion;
- precomputed indexing/strides;
- scratch reuse;
- liveness-based value release;
- initializer resident/paged/streamed policy.

Acceptance requires before/after measurements and unchanged declared numerical results.

## P15 — Multi-Family Compatibility

Goal: prove architecture agnosticism across multiple real decoder families/exports.

Target classes may include Llama-compatible, Qwen, Mistral, Gemma/Phi-class exports, selected by available ONNX artifacts and runtime feasibility.

Acceptance:

- at least three structurally meaningful model packages are profiled;
- at least two distinct decoder families complete reference-consistent generation without model-specific hard-coded Chat/TinyLM paths;
- unsupported families produce actionable compatibility gaps;
- "compatible" is reported from runtime evidence, not model-name whitelists.

Large parameter count is not itself an acceptance requirement.

## P16 — Product API & Real Chat UI

Goal: expose actual generative inference to users/adopters.

Acceptance:

- public model registry APIs;
- public generator/job APIs;
- load/unload/cancel/progress;
- model selection from ledger;
- real text prompt input uses the tokenizer;
- generated tokens stream/decode into readable text;
- diagnostic mode retains raw token/logit/profile/profiler visibility;
- the game remains responsive under bounded scheduling.

The old Tiny-LLM chat probe remains a diagnostic regression surface until superseded.

## P17 — Model-Agnostic TTS / Pipeline Expansion

Goal: apply the same model-store/profile/execution principles to usable ONNX TTS or other supported neural pipelines.

Acceptance is defined from a selected real pipeline after the LLM runtime stabilizes. Do not let TTS-specific requirements distort the generic LLM execution core.

## Parent completion

PZONNX is not complete because a model parses, one token is produced, TinyLLM runs, or P0-P8 tests pass.

The parent goal reaches developer-side completion only when the model-store, generic model profiling, tokenizer, KV-backed generation, sampling, measured performance/runtime responsiveness, multi-family compatibility, and real text-generation API/UI are implemented to the accepted roadmap boundaries, or a hard technical limitation is demonstrated reproducibly.
