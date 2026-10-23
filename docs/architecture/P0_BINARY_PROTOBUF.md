# P0 — Binary and Protobuf Foundation

## Purpose

Prove that ordinary Project Zomboid Lua can access packaged binary data with byte-exact behavior and that PZONNX can decode the protobuf wire primitives needed by ONNX.

This phase deliberately does not implement ONNX graph semantics.

## Supported file API decision

Project Zomboid exposes two relevant global APIs:

- `getFileInput(filename)` — Lua-cache file input;
- `getGameFilesInput(filename)` — game/mod virtual-filesystem input.

PZONNX uses `getGameFilesInput` for packaged runtime assets. The exact mod-relative virtual path remains a runtime acceptance item until exercised in Build 42.20.

## P0A deterministic fixture

Packaged fixture:

`media/pzonnx/fixtures/p0_probe.pb`

Logical protobuf content:

- field 1, varint: `150`
- field 2, length-delimited UTF-8/ASCII: `PZONNX`
- field 3, fixed32 interpreted as IEEE-754 float32: `1.0`

Expected bytes:

```text
08 96 01
12 06 50 5A 4F 4E 4E 58
1D 00 00 80 3F
```

Total: 16 bytes.

This is a generic protobuf probe, not an ONNX model. It exists solely to isolate the binary path from later ONNX semantic parsing.

## Runtime probe

`PZONNX/Diagnostics/P0Probe.lua` opens the packaged fixture through the IO adapter, validates all three fields, and emits a compact PASS line only after all checks succeed.

Expected evidence shape:

```text
[PZONNX] INFO probe=P0A status=PASS ... bytes=16 varint=150 text=PZONNX float32=1.0
```

A source-level implementation does not satisfy this gate. The line must be observed from Project Zomboid runtime output.

## P0B — real ONNX top-level parse

After P0A is runtime-verified:

1. generate a minimal real ONNX model with development tooling;
2. package the fixture;
3. parse ModelProto fields required to identify IR version, opset import, producer metadata, and graph envelope;
4. compare those values with a trusted ONNX inspector;
5. preserve unknown-field skipping and truncation failures.

P0 exits only after P0B succeeds through the game runtime.
