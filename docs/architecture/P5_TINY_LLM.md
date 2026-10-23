# P5 bounded tiny-LM one-token proof

The selected P5 fixture is `media/pzonnx/fixtures/p5_tiny_lm.onnx`:

```text
token_ids[int64, 1]
  -> Gather(embedding, axis=0)
  -> MatMul(lm_head)
  -> Add(lm_bias)
  -> logits[1, 3]
```

It has a three-token vocabulary, hidden width two, and exactly one precomputed token ID input. For token ID `1`, the ONNX Runtime reference logits are `[0.6, 0.4, -0.1]` within `1e-6`, so deterministic argmax selects token ID `0`.

This is a one-token language-model proof, not general text generation. It does not claim a tokenizer, multi-token context, positional encoding, KV cache, or a production-scale language model. The `TinyLM` adapter is model-specific and remains independent from Project Hoomans/PBrainz.
