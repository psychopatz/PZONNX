# PZONNX Acceptance Model

## Purpose

PZONNX combines binary parsing, ONNX numerical execution, user-file access, model discovery, tokenization, autoregressive generation, and game-thread scheduling. Evidence must therefore be labeled precisely.

## Evidence lanes

### Source acceptance

Implementation/contracts exist and unsupported behavior fails explicitly.

### Host/reference acceptance

Development tooling may use Python, ONNX, ONNX Runtime, tokenizer/model libraries, and model exporters to generate trusted fixtures and numerical/text references. These are not runtime dependencies.

### Project Zomboid runtime acceptance

Only stock PZ runtime evidence proves in-game loading, user-file access, responsiveness, UI behavior, or inference.

### Real-model acceptance

A non-toy model package performs the claimed operation through PZONNX.

For LLM claims this is graduated:

```text
real model parsed
< forward pass
< reference-consistent logits
< tokenizer accepted
< prefill + KV decode
< multi-token text generation
< multi-family generation
```

Do not collapse these into one "LLM works" label.

### Adopter acceptance

Another mod consumes the stable PZONNX API without copying or bypassing the runtime.

## Native feedback already established

Native testing has already provided useful evidence:

- P0A/P0B reached stock PZ;
- the Core-backed test window became reachable after integration fixes;
- a real inference attempt exposed main-thread stalls;
- the runtime was changed to resumable MatMul/MatMulInteger kernel chunks.

The next live run still needs to verify the non-freeze/cancel behavior numerically. This remains an open native gate, not a reason to halt P9 developer work.

## Non-blocking native evidence

Missing native evidence remains an open gate unless the next architecture decision genuinely depends on it and cannot be isolated.

Do not repeatedly stop after every developer chunk for user live testing.

## Numerical acceptance

Every numerical claim records:

- model/fixture identity and revision/hash when practical;
- exact input;
- reference implementation;
- expected output;
- PZONNX output;
- tolerance;
- comparison result.

Do not loosen tolerance merely to pass.

## Text-generation acceptance

Readable text is not accepted merely because arbitrary bytes/token IDs are displayed.

A generative-LM claim requires:

- prompt text was actually tokenized into the model input;
- generation used the intended decoder contract;
- KV state was reused where supported;
- token selection followed the declared sampling policy;
- generated token IDs were decoded through the model tokenizer;
- EOS/stop/max-token behavior was bounded;
- output was produced by PZONNX runtime inference rather than a fallback string generator.

## Responsiveness acceptance

"Cooperative" means heavy work yields below any operator boundary that can materially stall a frame.

A scheduler that yields only between graph nodes is insufficient if one node can monopolize the game thread.

Measured total latency and perceived responsiveness are separate:

- responsiveness: game/UI remains usable and cancel/progress can execute;
- throughput: time-to-first-token and tokens/time improve through measured optimization.

## Model-agnostic acceptance

Do not claim model agnosticism from one model name or one custom adapter.

Required evidence grows through:

1. generic ledger/package loading;
2. automatic ModelProfile discovery;
3. generic generation contract;
4. multiple structurally distinct real model packages;
5. at least two decoder families generating through the same generic runtime.

Unsupported models must remain inspectable and produce actionable gaps.

## Parent completion

The earlier P0-P8 developer-side completion state is superseded.

Parent completion now requires the mandatory P9+ roadmap for the model-agnostic generative runtime, or a hard technical limitation demonstrated with reproducible evidence.

A one-token TinyLLM/real-model proof is accepted foundation, not final completion.
