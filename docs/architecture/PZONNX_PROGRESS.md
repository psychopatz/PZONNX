# PZONNX Progress

Last reconciled: P8 developer-side and host/reference acceptance; all mandatory developer-side roadmap phases implemented.

## Parent goal

Build the complete experimental pure-Kahlua ONNX runtime through the approved real-ONNX, graph execution, tiny-LLM, resumable/quantized inference, TTS, and integration milestones.

Parent state: **IN PROGRESS**.

## Current major phase

**P8 — integration and hardening**

Developer state: **P0A-P8 mandatory developer-side implementation and host/reference acceptance complete.**

Native acceptance state: **P0A-P8 PZ runtime gates OPEN / UNVERIFIED.**

## Source-verified foundation

- Build 42.20 mod descriptor and shared bootstrap.
- byte reader with offsets and protobuf varint support;
- fixed32 and pure-Lua float32 decoding;
- protobuf wire tag/length/skip primitives;
- deterministic 16-byte packaged protobuf fixture;
- reproducible fixture generator;
- game-file adapter using `getGameFilesInput`;
- bounded P0A diagnostic probe scheduled for game start;
- host-style fake-stream smoke vectors.

P0B developer-side acceptance:

- genuine `media/pzonnx/fixtures/p0b_minimal.onnx` ModelProto fixture packaged;
- independent `tools/inspect_p0b_fixture.py` metadata inspection agrees with `tools/p0b_reference.json`;
- ONNX library checker accepted the fixture as a valid model (`ir_version=8`, default opset 13, one Identity node);
- top-level ModelProto parser identifies IR version, producer metadata, opset imports, graph name, and bounded graph counts;
- unknown-field skipping and truncated length-delimited input have focused Lua tests;
- bounded P0B diagnostic probe is scheduled for game start;
- host Lua tests, `luac -p`, and the PZ Kahlua verifier pass.

P1 indexing-slice developer-side acceptance:

- `NodeProto` metadata is represented without execution: inputs, outputs, name, op type, domain, and attribute count;
- tensor `ValueInfoProto` names, tensor element types, and fixed/symbolic shape dimensions are represented;
- inline `TensorProto` dimensions, datatype, source/message offsets, raw-data offset/length, and storage location are indexed without retaining raw bytes;
- external initializer references are represented as bounded key/value metadata, including location, offset, and length;
- `initializerIndex` provides name-based lookup and compatibility inspection reports operators, opsets, datatypes, and explicit P2 execution-unavailable diagnostics;
- genuine `p1_metadata.onnx` plus its sidecar is independently inspected and accepted by the ONNX checker;
- focused Lua indexing tests, syntax checks, and the PZ Kahlua verifier pass.

P1 compatibility-completion acceptance:

- `AttributeProto` name, declared type, and payload kind are represented without expanding tensor/graph payloads;
- compatibility reports preserve inspection-only operator status and explicitly report missing/mismatched/unindexed attribute metadata, unknown datatypes, and invalid storage declarations;
- trusted inspector/reference manifests cover both an inline/external initializer model and a valid `Cast(to=INT)` attribute model;
- focused tests cover attribute metadata, unknown-field skipping, wrong-wire rejection, truncation, and explicit unsupported diagnostics;
- bounded P1 probe code covers operator, datatype, inline raw-data, external-data, and attribute metadata.

P2 numerical execution acceptance:

- genuine `p2_linear.onnx` fixture contains a 2-D float32 `MatMul -> Add` graph and compact inline initializers;
- `tools/p2_reference.json` records exact input, expected output, `onnxruntime` reference lane, and `1e-6` tolerance;
- development-time ONNX checker and ONNX Runtime both accept the fixture and produce output `2.5`;
- pure-Lua `Tensor` and `Session` execute only supported 2-D float32 MatMul and same-shape Add paths;
- initializer bytes are reopened and decoded on demand from recorded offsets, with no retained full-model byte table;
- unsupported operators, attributes, initializer datatypes, and shape mismatches fail explicitly;
- focused P2 Lua numerical tests, syntax checks, Kahlua verification, and bounded P2 probe code pass.

P3 operator-runtime acceptance:

- `OperatorRegistry` owns explicit MatMul/Add operator specifications, arity, attribute policy, and execution dispatch;
- compatibility inspection predicts registry-supported versus unregistered/attribute-incompatible paths;
- tensor broadcast-shape and flat-index mapping are deterministic and reject incompatible dimensions explicitly;
- genuine `p3_broadcast.onnx` fixture uses Add with `[1,2] + [2]` and ONNX Runtime matches `[3.5, 3.5]` at `1e-6`;
- P2 exact-shape behavior remains covered through the same registry;
- focused registry/broadcast tests, syntax checks, Kahlua verification, and bounded P3 probe code pass.

