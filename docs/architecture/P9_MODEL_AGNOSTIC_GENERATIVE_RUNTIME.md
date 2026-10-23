# P9 — Model Store & Model-Agnostic Generative Runtime Foundation

## Why this phase exists

P0-P8 proved that PZONNX can parse ONNX, execute reference fixtures, run a real 408-node quantized tiny-LLM graph in host Lua, and expose a bounded in-game inference probe.

That foundation exposed the real remaining product gap:

```text
working graph executor
!=
usable model-agnostic LLM inference runtime
```

The current chat window accepts raw numeric token IDs; its prompt text is only a transcript label. It returns one next-token ID/logit. This is a useful forward-pass debugger, not chat generation.

P9 begins the architecture that turns the executor into a real inference product.

## Authoritative model location

User models live under:

```text
Zomboid/Lua/Models/
```

Because Project Zomboid cannot be relied on to enumerate arbitrary files there, discovery is explicit:

```text
Zomboid/Lua/Models/ledger.txt
```

Example:

```text
# comments are allowed
tinyllm/model_int8.onnx
llama/model.onnx
qwen/decoder.onnx
```

The ledger is a locator, not a model-description database. Do not encode architecture/head counts/vocab/etc. into ledger fields.

## P9A — ModelStore + ledger

### Responsibilities

Create a dedicated user-model IO boundary and registry.

Suggested ownership:

```text
PZONNX/IO/UserFile.lua
PZONNX/Models/ModelStore.lua
PZONNX/Models/ModelEntry.lua
```

Names may vary if repository conventions justify it, but responsibilities must remain separate from packaged fixture IO.

### Ledger rules

- one relative model entry path per line;
- trim surrounding whitespace;
- blank lines ignored;
- lines beginning with `#` ignored;
- duplicate entries handled deterministically;
- reject `..` traversal;
- reject absolute paths;
- reject Windows drive/UNC/network paths;
- normalize separators conservatively;
- resolved path must remain under `Zomboid/Lua/Models/`.

### Registry behavior

```text
refresh ledger
    |
    +--> valid existing entry -> REGISTERED
    +--> missing entry         -> MISSING
    +--> malformed entry       -> INVALID
```

One bad line must not make all models disappear.

Startup must not parse all model graphs. Entries are lightweight until explicitly inspected/loaded.

### Public direction

At minimum the registry should support equivalent operations to:

```text
refreshModels()
listModels()
getModelEntry(id/path)
```

Exact naming can be reconciled with the public API.

### P9A acceptance

- host tests for ledger parsing/path safety/duplicates/missing entries;
- source adapter uses only supported PZ Lua-user-file APIs at runtime;
- bounded native probe can report ledger count/status without loading model graphs;
- no packaged `media/...` path is required for user-model discovery;
- existing packaged fixtures continue to work for regression tests.

## P9B — ModelPackage

A registered model entry becomes a logical package.

Given:

```text
llama/model.onnx
```

derive package root:

```text
Models/llama/
```

Probe known companion filenames without enumeration. Capture present/missing metadata lazily.

External ONNX tensor references must resolve relative to the model/package and remain within the approved root.

## P9C — ModelProfile

Create a model-independent description consumed by generation.

Candidate fields:

```text
task
architecture
modelFiles
inputRoles
outputRoles
inputIds
attentionMask
positionIds
logits
pastKeyPattern
pastValuePattern
presentKeyPattern
presentValuePattern
layerCount
contextLength
vocabSize
bosToken
eosTokens
padToken
tokenizer
externalData
requiredOperators
requiredDatatypes
compatibility
detectionEvidence
confidence
```

Do not require every field for every model. Unknown must remain unknown rather than guessed.

Detection priority:

1. explicit generative config;
2. standard config/generation/tokenizer metadata;
3. ONNX graph names/shapes/types/structure;
4. optional PZONNX override.

## P9D — Generic model probe

Replace one-off external-model probing with a reusable compatibility path that accepts an arbitrary model/package and emits:

- parse result;
- model profile;
- opsets/operators/datatypes;
- external-data requirements;
- tokenizer status;
- generation-contract status;
- execution gaps;
- optional bounded forward-pass evidence.

TinyLLM stays as one regression case, not a special code path.

## Performance boundary inherited by P9

The recent resumable MatMul/MatMulInteger work is accepted foundation.

Do not regress to whole-kernel blocking while adding new model loading/profiling paths.

Performance optimization beyond responsiveness belongs primarily to P14, but any new heavy operation must expose a bounded path if it can stall the game.

## Out of scope for P9A

Do not implement in the first chunk:

- tokenizer algorithms;
- multi-token generation;
- KV-cache orchestration;
- sampling;
- broad operator additions;
- UI redesign;
- speculative Llama/Qwen-specific branches.

P9A succeeds when PZONNX has a safe, lazy, ledger-backed user model registry.
