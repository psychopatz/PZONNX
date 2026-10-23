# PZONNX Architecture

## Product boundary

PZONNX is not a port of Microsoft ONNX Runtime.

It is a selective, model-driven ONNX inference runtime written for Project Zomboid's supported Lua/Kahlua environment. Its target is not one TinyLLM export: it should accept any ONNX model package whose required protobuf features, tensor datatypes, operators, opset semantics, memory requirements, tokenizer/generation metadata, and runtime contract PZONNX supports.

"Model agnostic" does not mean every arbitrary ONNX graph is guaranteed to run. It means trying a new compatible model should not require hard-coding that model into the runtime.

## Runtime invariant

Inference acceptance requires stock Project Zomboid Lua/Kahlua-accessible APIs only.

Forbidden as a substitute for runtime inference:

- native DLL/shared-library inference;
- JNI/custom Java classes;
- JVM patching/injection;
- Python at game runtime;
- localhost/remote inference servers;
- companion inference executables.

Development-time Python/ONNX/ONNX Runtime may generate fixtures, inspect/export models, create reference outputs, profile compatibility, and optimize model artifacts.

## Two file domains

PZONNX intentionally separates internal regression assets from user models.

### Internal packaged fixtures

```text
Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/
```

These are small deterministic tests and may use the packaged game-file IO path.

### User model store

Authoritative user-visible root:

```text
Zomboid/Lua/Models/
```

Authoritative discovery manifest:

```text
Zomboid/Lua/Models/ledger.txt
```

PZONNX must not depend on directory enumeration. The ledger explicitly lists model entry files.

Example:

```text
# one entry model per line
tinyllm/model_int8.onnx
llama/model.onnx
qwen/decoder.onnx
```

Blank lines and comment lines are ignored. Entries are root-relative and must never escape `Zomboid/Lua/Models/`.

The exact Lua API path used to reach this user-visible directory remains a runtime contract to verify; ONNX/model logic must not depend directly on that bridge detail.

## Layered architecture

```text
                 Zomboid/Lua/Models/ledger.txt
                              |
                              v
                         ModelStore
                              |
                              v
                         ModelEntry
                              |
                              v
                         ModelPackage
                 /------------+-------------\
                v             v              v
          ONNX files       configs       tokenizer assets
                |             |              |
                +-------------+--------------+
                              |
                              v
                         ModelProfile
                              |
              /---------------+----------------\
             v                v                 v
        compatibility    generation       tokenizer
                           contract         contract
             \                |                 /
              +---------------+----------------+
                              |
                              v
                       ONNX Execution Core
          IO -> Protobuf -> Model -> Tensor -> Operators
                              |
                              v
                     ExecutionPlan / Session
                              |
                              v
                    resumable kernel scheduler
                              |
                 /------------+-------------\
                v                          v
          Generative Runtime             TTS/Pipeline
      tokenizer -> prefill -> KV
          -> decode -> sampling
```

## Ownership

### IO

Owns byte-exact access and source abstraction. Packaged fixtures and user model files must share a reader contract but use separate source adapters.

### ModelStore

Owns `Models/ledger.txt`, safe relative-path validation, lazy registry entries, refresh, missing-entry diagnostics, and model-package roots. It must not parse every model during startup.

### ModelPackage

Owns one logical model directory/package: ONNX entry point(s), known companion metadata/config files, tokenizer assets, and relative external-weight resolution.

### ModelProfile

Owns discovered task/architecture/generation contract. It should derive evidence in priority order:

1. explicit generative config when present;
2. standard model/config/tokenizer metadata;
3. ONNX graph names, shapes, types, and structural patterns;
4. optional PZONNX override only when automatic discovery is insufficient.

The profile records both the inferred result and the evidence/confidence. It must not silently guess required fields.

### ONNX

Owns protobuf ONNX semantics: ModelProto, graph, tensors, attributes, opsets, external-data metadata, compatibility inspection, and source offsets.

### Tensor / operators

Own numerical semantics. Operator dispatch must ultimately be **opset-aware**, datatype-aware, and explicit about supported attribute combinations.

### ExecutionPlan / Session

Own graph scheduling, value lifetime, initializer policy, scratch buffers, cancellation, execution state, and model outputs.

### Kernel scheduler

Heavy operators must be resumable below whole-node granularity. A graph node is not a valid responsiveness budget when one MatMul can perform millions of multiply-accumulates.

Current resumable MatMul/MatMulInteger is accepted foundation; the same rule should extend to other kernels that can monopolize a frame.

### Generative runtime

Owns generic causal-decoder behavior:

- text tokenization;
- prompt prefill;
- automatic input construction;
- KV-cache creation/update/reuse;
- one-token decode;
- logits selection;
- sampling;
- EOS/BOS/PAD behavior;
- token-to-text decoding;
- cancellation/progress.

It must consume a `ModelProfile` rather than hard-code TinyLLM/Llama/Qwen branches unless a genuinely family-specific contract requires a plugin/adapter.

### UI

The UI is a test/product surface, not model logic.

The current "Tiny-LLM Chat Probe" is actually a **forward-pass/token probe**: prompt text is only a transcript label, raw token IDs are the model input, and one next-token ID/logit is displayed. Preserve it as a diagnostic surface until the real generative runtime exists; do not treat it as chat acceptance.

## Model package discovery

Given ledger entry:

```text
llama/model.onnx
```

PZONNX derives package root:

```text
Zomboid/Lua/Models/llama/
```

It may probe known companion names without enumerating the directory, for example:

- `genai_config.json`;
- `config.json`;
- `generation_config.json`;
- `tokenizer.json`;
- `tokenizer_config.json`;
- `special_tokens_map.json`;
- `vocab.json`;
- `merges.txt`;
- ONNX-declared external tensor files.

Missing optional files are not errors by themselves.

## Performance architecture

PZONNX has two independent performance requirements.

### Responsiveness

Long work must yield to Project Zomboid. "One graph node per tick" is insufficient when a single node is large.

### Throughput

The runtime should minimize interpreted work through measured optimization:

- specialized flat-index matrix kernels;
- integer/quantized fused kernels;
- graph constant folding;
- safe operator/subgraph fusion;
- precomputed strides and shape metadata;
- buffer/scratch reuse;
- value liveness and early release;
- initializer resident/paged/streamed policies;
- true KV-cache decode rather than recomputing history.

Optimization must be profiler-driven and preserve numerical acceptance.

## Memory strategy

Avoid full-model boxed-scalar expansion.

Prefer:

- packed initializer storage;
- lazy/external initializer access;
- compact graph/profile metadata;
- bounded activations;
- explicit KV-cache limits;
- liveness-based intermediate release;
- scratch-buffer reuse;
- streaming/paging for large weights when feasible.

## Error philosophy

Unsupported is a valid, useful result.

A new model should resolve to a diagnostic state such as:

```text
FOUND
PARSED
PROFILED
GENERATION CONTRACT RECOGNIZED
UNSUPPORTED:
  FLOAT16 initializer decode
  com.microsoft::GroupQueryAttention
```

rather than crashing startup or silently approximating semantics.

## Public direction

The eventual primary flow should be closer to:

```text
PZONNX.refreshModels()
PZONNX.listModels()
PZONNX.loadModel(modelId)
PZONNX.createGenerator(model)
generator:prompt(text)
generator:step(budget)
```

rather than requiring adopters to know packaged ONNX paths or construct TinyLM-specific inputs manually.
