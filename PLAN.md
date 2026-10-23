# PZONNX Plan

## Objective

Build an experimental ONNX inference runtime that executes selected neural models inside Project Zomboid Build 42 using supported Lua/Kahlua APIs only.

The product objective is larger than any single roadmap phase. A phase is complete only when its acceptance gate is proven; the project is complete only when the approved end-to-end experiment is complete or a hard technical limitation is demonstrated with reproducible evidence.

## Immediate direction

Current phase: **P0 — Binary and protobuf foundation**.

Current next chunk:

1. prove stock PZ Lua can open a tiny binary fixture through the supported file API;
2. verify byte-exact reads and protobuf varints;
3. parse a deliberately tiny ONNX fixture far enough to identify its model/graph metadata;
4. preserve an external trusted reference for comparison.

## Long arc

```text
P0 binary/protobuf foundation
  -> P1 ONNX model loading/indexing
  -> P2 tiny graph execution
  -> P3 reusable operator runtime
  -> P4 transformer operator coverage
  -> P5 tiny LLM one-token proof
  -> P6 resumable/quantized inference experiments
  -> P7 TTS proof
  -> P8 integration and compatibility hardening
```

See `docs/architecture/PZONNX_ROADMAP.md` for acceptance gates and `docs/architecture/PZONNX_PROGRESS.md` for current truth.
