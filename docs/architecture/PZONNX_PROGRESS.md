# PZONNX Progress

Last reconciled: real multi-family reference evidence and generic compatibility expansion.

## Parent goal

Build a model-agnostic pure-Kahlua ONNX inference runtime for Project Zomboid that can discover user-supplied compatible model packages, inspect them, tokenize text, perform KV-backed autoregressive generation, sample/decode output, and remain responsive enough for in-game use.

Parent state: **IN PROGRESS**.

## Current major phase

**P14-P17 — Measured Generative Runtime & Product Integration**

State: **ACTIVE**.

The previous P0-P8 developer-side completion statement is historical foundation, not current parent completion.

## Accepted foundation preserved

Source/host/reference evidence currently supports:

- binary/protobuf reader;
- real ONNX ModelProto parsing/indexing;
- lazy packed initializer access;
- tensor runtime and operator registry;
- numerical P2-P7 fixtures;
- resumable inference jobs;
- quantized execution paths;
- public session/fallback surfaces;
- real 13,077,992-byte quantized tiny-LLM ONNX parsing/execution in host Lua;
- 408 graph nodes completed with reference-consistent selected token evidence;
- Core-backed in-game forward-pass/token probe;
- resumable MatMul/MatMulInteger kernel machinery after native freeze feedback.

## Native evidence

Observed native feedback includes:

- P0A/P0B reached stock Project Zomboid;
- the debug/chat probe became reachable after integration corrections;
- the first real-model inference attempt caused a long apparent game freeze;
- that stall was traced to large atomic matrix work;
- source now slices MatMul/MatMulInteger into resumable kernel work and exposes Cancel.

Still open:

- verify in stock PZ that sliced inference keeps the game responsive enough to interact/cancel;
- verify real-model in-game numerical output after the scheduler change.

These gates remain important, but they do not block P9 source implementation.

## Product gap discovered

The existing GUI is not a real chat system:

- prompt text is not sent to the model;
- the input is raw token IDs;
- there is no tokenizer runtime;
- one forward pass returns one next-token ID/logit;
- there is no generic prefill/decode loop;
- KV inputs can be constructed but cache lifecycle is not a generation subsystem;
- there is no token decoding or normal sampling.

The test was valuable because it proved graph execution and exposed performance behavior; it must not be mistaken for final LLM inference.

## Superseded direction

The following old conclusion is no longer authoritative:

```text
P8 complete
no developer-implementable chunk remains
READY FOR USER LIVE TEST
```

Reason: the clarified objective requires a model store, generic model profiling, tokenizer, KV-backed generation, sampling, performance work, multi-family compatibility, and real text-generation UI/API.

## Completed Developer Chunk — P9A User Model Store + Ledger — 2026-10-23

Authoritative user-visible model root:

```text
Zomboid/Lua/Models/
```

Authoritative manifest:

```text
Zomboid/Lua/Models/ledger.txt
```

Implement:

1. a user-file/model-store IO boundary separate from `GameFile` packaged fixtures;
2. ledger parser for one relative model entry path per nonblank/non-comment line;
3. strict root/path safety;
4. lightweight `ModelEntry` registry states such as REGISTERED/MISSING/INVALID;
5. lazy behavior: registry refresh must not parse every ONNX model;
6. refresh/list/get public operations;
7. host tests for parsing, duplicates, missing entries, and path rejection;
8. bounded in-game ledger probe using the supported Lua-user-file path;
9. update public capability/status only to claims actually implemented.

Do not implement tokenizer/generation/UI redesign in this chunk.

### P9A evidence

- source-verified: `IO/UserFile.lua` validates model-root-relative paths and uses only the supported `getFileInput("Models/...")` adapter; packaged `GameFile` remains separate;
- source-verified: `Models/ModelStore.lua` parses one path per nonblank/non-comment ledger line, preserves invalid and missing entries, handles duplicates deterministically, and performs no ONNX graph parsing during refresh;
- source-verified: public `refreshModels()`, `listModels()`, `getModelEntry()`, and diagnostics are exposed through `PZONNX`;
- host/reference verified: focused P9A tests cover path safety, normalization, duplicates, missing entries, bounded text reading, and lazy existence checks;
- source-verified: bounded `P9AProbe` reports ledger status/counts at `OnGameStart` without loading model graphs;
- validation: all existing host tests, P9A tests, Lua syntax checks, `git diff --check`, and PZ Kahlua compatibility checks pass;
- open native gate: the stock-PZ user ledger probe and sliced real-model responsiveness/cancellation still require live evidence; no PZ runtime acceptance is claimed.

