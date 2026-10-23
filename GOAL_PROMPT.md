# PZONNX /goal

Repository: `psychopatz/PZONNX`

Own the complete approved PZONNX objective: build a **model-agnostic pure-Kahlua ONNX inference runtime** for stock Project Zomboid Build 42.20 that can load user-supplied compatible ONNX model packages, automatically inspect their model/generation contract, tokenize text, perform KV-backed autoregressive generation, sample/decode output, and remain responsive enough for in-game use.

TinyLLM is a regression model, not the architecture.

Read in order:

1. `docs/architecture/PZONNX_ARCHITECTURE.md`
2. `docs/architecture/PZONNX_ROADMAP.md`
3. `docs/architecture/PZONNX_ACCEPTANCE.md`
4. `docs/architecture/PZONNX_PROGRESS.md`
5. `docs/architecture/P9_MODEL_AGNOSTIC_GENERATIVE_RUNTIME.md`
6. `docs/architecture/AGENT_RUNBOOK.md`
7. `docs/architecture/PZONNX_CHAT_UI.md` when relevant.

Current accepted foundation includes real ONNX execution, a host/reference-verified 408-node quantized tiny-LLM forward pass, the in-game token probe, and newly resumable MatMul/MatMulInteger kernels after native freeze feedback. Preserve that work. Do not revert to the superseded "P8 complete / only live testing remains" state.

Start with the exact Next Chunk in PROGRESS: **P9A User Model Store + Ledger**.

The authoritative user model location is `Zomboid/Lua/Models/`; discovery is explicit through `Zomboid/Lua/Models/ledger.txt` because PZ cannot be relied on to enumerate arbitrary model files. Implement a safe user-file/model-store boundary, parse one relative model entry path per nonblank/non-comment line, reject root escape/absolute/traversal paths, preserve missing/invalid entries as diagnostics, keep refresh lazy (do not parse every ONNX model at startup), expose refresh/list/get entry operations, and add focused host tests plus a bounded PZ ledger probe.

Keep packaged `media/pzonnx/fixtures/` as internal regression assets only. Do not make packaged model paths the user model architecture.

After P9A acceptance, continue autonomously through P9B ModelPackage, P9C ModelProfile, P9D generic model probing, then P10 external-data/opset/datatype compliance, P11 tokenizer, P12 generic prefill+KV-cache+decode generation, P13 sampling, P14 profiler/performance optimization, P15 multi-family compatibility, P16 real generative API/UI, and P17 TTS/pipeline expansion. Update PROGRESS after each coherent chunk; phase completion is not parent completion.

Hard runtime boundary: no DLL/shared-library inference, JNI/custom Java, JVM patching, Python at game runtime, external/localhost inference server, or companion inference executable. Development-time Python/ONNX/ONNX Runtime/tokenizer/model tooling is allowed for fixtures, inspection, export, optimization, profiling, and trusted references only.

Model-agnostic rule: do not grow generic execution through `if TinyLLM / elseif Llama / elseif Qwen` branches. Prefer config/graph-driven ModelProfile discovery and generic generation contracts. Isolate truly family-specific behavior only when evidence proves it is necessary.

Performance rule: distinguish responsiveness from throughput. Heavy kernels must yield below whole-node granularity when required. Preserve numerical references, measure before optimizing, and prioritize profiler-proven real-model hotspots. Do not claim "faster" without measurements.

Evidence rule: the current GUI is a forward-pass/token probe. Prompt text is not currently model input. Do not claim chat/generation until text is tokenized, prefill/KV decode runs, tokens are sampled, and token IDs are decoded back to text.

Native PZ evidence is required for in-game claims but open live gates are not automatically blockers. Preserve the outstanding native check that sliced real-model inference remains responsive/cancellable, then continue developer-side roadmap work whenever safe.

Do not publish to Steam Workshop. Preserve unrelated user work.

Stop only for a genuine blocker defined by the runbook, or when the full mandatory P9+ developer-side roadmap is complete and only bounded user-owned native verification remains. Otherwise continue through the approved roadmap.
