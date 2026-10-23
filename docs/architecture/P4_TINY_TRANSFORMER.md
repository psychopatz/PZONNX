# P4 bounded transformer-style coverage

The first P4 fixture is `media/pzonnx/fixtures/p4_tiny_attention.onnx`.
It is a deliberately bounded one-token, hidden-width-two attention-style projection:

```text
hidden -> MatMul(score_weight) -> scores -> Softmax(axis=1)
       -> probabilities -> MatMul(value_weight) -> context
       -> Add(bias) -> logits
```

The frozen inventory is `MatMul`, `Softmax(axis=1)`, `MatMul`, and `Add`, all float32. The host/reference input is `[1.0, -1.0]`, and the ONNX Runtime reference logits are approximately `[1.98079705, 1.01920295]` with tolerance `1e-6`.

This is transformer-style operator coverage, not the P5 tiny-LLM proof. It intentionally does not claim tokenizer, positional encoding, multi-token context, KV cache, or language-model generation acceptance.
