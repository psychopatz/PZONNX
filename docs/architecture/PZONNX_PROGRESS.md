# PZONNX Progress

Last reconciled: model-agnostic generative-runtime phase transition after native GUI/performance feedback.

## Parent goal

Build a model-agnostic pure-Kahlua ONNX inference runtime for Project Zomboid that can discover user-supplied compatible model packages, inspect them, tokenize text, perform KV-backed autoregressive generation, sample/decode output, and remain responsive enough for in-game use.

Parent state: **IN PROGRESS**.

## Current major phase

**P9 — Model Store & Model-Agnostic Discovery**

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

## Exact Next Chunk — P9D Generic Model Probe

Implement a reusable compatibility probe accepting any registered `ModelPackage` and emitting parse result, `ModelProfile`, opsets/operators/datatypes, external-data requirements, tokenizer status, generation-contract status, execution gaps, and optional bounded forward-pass evidence. Keep model parsing/profile inspection explicit and bounded; do not turn the probe into a startup sweep. TinyLLM remains one regression input only.

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
