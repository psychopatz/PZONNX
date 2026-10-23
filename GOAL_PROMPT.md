# PZONNX /goal

Repository: `psychopatz/PZONNX`

Own the **complete approved PZONNX objective**, not just the current phase: build an experimental ONNX inference runtime that can execute selected small neural models inside stock Project Zomboid Build 42.20 using supported Lua/Kahlua APIs only, continuing through the approved tiny-LLM, resumable/quantized inference, TTS, and integration milestones unless a genuine hard blocker is proven.

Read in order:

1. `docs/architecture/PZONNX_ARCHITECTURE.md`
2. `docs/architecture/PZONNX_ROADMAP.md`
3. `docs/architecture/PZONNX_ACCEPTANCE.md`
4. `docs/architecture/PZONNX_PROGRESS.md`
5. current phase document, currently `docs/architecture/P0_BINARY_PROTOBUF.md`
6. `docs/architecture/AGENT_RUNBOOK.md`

Current state: P0A packaged-binary/protobuf source implementation exists. Its native Project Zomboid PASS evidence is still open. **Do not stop and ask the user to live-test P0A before continuing developer-side work.** Keep that native gate honest and open, then start with the exact P0B Next Chunk in PROGRESS: generate/package a genuine minimal ONNX fixture, implement top-level ModelProto/opset/graph-envelope parsing, compare against trusted reference metadata, and add a bounded PZ probe.

After each accepted developer-side chunk, update PROGRESS and immediately continue to the next mandatory developer-implementable roadmap chunk. A phase completion, passing test, docs update, parser milestone, or single successful model operation is not parent-goal completion.

Hard runtime boundary: no DLL/shared-library inference, JNI, custom Java classes, JVM patching/injection, Python at game runtime, external/localhost inference server, or companion executable. Development-time Python/ONNX/ONNX Runtime may be used only for fixtures, model export/inspection, operator inventory, and trusted reference outputs.

Treat numerical/reference correctness as mandatory. Unsupported ONNX behavior must fail explicitly. Avoid expanding large model weights into boxed Lua scalars. Keep generic runtime code independent from Project Hoomans/PBrainz until the integration phase.

Native PZ evidence is required for in-game claims but missing live evidence is not automatically a blocker. Preserve open native gates and continue development whenever the next work can be safely isolated behind documented APIs/adapters/reference fixtures. Do not repeatedly stop for user-owned live testing.

Do not publish to Steam Workshop. Preserve unrelated user work. Do not claim PZ runtime acceptance from host/reference tests.

Stop only when:

1. a genuine blocker defined by the runbook prevents further safe developer-side work; or
2. the full mandatory developer-side roadmap is implemented and the project is **READY FOR USER LIVE TEST**; or
3. the complete parent goal is truly accepted.

If blocked, provide the smallest reproducible evidence and exact missing capability. Otherwise continue autonomously through the roadmap.
