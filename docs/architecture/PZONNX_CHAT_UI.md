# PZONNX in-game inference probe UI

## Current role

The existing Core-backed window is a **forward-pass/token diagnostic probe**, not a completed chat interface.

It currently:

- loads one ONNX path;
- accepts comma-separated numeric token IDs;
- builds known decoder-style inputs;
- advances a bounded inference job;
- selects the highest-logit next token;
- displays token ID/logit diagnostics.

The visible prompt text is currently a transcript label and is **not tokenized or fed to the model**. Therefore readable conversational output is not an acceptance expectation for this window yet.

## Current model-path status

The current source still contains the historical packaged/local test path:

```text
media/pzonnx/models/tiny_llm/model_int8.onnx
```

That is superseded as the future user-model architecture.

The new authoritative user model root is:

```text
Zomboid/Lua/Models/
```

with discovery through:

```text
Zomboid/Lua/Models/ledger.txt
```

Do not simply replace the text field with another hard-coded path. The UI should eventually select registered `ModelEntry`/`ModelPackage` objects from the model registry.

## Responsiveness

Native testing exposed a long main-thread stall during real-model inference.

Current source now includes resumable MatMul/MatMulInteger kernel state, a bounded kernel work budget, one scheduler step per `OnTick`, and Cancel.

This is accepted source/host progress. Native verification still must confirm that the game remains responsive and Cancel executes during a real model run.

## Future UI modes

When P16 is reached, keep two distinct surfaces/modes.

### Generation mode

- model selection from ledger-backed registry;
- text prompt;
- max tokens;
- sampling controls;
- generated readable text;
- progress/cancel.

### Diagnostic mode

- raw token IDs;
- ModelProfile/compatibility;
- logits;
- current token;
- KV-cache state;
- node/kernel progress;
- profiler timing.

Do not make the diagnostic probe pretend to be chat before tokenizer + generation runtime acceptance.

## Evidence boundary

The linked real tiny model has host/reference forward-pass evidence. That does not yet prove native readable chat generation.