P4 transformer-style coverage acceptance:

- frozen `p4_tiny_attention.onnx` inventory is `MatMul`, `Softmax(axis=1)`, `MatMul`, `Add`, all float32;
- bounded hidden width and one-token input are documented in `P4_TINY_TRANSFORMER.md`;
- ONNX Runtime reference logits are `[1.98079693, 1.01920283]` with maximum error `1.2e-7` against the recorded reference;
- pure-Lua forward pass matches the declared `1e-6` tolerance;
- compatibility inspection reports every required operator/attribute path as registry-supported;
- focused P4 tests, syntax checks, Kahlua verification, and bounded P4 probe code pass;
- tokenizer, positional encoding, KV cache, multi-token context, and general LLM generation remain intentionally unclaimed.

P5 one-token acceptance:

- frozen `p5_tiny_lm.onnx` inventory is `Gather(axis=0)`, `MatMul`, and `Add`, with int64 token input and float32 weights/logits;
- bounded model dimensions are vocabulary size three and hidden size two, with precomputed token ID `1` as input;
- ONNX Runtime reference logits are `[0.60000002, 0.40000001, -0.10000000]` and select token ID `0` at `1e-6`;
- pure-Lua `TinyLM` adapter matches logits and deterministic argmax choice;
- focused P5 tests, syntax checks, Kahlua verification, and bounded P5 probe code pass;
- this is not tokenizer, multi-token, KV-cache, production-scale, or general text-generation acceptance.

P6 resumable/quantized acceptance:

- `InferenceJob.step(budget)` owns cursor, state, bounded node work, terminal completion/cancellation, and failure cleanup;
- `Session.run` is a convenience wrapper over the explicit job contract, while `Session:newJob` exposes cooperative execution;
- cancellation and positive-budget validation have focused tests;
- opt-in int8 initializer storage uses declared scale `0.02`, reduces the float32 initializer storage footprint, and preserves the P2 output within `1e-6`;
- P6 probe code records node budget, terminal state, storage mode/scale, and numerical output;
- focused P6 tests, syntax checks, Kahlua verification, and bounded P6 probe code pass.

P7 numeric TTS acceptance:

- frozen `p7_tiny_tts.onnx` inventory is `Gather`, `MatMul`, and `Add` with int64 precomputed token input and float32 numeric output;
- `TinyTTS` is a separate adapter with bounded one-token/one-block behavior and no Project Hoomans/PBrainz dependency;
- ONNX Runtime reference PCM is `[0.5, -0.15, 0.32, 0.3]` with maximum error below `3e-8` against the recorded reference;
- pure-Lua adapter output matches the declared `1e-6` tolerance;
- focused P7 tests, syntax checks, Kahlua verification, and bounded P7 probe code pass;
- phonemization, vocoder quality, full-sentence TTS, and production audio acceptance remain explicitly unclaimed.

P8 integration/hardening acceptance:

- stable public API exposes model loading/inspection, sessions, bounded jobs, capabilities, runtime status, and adapters;
- `Fallback` adopter boundary preserves a primary path on success and reports/degrades cleanly to an existing fallback on unsupported/failing PZONNX execution;
- generic runtime modules do not import Project Hoomans or PBrainz;
- host adopter-contract tests cover inspection, cooperative jobs, primary success, fallback success, and visible primary errors;
- bounded P8 diagnostic probe reports API/fallback readiness while retaining open native-gate status;
- all Lua syntax checks, PZ Kahlua verification, focused P0-P8 host tests, and ONNX Runtime reference checks pass.

## Open evidence

Not yet PZ-runtime verified:

- packaged fixture virtual path resolution;
- DataInputStream method bridging;
- expected P0A PASS line;
- real ONNX fixture virtual path resolution and top-level parser execution;
- expected P0B PASS line.
- P1 indexed fixture virtual path resolution and metadata probe execution;
- expected P1 PASS line.
- P1 attribute fixture and compatibility report virtual path resolution;
- expected complete P1 PASS line.
- P2 fixture virtual path resolution and pure-Kahlua numerical execution;
- expected P2 PASS line with reference-consistent output.
- P3 registry dispatch and broadcast execution through the packaged fixture;
- expected P3 PASS line with reference-consistent output.
- P4 fixture virtual path resolution and bounded transformer-style forward pass;
- expected P4 PASS line with reference-consistent logits.
- P5 fixture virtual path resolution and one-token adapter execution;
- expected P5 PASS line with reference-consistent logits and token choice.
- P6 cooperative job budget/cancellation and quantized initializer path;
- expected P6 PASS line with reference-consistent output and storage measurement.
- P7 numeric-audio fixture virtual path resolution and bounded TTS adapter execution;
- expected P7 PASS line with reference-consistent PCM values.