## Completed Developer Chunk — P9B ModelPackage — 2026-10-23

Implemented a lazy model-package abstraction over a registered P9A entry. It derives the safe package root, exposes a fixed known companion-name contract without directory enumeration, preserves missing companion diagnostics, and resolves external ONNX data relative to the model/package while remaining inside the approved user root. Public `getModelPackage()` and package capabilities are available. The bounded P9B probe instantiates descriptors for registered entries only; it does not inspect companion files or parse ONNX graphs.

Evidence:

- source-verified: package construction requires `REGISTERED` entries and derives `Models/<package>/` from the ledger path;
- source-verified: companion access is explicit and fixed-name only; no arbitrary directory enumeration is introduced;
- source-verified: external-data traversal, absolute, drive, and network paths are rejected by the shared user-file boundary;
- host/reference verified: P9B tests cover lazy construction, companion presence/missing status, fixed-name probing, and package-relative external-data resolution;
- source-verified: bounded `P9BProbe` is registered after the P9A refresh probe;
- open native gate: stock-PZ package probe and sliced real-model responsiveness/cancellation remain unverified.

## Completed Developer Chunk — P9C ModelProfile — 2026-10-23

Implemented model-independent profile discovery over a registered `ModelPackage`. Explicit config and generation metadata are inspected before generic graph evidence; input/output role detection uses names/shapes/types; external-data requirements, operators, datatypes, compatibility, tokenizer presence, evidence, confidence, and unknown fields are retained. Profile parsing is explicit (`getModelProfile()`); the startup probe remains lazy and does not parse user models. TinyLLM is not referenced by the profile implementation.

Evidence:

- source-verified: `Models/ModelProfile.lua` consumes the existing generic `Model.parseReader` result and does not select model families;
- source-verified: explicit `config.json`/`generation_config.json` scalar metadata has priority over graph fallback, while absent task/architecture/context/vocabulary/KV data remains unknown;
- source-verified: profile graph evidence records generic input/output roles, required operators, required datatypes, compatibility, and external-data path diagnostics;
- host/reference verified: P9C tests exercise explicit config precedence, token metadata, graph evidence, tokenizer absence, confidence, and unknown-task preservation;
- source-verified: bounded `P9CProbe` reports registered-profile availability without parsing every model at startup;
- open native gate: explicit user-model profile parsing and sliced real-model responsiveness/cancellation still require stock-PZ evidence.

## Completed Developer Chunk — P9D Generic Model Probe — 2026-10-23

Implemented an explicit generic compatibility probe over any registered package. It reports parse/profile status, opsets, operators, datatypes, external-data diagnostics, tokenizer status, generation-contract gaps, compatibility/execution gaps, and optional caller-supplied bounded forward-pass evidence. Startup only reports availability and never sweeps or parses user models. TinyLLM remains a regression input rather than a probe branch.

Evidence:

- source-verified: `Models/ModelProbe.lua` is package/profile driven and contains no model-family conditionals;
- source-verified: parse failures are structured, generation readiness is reported as a contract status, and missing KV/tokenizer/role evidence remains an explicit gap;
- host/reference verified: P9D tests cover incomplete and complete contract reports, compatibility aggregation, opt-in forward evidence, and parse failure preservation;
- source-verified: bounded `P9DProbe` is lazy and startup-safe;
- open native gate: generic probing of a user-supplied package and sliced real-model responsiveness/cancellation remain unverified in stock PZ.

## Completed Developer Chunk — P10 ONNX Compliance / External Data / Opset / Datatype Expansion — 2026-10-23

Extended package loading with validated external-initializer reads, offset/length metadata handling, package-relative external files, opset-aware registry dispatch, explicit datatype gaps, packed FP16/BF16/int32/int64 decoding, and optional empty-node-input handling. Large initializer storage remains packed and lazy; only value access decodes individual elements. Public package loading and capability/status surfaces are updated while native gates remain open.

Evidence:

- source-verified: `Model.loadPackage()` binds primary and external readers to `ModelPackage`; external locations are validated before access and offset/length bounds are enforced;
- source-verified: `OperatorRegistry` dispatch/reporting receives opset versions and rejects versions outside implemented semantics explicitly;
- source-verified: compatibility reports distinguish `datatypeGaps`, unsupported operators/opsets, and execution gaps;
- source-verified: packed FP16/BF16/int32/int64 initializers decode on demand without expanding backing bytes into Lua scalar arrays;
- host/reference verified: P10 tests cover external initializer bytes, package inline reads, FP16/BF16/int32/int64 values, future-opset rejection, datatype gaps, and optional Slice inputs;
- source-verified: bounded P10 probe records compliance capabilities without loading user models;
- open native gate: user-package external data and sliced real-model responsiveness/cancellation remain unverified in stock PZ.

