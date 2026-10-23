# PZONNX Plan

## Full objective

Build an experimental ONNX inference runtime that executes selected small neural models inside Project Zomboid Build 42.20 using supported Lua/Kahlua APIs only.

The parent goal is the **complete runtime experiment**, not the next phase. A phase is only an organizational boundary and may never be used as a smaller definition of success.

The project is complete only when the approved mandatory roadmap has been implemented and accepted as far as the supported runtime permits, including the small-LLM and TTS proofs, or when a hard technical limitation is demonstrated with reproducible evidence and recorded as the reason the experiment cannot continue.

## Current state

Current major phase: **P0 — Binary and protobuf foundation**.

Current source implementation already includes:

- Build 42.20 mod bootstrap;
- byte/varint/fixed32/float32 primitives;
- protobuf wire helpers;
- packaged 16-byte binary probe fixture;
- game-file input adapter using `getGameFilesInput`;
- P0A in-game diagnostic probe.

Current missing native evidence: the P0A PASS line has not yet been captured from a real Project Zomboid runtime.

That missing native evidence **does not authorize the implementation agent to stop**. The agent should preserve P0A as an open acceptance gate and continue all developer-side work that does not logically require the live result.

## Ordered implementation arc

```text
P0 binary/protobuf + real ONNX top-level parsing
  -> P1 ONNX model loading/indexing
  -> P2 tiny graph execution
  -> P3 reusable operator runtime
  -> P4 transformer operator coverage
  -> P5 tiny LLM one-token proof
  -> P6 resumable/quantized inference
  -> P7 TTS proof
  -> P8 integration and hardening
```

## Working rule

For each phase:

```text
implement developer-side work
  -> validate with focused fixtures/reference tooling
  -> capture any available PZ runtime evidence
  -> keep missing native gates honest
  -> continue to the next developer-implementable chunk
```

Do not wait for the user to perform live testing before continuing source implementation unless the next code decision genuinely cannot be made safely without that result.

See:

- `docs/architecture/PZONNX_ARCHITECTURE.md`
- `docs/architecture/PZONNX_ROADMAP.md`
- `docs/architecture/PZONNX_ACCEPTANCE.md`
- `docs/architecture/PZONNX_PROGRESS.md`
- `docs/architecture/AGENT_RUNBOOK.md`
- `GOAL_PROMPT.md`
