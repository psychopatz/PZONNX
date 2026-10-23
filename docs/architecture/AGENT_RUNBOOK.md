# PZONNX Agent Runbook

## Mission

Implement the complete approved PZONNX roadmap as an experimental pure-Kahlua ONNX runtime for Project Zomboid.

A phase is an organizational boundary, not a redefinition of the product goal.

## Mandatory runtime boundary

Do not solve inference by adding:

- DLL/shared libraries;
- JNI;
- custom Java classes;
- Java patching/injection;
- Python at game runtime;
- external/localhost inference services;
- companion executables.

If a required feature appears impossible under this boundary, prove the limitation with a minimal reproducer and document it. Do not quietly cross the boundary.

## Development tools

Outside-game tools may:

- generate tiny ONNX fixtures;
- export a selected model to ONNX;
- inspect protobuf/model metadata;
- run ONNX Runtime for reference outputs;
- produce operator inventories;
- compare numerical output.

They are test/reference infrastructure, not runtime dependencies.

## Execution discipline

1. Read `PZONNX_ARCHITECTURE.md`.
2. Read `PZONNX_ROADMAP.md`.
3. Read `PZONNX_PROGRESS.md`.
4. Start from the exact current Next Chunk.
5. Implement and validate it.
6. Reconcile PROGRESS with evidence.
7. Continue to the next mandatory chunk when the current gate is genuinely satisfied.
8. Do not stop merely because one phase/test/commit completed.

## Evidence discipline

Never claim:

- "works in PZ" from host Lua tests;
- "loads ONNX" from a hand-authored protobuf-only fixture;
- "supports an operator" from one unsupported-attribute shortcut;
- "LLM works" from model parsing without correct logits;
- "TTS works" from producing a WAV container without reference-consistent audio samples.

Keep synthetic fixtures and real-model acceptance distinct.

## Performance discipline

Correctness first.

Before optimizing, preserve a reference-correct implementation or fixture. Measure before and after meaningful optimization. Do not replace correct semantics with an approximation unless the approximation is explicit, optional, and separately characterized.

## Memory discipline

Avoid full-model boxed-scalar expansion. Large initializer handling must stay bounded enough to preserve the experiment's purpose.

## Git discipline

Preserve unrelated work. Keep commits coherent. Do not publish to Steam Workshop or other distribution channels. GitHub publication must follow the active execution authorization; repository access alone is not standing permission for unrelated destructive changes.

## True blockers

A blocker is something that prevents further safe implementation, such as:

- supported PZ Lua cannot access the required binary bytes and no supported equivalent exists;
- a required numeric operation cannot be represented with acceptable correctness and no model/export alternative exists;
- repository/auth state prevents required work;
- a user-authored conflict makes intended edits unsafe.

Slow performance, one failed optimization, or one unsupported model is not automatically a blocker for the whole runtime.