## Completed Developer Chunk — P11 Tokenizer Runtime — 2026-10-23

Implemented a package/profile-driven pure-Kahlua BPE tokenizer over `tokenizer.json`, including supported normalizer/post-processor/decoder paths, UTF-8 symbol handling, ranked merges, BOS/EOS and special-token rules, encode/decode APIs, bounded JSON parsing, and explicit rejection of unsupported tokenizer families/features. The selected Tiny-LLM tokenizer was inspected with development-time tooling as BPE (32k vocabulary) and the runtime matched trusted reference IDs for `hello world` and the model sample; this still does not claim model generation.

Evidence:

- source-verified: tokenizer assets are loaded only through `ModelPackage` and are explicit-use/lazy;
- source-verified: unsupported non-BPE models, pre-tokenizers, normalizers, post-processors, decoder components, malformed JSON, and missing special-token contracts fail explicitly;
- host/reference verified: compact tokenizer fixture vectors pass encode/decode, BOS override, EOS append, special-token skipping, malformed JSON, and unsupported-family tests;
- real-model metadata/reference verified: development `tokenizers` output matched runtime IDs for Tiny-LLM `hello world` (`1,22172,3186`) and its longer sample; no in-game claim is made;
- source-verified: startup P11 probe reports availability without parsing every tokenizer;
- open native gate: tokenizer loading through a live PZ user package and all sliced real-model responsiveness/cancellation remain unverified.

## Completed Developer Chunk — P12 Generic Decoder Runtime — 2026-10-23

Implemented a profile-driven decoder primitive with token prefill, one-token decode, attention/position input construction, ordered KV cache transfer, cache-shape validation, bounded `InferenceJob` stepping, cancellation, reset, and explicit model-entry construction. No TinyLLM/Llama/Qwen execution branches were added, and this chunk does not claim sampling or chat generation.

Evidence:

- source-verified: `Runtime/Decoder.lua` consumes generic profile roles/cache descriptors and uses the existing resumable session job;
- source-verified: cache input/output count and tensor availability are validated; dynamic dimensions fail explicitly when they cannot be resolved;
- host/reference verified: P12 tests cover resumable prefill, empty initial cache, attention/position progression, one-token decode cache reuse, and cancellation;
- source-verified: public decoder creation APIs and lazy P12 probe are available;
- open native gate: real user-model prefill/decode and sliced real-model responsiveness/cancellation remain unverified in stock PZ.

## Completed Developer Chunk — P13 Sampling — 2026-10-23

Implemented a model-independent sampler with greedy/argmax, local seeded PRNG sampling, temperature, top-k, top-p, repetition/presence/frequency penalties, tensor-logit extraction, EOS/length stopping, and explicit NaN/invalid-boundary failures. Sampling remains separate from decoder and tokenizer execution; no chat/generation claim is made from this chunk alone.

Evidence:

- source-verified: `Runtime/Sampler.lua` has no model-family or tokenizer branches and does not mutate global random state;
- source-verified: rank-1/rank-2/rank-3 logits select the final vocabulary row generically;
- host/reference verified: P13 tests cover greedy/top-k, penalties, tensor extraction, seeded determinism, EOS/length stopping, NaN, invalid top-p, and invalid temperature;
- source-verified: bounded P13 probe and public sampler capability are available;
- open native gate: sampled decoder output and sliced real-model responsiveness/cancellation remain unverified in stock PZ.

## Completed Developer Chunk — P14 Profiler / Performance Optimization — 2026-10-23

Added a disabled-by-default bounded profiler using the source-verified PZ `getTimestampMs()` API when available, with injectable host clocks, event caps, aggregates, scheduler/operator/decoder/tokenizer instrumentation, and packed/quantized tensor storage reports. No speed or native throughput claim is made; the profiler provides the measurements required for later optimization and responsiveness checks.

Evidence:

