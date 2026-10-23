# P7 bounded numeric TTS proof

The selected fixture is `media/pzonnx/fixtures/p7_tiny_tts.onnx`:

```text
token_ids[int64, 1]
  -> Gather(embedding)
  -> MatMul(audio_decoder)
  -> Add(decoder_bias)
  -> pcm[1, 4]
```

The fixed precomputed token ID is `1`. ONNX Runtime produces `[0.5, -0.15, 0.32, 0.3]` within `1e-6`, exposed by `TinyTTS` as a bounded 16 kHz numeric sample block.

This proves a small neural numeric-audio path, not phonemization, waveform quality, a vocoder, a full-sentence TTS model, or production audio acceptance. Those concerns remain separate and are not hidden behind the adapter.
