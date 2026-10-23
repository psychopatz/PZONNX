# PZONNX in-game Tiny-LLM chat probe

The client probe is a small Build 42 UI harness for exercising the current
PZONNX runtime from inside Project Zomboid. It is deliberately separate from
Project Hoomans and PBrainz.

## Opening the window

The mod declares `PsychopatzCore` as a dependency and loads
`PsychopatzCore/UI/PsychopatzUI`. The window therefore uses Core's themed
`UI.Window`, responsive layout, text-entry/button factories, command hub, and
configurable keybinds.

- Press F8 by default; the key can be changed in the Core mod options.
- Open the Core command hub and choose the PZONNX chat probe.
- Open the Psychopatz Debug Hub and launch `PZONNX Tiny-LLM Chat Probe`.
- The public client entry point is `PZONNXChatUI.Open()`.
- Run advances one scheduler step per game tick; the Cancel button releases a
  long-running job without closing the window.

## Model and input

The default model field is:

```text
media/pzonnx/models/tiny_llm/model_int8.onnx
```

The linked `onnx-community/Tiny-LLM-ONNX` `model_int8.onnx` file is a local,
ignored model asset. It must be copied into the relative mod path before the
game can load it. Runtime performs no network access.

The probe accepts comma-separated integer token IDs. It does not claim to be a
tokenizer: prompt text is retained as a transcript label only. For the linked
decoder export, the adapter supplies `input_ids`, `attention_mask`,
`position_ids`, and empty layer-0 key/value cache tensors. It reads the last
sequence position from the `logits` output and displays the selected token ID
and logit.

Model loading rejects a non-empty compatibility report. Inference advances one
scheduler step per `OnTick`, including resumable matrix-kernel chunks; failed
input, unsupported shape, unsupported operator, and invalid output conditions
are shown explicitly in the window.

## Evidence boundary

The shared adapter and the real linked model are host/reference verified: the
adapter executed all 408 nodes outside the game and selected token ID `9309`
for token ID `1`. The UI source is Kahlua-verified and the bundled adapter
fixture passes its numerical test. Native Project Zomboid loading, UI display,
and in-game numerical output remain open native gates until exercised in stock
Build 42.20; this document does not promote host evidence to PZ acceptance.