- source-verified: `Runtime/Profiler.lua` records bounded elapsed time/work and exposes reset/snapshot data without global timing or random-state mutation;
- source-verified: session jobs, operators, decoder steps, tokenizer encode/decode, and tensor storage can emit profiler events while disabled paths remain no-op;
- host/reference verified: P14 tests cover event bounds, aggregate work, packed storage metrics, and disabled profiler behavior;
- PZ Java source-verified: `getTimestampMs` is a supported global Lua method backed by `System.currentTimeMillis()`;
- open native gate: real timing/cancellation responsiveness and sliced model throughput remain unverified in stock PZ.

## Completed Developer Chunk — P15 Structural Compatibility Matrix — 2026-10-23

Added a model-name-independent compatibility matrix over generic probe reports. It derives structural signatures from roles, operators, tensor ranks, cache cardinality, and tokenizer status; aggregates compatible and incomplete packages; and reports unsupported contract gaps without introducing family-specific execution branches. A bounded P15 probe and public matrix API are available, while the diagnostic and runtime status remain honest about the open real-family gate.

Evidence:

- source-verified: `Models/CompatibilityMatrix.lua` contains no TinyLLM/Llama/Qwen or model-name dispatch and reports parse/profile/generation/execution gaps explicitly;
- host/reference verified: P15 tests cover three structurally distinct reports, two compatible signatures, and one incomplete/unsupported report;
- source-verified: public compatibility assessment/comparison and the bounded P15 probe are registered;
- validation: PZ Kahlua verification reports 0 errors and 0 warnings for 48 scanned files; focused P12, P13, P14, and P15 host tests pass;
- partial: the repository still contains only one real decoder export, so P15 acceptance requiring two distinct real decoder families with reference-consistent generation remains open;
- open native gates: real-family generation, user-package tokenizer/profile loading, and sliced real-model responsiveness/cancellation remain unverified in stock PZ.

## Completed Developer Chunk — P16 Generic Generation API Core — 2026-10-23

Implemented the first real text-generation API layer over the accepted P11 tokenizer, P12 resumable decoder/KV contract, and P13 sampler. `Runtime/Generator.lua` performs tokenizer-driven prefill, samples decoder logits, advances one-token decode steps, decodes generated IDs back to text, enforces EOS/length stopping, exposes bounded cooperative stepping, and supports cancellation/reset. It is dependency-injected and model-profile-driven; no family-name execution branches were added. This is a host-verified API core, not a native chat acceptance claim yet.

Evidence:

- source-verified: `Generator` consumes only Decoder/Tokenizer/Sampler contracts and returns explicit phase, progress, text, token, stopping, and cancellation state;
- source-verified: `PZONNX.newGeneratorForEntry()` loads a ledger-backed package, profile, model, session, decoder, tokenizer, and sampler through the generic path; `generateText()` is available for bounded host/reference use;
- host/reference verified: P16 tests cover prefill sampling, repeated decode, generated-text decoding, max-token stopping, zero-length stopping, and cancellation;
- real-model host/reference verified: the local 408-node quantized TinyLLM package was loaded through the user-file adapter and generic profile/tokenizer/generator path; `hello` tokenized to 2 IDs and one sampled token decoded to `to` after 3,384 bounded scheduler steps (developer host evidence only);
- open native gates: live user-package generation, game-thread responsiveness/cancellation, and the P16 Core-backed chat surface remain unverified in stock PZ.

## Exact Next Chunk — P16 Core-Backed Generative Chat Surface

Extend the existing Core-backed diagnostic window with a distinct ledger-backed generative mode. Preserve the numeric forward-pass probe, add model refresh/selection and prompt controls, drive `Generator:step()` cooperatively with visible progress/cancel state, and display decoded assistant text only when the generic tokenizer/decoder/sampler contracts are actually ready. Keep packaged TinyLLM paths as diagnostic regression assets rather than the user model architecture.

## Completed Developer Chunk — P16 Core-Backed Generative Chat Surface — 2026-10-23

Added a distinct `GenerationUI` built on the reusable PsychopatzCore window, layout, button, text-entry, command-hub, debug-hub, keybind, and OnTick surfaces. The window refreshes the explicit user ledger, shows registered/missing/invalid entries, loads only a selected registered package through `newGeneratorForEntry()`, accepts prompt/max-token input, steps generation one bounded budget per tick, displays decoded assistant text and stop reason, and cancels active work. The numeric Tiny-LLM forward-pass probe remains separate and unchanged as a diagnostic regression surface.

Evidence:

