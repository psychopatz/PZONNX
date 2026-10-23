# PZONNX

PZONNX is an experimental pure-Kahlua ONNX inference runtime for Project Zomboid Build 42.

The project goal is deliberately unusual: load and execute real ONNX models **inside stock Project Zomboid through supported Lua/Kahlua APIs**, without shipping native libraries, custom Java code, JNI, or an external inference process.

## Ground rules

Runtime acceptance for the core experiment requires:

- ordinary Project Zomboid Lua/Kahlua only;
- no DLL, JNI, custom Java classes, injected JVM code, Python runtime, local inference server, or companion executable;
- development-time tools may generate ONNX fixtures and trusted reference outputs;
- numerical correctness comes before performance;
- large-model support is earned incrementally from real model/operator evidence, not assumed.

## First proof target

The first hard gate is intentionally small:

1. Project Zomboid loads the PZONNX mod.
2. PZONNX reads a genuine binary `.onnx` fixture.
3. The Lua runtime parses the required protobuf/ONNX structures.
4. It executes a tiny neural network entirely in Kahlua.
5. Its output matches a trusted ONNX Runtime reference within a documented tolerance.

Only after that gate is real do we expand toward transformer inference, a tiny LLM, quantization, and experimental TTS.

## Repository map

- `Contents/mods/PZONNX/42.20/` — Project Zomboid Build 42.20 mod.
- `docs/architecture/` — durable architecture, roadmap, progress, and runbook.
- `tests/` — host-side and fixture-level verification assets.
- `tools/` — development-only fixture/reference generation helpers.

See [PLAN.md](PLAN.md) and [docs/architecture/PZONNX_ROADMAP.md](docs/architecture/PZONNX_ROADMAP.md).
