# PZONNX in-game inference and generative UI

## Current role

PZONNX now exposes two Core-backed windows: the original forward-pass/token diagnostic probe and a separate ledger-backed generative chat surface. Both use supported `PsychopatzCore` UI factories; the diagnostic surface remains intentionally separate from text generation.

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

## Generation mode

- `PZONNX/GenerationUI.lua` refreshes and displays ledger entries from the user model store;
- the model field accepts a registered ledger path, not a packaged fixture path;
- prompt text is passed through the generic tokenizer, decoder/KV scheduler, sampler, and text decoder;
- max-new-token limits, cooperative progress, cancel, and explicit error reporting are visible;
- the Debug Hub and command hub expose the window; F9 is the default toggle key.

The generation surface is source/host verified only. It must not be described as native generation acceptance until a stock-PZ user package has been loaded and a real run has remained responsive.

## Diagnostic mode

### Diagnostic mode

- raw token IDs;
- ModelProfile/compatibility;
- logits;
- current token;
- KV-cache state;
- node/kernel progress;
- profiler timing.

The diagnostic probe remains available from the command hub and F8. It continues to accept raw token IDs and show logits/node progress, and it must not be used as evidence for readable generation.

## Evidence boundary

The linked real tiny model has host/reference forward-pass evidence. That does not prove native readable chat generation, user-package loading, multi-family generation, or game-thread responsiveness.