- source-verified: `GenerationUI.lua` requires the supported Core UI modules and uses no custom Java/native bridge;
- source-verified: the generation window is ledger-backed and does not expose packaged fixture/model paths as the user model architecture;
- host/reference verified: all repository Lua host tests pass, including P16 generator tests; PZ Kahlua verification reports 0 errors and 0 warnings across 50 scanned files;
- open native gates: the Core-backed window, a live user package, readable native generation, and sliced real-model responsiveness/cancellation still require stock-PZ evidence;
- P15 developer evidence is now present for two real decoder families, but this does not claim native PZ acceptance.

## Completed Developer Chunk — P17 Model-Agnostic TTS / Pipeline Boundary — 2026-10-23

Added an optional `Runtime/Pipeline.lua` boundary that composes the generic text generator with a caller-owned bounded TTS provider. Text-only generation remains unchanged; audio is opt-in and fails explicitly when no provider is attached. A provider must expose `begin(text, options)`, bounded `step(budget)`, and optional `cancel()`; audio output is kept separate from generated text and no TinyTTS/model-specific branch was added. The P17 probe and public pipeline constructors are available.

Evidence:

- source-verified: pipeline scheduling, cancellation, reset, text/audio result separation, and missing-provider errors are generic and pure Kahlua;
- source-verified: `newPipelineForEntry()` composes the existing ledger-backed generator with caller-owned TTS without coupling the LLM runtime to a TTS family;
- host/reference verified: P17 tests cover text-only output, bounded generation-to-audio transition, audio result shape, cancellation, and explicit missing-provider failure;
- validation: all repository Lua host tests pass; PZ Kahlua verification reports 0 errors and 0 warnings across 52 scanned files;
- partial/open: no selected real TTS pipeline is accepted, and native package/responsiveness gates remain open.

## Completed Developer Chunk — P15 Real Multi-Family Reference Evidence — 2026-10-23

Expanded generic execution and tokenizer coverage from evidence supplied by a second real decoder family. The runtime now includes model-independent `Identity`, `Sub`, `Less`, `Tanh`, `Gemm`, `Split`, `Squeeze`, and optional-axes `ReduceMean` support, plus the ByteLevel BPE subset required by the GPT-2-family tokenizer. No model-name execution branches were added.

Evidence:

- host/reference verified: the local 408-node quantized TinyLLM package completed generic one-token generation for `hello`, producing token ID `304` (`to`) after 3,384 bounded scheduler steps; development-time ONNX Runtime selected the same ID;
- host/reference verified: the real `onnx-community/tiny-gpt2-ONNX` package completed generic one-token generation for `Hello`, producing token ID `10209` (`Ġviewers`, decoded as ` viewers`) after 452 bounded scheduler steps; development-time ONNX Runtime selected the same ID;
- real-model metadata verified: the GPT-2 package has 475 nodes, 11 inputs, 9 outputs, and 8 KV input/output pairs; it is not a TinyLLM graph or adapter;
- structural compatibility verified: a third real GPT-2 decoder export was profiled at 1,372 nodes with 2 inputs, 11 outputs, no past-cache inputs, and 10 cache-like outputs; it remains an actionable incomplete stateless-generation contract rather than a false compatibility pass;
- host tests cover the new tensor/operator primitives and ByteLevel tokenizer vector; all repository tests and Kahlua checks pass;
- open native/performance gates: these are source/host/reference results only. Native PZ generation, cancellation responsiveness, and acceptable elapsed time remain unverified; the GPT-2 host run was multi-minute and is not presented as interactive performance.

## Exact Next Chunk — P14C Measured Hotspot Optimization / Native-Ready Responsiveness

Use the bounded profiler on the same real-model vectors, identify the dominant operator and allocation costs, and implement only measured behavior-preserving optimizations. Add before/after work and elapsed-time evidence, preserve resumable/cancellable scheduling below whole-node granularity, and keep the stock-PZ responsiveness gate open until live evidence exists.

## Following chunks

After P9A acceptance, continue directly:

- P9B ModelPackage;
- P9C ModelProfile;
- P9D generic model probe;
- P10 ONNX compliance/external data/opset expansion;
- P11 tokenizer;
- P12 KV-backed prefill/decode;
- P13 sampling;
- P14 profiler/performance;
- P15 multi-family compatibility;
- P16 real generative API/UI;
- P17 TTS/pipeline expansion.

## Evidence labels

Use:

- source-verified;
- host/reference verified;
- PZ runtime verified;
- real-model verified;
- generation verified;
- multi-family verified;
- adopter verified;
- open native gate;
- partial;
- unsupported/unproven.
