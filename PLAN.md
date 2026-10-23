# PZONNX Plan

## Full objective

Build a **model-agnostic pure-Kahlua ONNX inference runtime** for Project Zomboid Build 42.20 that can load user-supplied compatible ONNX model packages, inspect their execution/generation contract, and run useful generative inference in-game without native libraries, custom Java, JNI, or an external inference service.

TinyLLM is a regression/compatibility model, not the product architecture.

The desired user experience is ultimately:

```text
Zomboid/Lua/Models/
    ledger.txt
    <model package files>
        |
        v
PZONNX Model Store
        |
        v
ModelPackage + ModelProfile
        |
        +--> tokenizer/config discovery
        +--> ONNX compatibility
        +--> external weights
        |
        v
Generative Runtime
        |
        +--> prefill
        +--> KV cache
        +--> decode
        +--> sampling
        |
        v
streamed text while Project Zomboid remains responsive
```

## Accepted foundation

P0-P8 remain valuable accepted developer-side foundation:

- protobuf/ONNX parsing;
- lazy packed initializer access;
- generic tensor/session/operator execution;
- reference-checked toy fixtures;
- quantized paths;
- resumable inference jobs;
- a real 408-node quantized tiny-LLM host/reference execution;
- in-game Core-backed forward-pass probe;
- resumable MatMul/MatMulInteger kernel state.

These milestones prove that PZONNX can execute real ONNX neural work in Lua. They do **not** complete the full LLM inference objective.

## Current major phase

**P9 — Model Store & Model-Agnostic Discovery**

The old "P8 complete / READY FOR USER LIVE TEST" direction is superseded as the parent roadmap state. Native P0-P8 evidence remains useful, but the clarified product gap requires substantial developer-side work.

## Current exact Next Chunk

**P9A — User Model Store + Ledger**

Implement the authoritative user model source:

```text
Zomboid/Lua/Models/ledger.txt
```

The ledger explicitly lists model entry files because Project Zomboid cannot be relied on to enumerate/discover arbitrary user files.

The first chunk must:

1. add a user-file/model-store IO boundary separate from packaged regression fixtures;
2. read `Models/ledger.txt` through the supported Lua-user-file API;
3. parse one relative model entry path per nonblank/non-comment line;
4. reject traversal/absolute/out-of-root paths;
5. register entries lazily without parsing every ONNX model at startup;
6. preserve invalid/missing entries as visible diagnostics rather than aborting the entire registry;
7. expose refresh/list/get operations;
8. add focused host tests and a bounded in-game probe.

Do not build the tokenizer or general generation loop in P9A.

## Ordered remaining arc

```text
P9  Model Store & Model-Agnostic Discovery
P10 ONNX Compliance Expansion & Model Package IO
P11 Tokenizer Runtime
P12 Generic Decoder Runtime: prefill + KV cache + decode
P13 Sampling & Generation Controls
P14 Performance Planner, Profiler & Optimized Kernels
P15 Multi-Family Compatibility
P16 Product API & Real Chat UI
P17 Model-Agnostic TTS/Pipeline Expansion
```

See the architecture, roadmap, current progress ledger, and P9 phase document for the durable contracts.
