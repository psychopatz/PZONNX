# PZONNX Architecture

## Product boundary

PZONNX is not a port of Microsoft ONNX Runtime and must not present itself as one.

It is a selective ONNX interpreter/runtime designed for the constraints of Project Zomboid's supported Lua/Kahlua environment. Compatibility is model-driven: PZONNX supports a model only when every required datatype, protobuf feature, ONNX operator, shape rule, and runtime behavior needed by that model is implemented and verified.

## Runtime invariant

The core experiment is valid only when inference occurs inside stock Project Zomboid through supported Lua/Kahlua-accessible APIs.

Forbidden as a substitute for the runtime:

- native DLL/shared-library inference;
- JNI or custom Java classes;
- JVM patching/injection;
- Python at game runtime;
- localhost/remote inference servers;
- companion executables.

Development-time Python, ONNX, and ONNX Runtime are allowed only to create fixtures, inspect models, and produce trusted reference outputs.

## Layers

```text
Model file
  |
  v
IO / BinaryReader
  |
  v
Protobuf wire decoder
  |
  v
ONNX model/index layer
  |
  +--> lazy initializer metadata / weight access
  |
  v
Tensor representation
  |
  v
Operator kernels
  |
  v
Graph executor / Session
  |
  v
Incremental inference job
  |
  +--> LLM adapter
  +--> TTS adapter
```

## Ownership

### IO

Owns byte-exact access and offsets. It does not understand protobuf or ONNX.

### Protobuf

Owns protobuf wire decoding, field tags, length-delimited regions, and safe skipping of unknown fields. It does not understand ONNX semantics.

### ONNX

Owns ModelProto/GraphProto/TensorProto interpretation, opsets, node attributes, shapes, initializers, and compatibility diagnostics.

### Tensor

Owns tensor shape, element indexing, temporary buffers, numeric conversion, and later quantized representations.

### Ops

Each supported operator owns its ONNX semantics and numerical kernel. Unsupported attributes or type combinations must fail explicitly.

### Runtime

Owns graph scheduling, value lifetimes, execution state, cancellation, work budgeting, and incremental/resumable execution.

### Adapters

LLM and TTS layers translate model-specific inputs/outputs. They may not bypass the runtime with native inference.

## Memory strategy

Naively expanding a model into Lua tables is unacceptable for larger experiments.

PZONNX should prefer:

- compact graph metadata;
- lazy or bounded initializer decoding;
- reusable scratch buffers;
- bounded activation lifetime;
- explicit KV-cache limits;
- streaming/blockwise weight access where practical;
- quantized storage only after correctness is proven.

Every optimization must preserve a reference-correct path for testing.

## Scheduling strategy

Long inference must not monopolize a Project Zomboid frame.

The target runtime exposes resumable work:

```text
InferenceJob.step(budget)
  -> perform bounded work
  -> persist execution cursor
  -> yield to game
  -> resume later
```

The exact budget unit may evolve from primitive operations to rows/blocks/nodes, but the scheduler must be deterministic and auditable.

## Error philosophy

Unsupported is a valid result.

PZONNX must prefer:

```text
unsupported operator: LayerNormalization opset 17 attribute ...
```

over silent approximation.

Every model load should eventually produce a compatibility report containing required opsets, operators, datatypes, unsupported features, and estimated memory-relevant metadata.

## Numerical acceptance

Correctness is evaluated against trusted development-time reference outputs.

Tolerance is declared per fixture and datatype. PZONNX must not loosen tolerance merely to pass a model.

## First architectural proof

The first complete proof is intentionally small: a genuine ONNX model, parsed and executed in PZ Lua, with numerically matching output.

Transformer and TTS work cannot substitute for this foundation.