## Final developer-side handoff

All mandatory developer-side roadmap phases P0A-P8 are implemented and have source/host/reference evidence. Project Zomboid runtime evidence remains open for the accumulated bounded probes:

- P0A packaged binary/protobuf path;
- P0B genuine ONNX top-level parse;
- P1 model indexing/compatibility inspection;
- P2/P3 numerical graph execution and operator runtime;
- P4 transformer-style forward pass;
- P5 one-token tiny-LM proof;
- P6 cooperative/quantized execution;
- P7 numeric TTS path;
- P8 adopter/fallback boundary.

Required handoff state: **READY FOR USER LIVE TEST**.

This is not a claim of Project Zomboid runtime acceptance or complete parent-goal acceptance. Do not mark the parent goal completed until the required native evidence is captured and reviewed.

Expected P0A native success evidence:

```text
[PZONNX] INFO probe=P0A status=PASS path=media/pzonnx/fixtures/p0_probe.pb bytes=16 varint=150 text=PZONNX float32=1.0
```

These remain mandatory acceptance items but are not a reason to stop developer-side implementation.

## Exact Next Chunk — none developer-implementable

No mandatory developer-side roadmap chunk remains after P8.

Required work:

1. user-owned live testing is required to close the accumulated native gates;
2. preserve every probe and expected evidence line for that run;
3. do not claim PZ runtime or parent acceptance from host/reference evidence.

Do **not** add transformer-specific logic in this chunk.

## Following chunk

After the accumulated native probes pass in stock Project Zomboid Build 42.20, reassess the parent acceptance criteria; until then report **READY FOR USER LIVE TEST**.

## Evidence labels

Use:

- source-verified;
- host/reference verified;
- PZ runtime verified;
- real-model verified;
- adopter verified;
- open native gate;
- partial;
- unsupported/unproven.

## Final handoff rule

If all developer-implementable mandatory work is complete and only user-owned native verification remains, report:

**READY FOR USER LIVE TEST**

Do not report COMPLETED or BLOCKED in that state.

## Targeted external-model probe — 2026-10-23

The requested Hugging Face model was tested outside the repository using the
13,077,992-byte `onnx/model_int8.onnx` export (SHA-256
`33c4f02ff02d3c997d76f190ecbe1d6e88307182a4d7caf8be49db1ded60839b`). The
artifact was kept in `/tmp`, not packaged or published.

- Host Lua streaming `BinaryReader` + `Model.parseReader` passed on the genuine
  ModelProto: IR 8, graph `main_graph`, 408 nodes, 30 initializers, 5 inputs,
  3 outputs, and 375 value-info entries.
- A bounded `Session:newJob()` executed all 408 nodes using packed initializer
  storage. The job completed with `state=completed`, `cursor=409`, and
  `work=408`; no native library, JNI, Python runtime, server, or companion
  process was used by the Lua execution.
- With `input_ids=[[1]]`, `attention_mask=[[1]]`, `position_ids=[[0]]`, and
  empty layer-0 KV inputs, Lua produced token index `9309` (zero-based),
  `max(logits)=11.559551055381`, and logits beginning
  `9.3276447538538,9.4631352458317,1.989958994424`.
- A development-time explicit int32 reference graph, rewriting each
  `MatMulInteger` as centered int32 `Cast`/`Sub`/`MatMul`, produced the same
  token index and logits within approximately `1e-6`; the first five present
  key/value elements also matched within float32 rounding. This is the
  numerical reference used for the result because it directly exercises the
  ONNX operator semantics.
- The installed ONNX Runtime CPU provider's original mixed uint8/int8
  `MatMulInteger` path differed in two projection elements and consequently
  reported `max(logits)=11.401731491089`, although it selected the same token
  index `9309`. That provider discrepancy is retained as evidence, not treated
  as Lua acceptance evidence.

This is host/reference evidence only. It proves the current runtime can execute
this real tiny-LLM export in host Lua, but it is not Project Zomboid runtime
acceptance. The accumulated native PZ gates remain open and the required
handoff state is still **READY FOR USER LIVE TEST**.

The follow-up regression pass also fixed packed-initializer quantization,
preserved the stable MatMul shape-mismatch diagnostic, and updated the Cast
compatibility expectation. All `tests/test_*.lua` tests now pass, Kahlua
verification reports zero errors, and the graph index has no recorded parse or
coverage gaps for the changed runtime/test files.
