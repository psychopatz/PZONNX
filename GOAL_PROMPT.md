# PZONNX /goal

Repository: `psychopatz/PZONNX`

Own the complete approved PZONNX objective: build an experimental ONNX inference runtime that can execute selected small neural models inside stock Project Zomboid Build 42.20 using supported Lua/Kahlua APIs only.

Read in order:

1. `docs/architecture/PZONNX_ARCHITECTURE.md`
2. `docs/architecture/PZONNX_ROADMAP.md`
3. `docs/architecture/PZONNX_PROGRESS.md`
4. `docs/architecture/AGENT_RUNBOOK.md`

Start with the exact Next Chunk in PROGRESS. Do not skip foundational acceptance in order to jump to an LLM.

Hard boundary: no DLL/shared-library inference, JNI, custom Java classes, JVM patching/injection, Python at game runtime, external inference server, or companion executable. Development-time Python/ONNX/ONNX Runtime may generate fixtures and trusted reference outputs only.

Treat numerical/reference correctness as mandatory. Unsupported ONNX behavior must fail explicitly. Keep model compatibility evidence-driven and avoid expanding large weights into boxed Lua scalars.

A phase completion is not parent-goal completion. After each accepted phase, reconcile the docs and continue through the remaining mandatory roadmap without waiting for a new goal prompt, unless a genuine blocker or authorization boundary prevents further work.

Do not publish to Steam Workshop. Preserve unrelated user work. Do not claim PZ runtime acceptance from host-only tests.

Final developer-side handoff is reached only when the approved mandatory roadmap is implemented and verified as far as the supported runtime permits, or a hard technical limitation is proven with reproducible evidence and documented precisely.
