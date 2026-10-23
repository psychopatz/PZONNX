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

## Exact Next Chunk — P9A User Model Store + Ledger

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
