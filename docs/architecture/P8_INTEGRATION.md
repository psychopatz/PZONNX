# P8 integration and hardening contract

The stable public surface is the returned `PZONNX` table:

- `loadModel(relativePath)` and `inspectModel(model)`;
- `newSession(model, options)` and `createInferenceJob(session, inputs)`;
- `getCapabilities()` and `getRuntimeStatus()`;
- model-specific `TinyLM` and `TinyTTS` adapters;
- `newFallbackAdapter(primary, fallback, logger)`.

An adopter must treat PZONNX as an optional dependency. It may request a model/session, advance a job with a bounded budget, and fall back to its existing behavior if model compatibility, runtime execution, or a native gate fails. The fallback adapter contains the failure and reports the primary error; it does not silently claim ONNX success.

Generic PZONNX modules do not import Project Hoomans or PBrainz. An adopter owns its own tokenization, gameplay policy, scheduling integration, and fallback behavior.
