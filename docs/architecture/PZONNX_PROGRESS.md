# PZONNX Progress

Last reconciled: goal-documentation hardening after P0A source implementation.

## Parent goal

Build the complete experimental pure-Kahlua ONNX runtime through the approved real-ONNX, graph execution, tiny-LLM, resumable/quantized inference, TTS, and integration milestones.

Parent state: **IN PROGRESS**.

## Current major phase

**P0 — Binary and protobuf foundation**

Developer state: **P0A source implementation complete; P0B is the next developer-side chunk.**

Native acceptance state: **P0A PZ runtime gate OPEN / UNVERIFIED.**

## Source-verified foundation

- Build 42.20 mod descriptor and shared bootstrap.
- byte reader with offsets and protobuf varint support;
- fixed32 and pure-Lua float32 decoding;
- protobuf wire tag/length/skip primitives;
- deterministic 16-byte packaged protobuf fixture;
- reproducible fixture generator;
- game-file adapter using `getGameFilesInput`;
- bounded P0A diagnostic probe scheduled for game start;
- host-style fake-stream smoke vectors.

## Open evidence

Not yet independently host-run in the current ChatGPT execution environment:

- repository smoke Lua test, because that environment has no Lua/LuaJIT interpreter.

Not yet PZ-runtime verified:

- packaged fixture virtual path resolution;
- DataInputStream method bridging;
- expected P0A PASS line.

Expected P0A native success evidence:

```text
[PZONNX] INFO probe=P0A status=PASS path=media/pzonnx/fixtures/p0_probe.pb bytes=16 varint=150 text=PZONNX float32=1.0
```

These remain mandatory acceptance items but are not a reason to stop developer-side implementation.

## Exact Next Chunk — P0B developer implementation

Implement a **genuine minimal ONNX top-level parsing proof**.

Required work:

1. add development tooling that generates a real minimal `.onnx` fixture;
2. record trusted reference metadata for that exact fixture;
3. implement only the ModelProto/opset/graph-envelope protobuf fields required to identify:
   - IR version;
   - producer name/version when present;
   - opset imports;
   - graph name/envelope;
4. keep unknown-field skipping and truncation errors explicit;
5. add focused reference tests that prove PZONNX sees the same top-level metadata as the trusted inspector;
6. package the real ONNX fixture for the mod;
7. add a bounded PZ diagnostic probe for the real ONNX fixture;
8. preserve P0A as an open native gate unless actual PZ evidence is obtained.

Do **not** implement MatMul, tensor execution, or transformer-specific logic in this chunk.

## Following chunk

After P0B developer acceptance, proceed directly into **P1 model loading/indexing** even if native P0A/P0B evidence is still open, provided no runtime fact blocks safe implementation.

## Evidence labels

Use:

- source-verified;
- host/reference verified;
- PZ runtime verified;
- real-model verified;
- adopter verified;
- open native gate;
- partial;
- unsupported/unproven.

## Final handoff rule

If all developer-implementable mandatory work is complete and only user-owned native verification remains, report:

**READY FOR USER LIVE TEST**

Do not report COMPLETED or BLOCKED in that state.
