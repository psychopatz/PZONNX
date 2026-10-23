# PZONNX Progress

Last reconciled: P0A packaged binary probe implementation.

## Current phase

**P0 — Binary and protobuf foundation**

State: IN PROGRESS.

## Verified foundation

- Repository exists and is writable.
- Project identity is PZONNX.
- Build target is Project Zomboid 42.20.
- Runtime constraint is pure supported Lua/Kahlua; development-time external reference tooling is allowed.
- Current Project Zomboid API documentation exposes `getGameFilesInput(String)` returning `DataInputStream`; `getFileInput(String)` is documented as Lua-cache input and is not the selected packaged-asset path.

## Implemented in source

- Build 42.20 mod descriptor.
- Lua bootstrap/diagnostics module.
- byte reader primitives for DataInputStream-like objects exposed to Lua;
- protobuf wire tag/skip primitives;
- float32 little-endian decode without native bit operators;
- deterministic 16-byte packaged protobuf fixture;
- reproducible development-time fixture generator;
- `getGameFilesInput` adapter behind the IO boundary;
- P0A runtime probe scheduled at `OnGameStart`;
- host-style fake-stream smoke vectors including the complete P0 fixture.

## Evidence status

Source-verified:

- repository contents and fixture bytes;
- P0A parser/probe implementation.

Not independently host-run in the current ChatGPT execution environment:

- no Lua/LuaJIT interpreter is available in the local execution container.

Not yet PZ-runtime verified:

- whether `media/pzonnx/fixtures/p0_probe.pb` resolves through the Build 42.20 mod virtual filesystem exactly as assumed;
- DataInputStream method bridging in the live game;
- expected P0A PASS log.

## Next Chunk — P0A runtime acceptance

1. Install/enable the mod in Build 42.20.
2. Start a game and capture the PZONNX P0A diagnostic line.
3. If path or Java-method bridging fails, fix only the IO boundary and rerun.
4. Preserve the exact runtime evidence in this ledger.
5. After P0A passes, begin P0B with a genuine minimal ONNX fixture.

Expected success evidence:

```text
[PZONNX] INFO probe=P0A status=PASS path=media/pzonnx/fixtures/p0_probe.pb bytes=16 varint=150 text=PZONNX float32=1.0
```

## Phase exit

P0 exits only when a genuine ONNX file is read through the supported game path and its top-level protobuf structure is correctly identified.

## Evidence labels

Use these labels in future updates:

- source-verified;
- host-test verified;
- PZ runtime verified;
- reference-runtime verified;
- partial;
- unsupported/unproven.
