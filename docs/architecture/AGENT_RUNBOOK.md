# PZONNX Agent Runbook

## Mission

Own the complete approved PZONNX roadmap as one autonomous implementation assignment.

The current product goal is a **model-agnostic generative ONNX runtime**, not merely parsing ONNX or reproducing one TinyLLM next-token result.

A phase organizes work; it never redefines parent completion.

## Mandatory runtime boundary

Do not solve runtime inference by adding:

- DLL/shared libraries;
- JNI/custom Java classes;
- Java/JVM patching;
- Python at game runtime;
- external/localhost inference services;
- companion inference executables.

Development/reference tooling outside the game may use Python, ONNX, ONNX Runtime, tokenizer libraries, exporters, profilers, and model optimization tools.

## Required reading order

1. `PZONNX_ARCHITECTURE.md`
2. `PZONNX_ROADMAP.md`
3. `PZONNX_ACCEPTANCE.md`
4. `PZONNX_PROGRESS.md`
5. current phase doc, currently `P9_MODEL_AGNOSTIC_GENERATIVE_RUNTIME.md`
6. `PZONNX_CHAT_UI.md` when touching UI/testing
7. `GOAL_PROMPT.md`

Then inspect current HEAD and relevant implementation.

## Autonomous execution loop

For each Next Chunk:

1. audit current source/evidence;
2. implement one coherent responsibility;
3. add focused host/reference verification;
4. add/update a bounded native probe where useful;
5. update PROGRESS with exact evidence;
6. immediately continue to the next approved developer-implementable chunk after acceptance;
7. do not stop merely because one phase or test passes.

## User model-store policy

The authoritative user model location is:

```text
Zomboid/Lua/Models/
```

and discovery is through:

```text
Zomboid/Lua/Models/ledger.txt
```

Do not introduce automatic directory scanning as a hidden dependency.

Ledger/model-package paths must remain beneath the model root. Reject path traversal, absolute paths, drive/network paths, and external-data references escaping the package/model root.

Packaged `media/pzonnx/fixtures/` files remain internal regression assets and must not become the user-model architecture.

## Model-agnostic policy

Do not solve each model by adding:

```text
if TinyLLM ...
elseif Llama ...
elseif Qwen ...
```

to generic execution code.

Use graph/config-driven ModelProfile discovery and generic contracts. Family-specific plugins are acceptable only when a genuine model-family contract cannot be represented generically; such specialization must be isolated and documented.

TinyLM/Chat adapters are historical/regression helpers, not the desired public generation architecture.

## Performance discipline

Correctness first, then measurement, then optimization.

Preserve trusted numerical references while optimizing.

Distinguish:

- **responsiveness** — bounded work/yield/cancel/progress;
- **throughput** — actual inference latency.

A whole ONNX node is not automatically a safe scheduler unit. Heavy kernels must be resumable below node granularity.

Use profiler evidence before broad optimization. Prioritize real-model hotspots, especially matrix/quantized linear paths.

Do not claim an optimization from smaller storage alone; record before/after runtime or work metrics where the phase requires speed claims.

## Memory discipline

Avoid whole-model boxed scalar expansion.

Prefer packed/lazy/external weights, value liveness, early release, scratch reuse, explicit KV-cache limits, and measured resident/paged/streamed policies.

## Evidence discipline

Never claim:

- "works in PZ" from host tests;
- "chat works" when prompt text is only a UI label;
- "LLM works" from parsing/model loading alone;
- "generation works" from one next-token ID without tokenizer/KV loop;
- "model agnostic" from one model-specific adapter;
- "faster" without measurements;
- "cooperative" when a heavy kernel can still monopolize a frame.

Use the evidence categories in `PZONNX_ACCEPTANCE.md`.

## Live Project Zomboid rule

Native evidence is mandatory for in-game claims but missing native evidence is not automatically permission to stop development.

Preserve open gates and continue when the next developer work can be safely isolated by adapters/reference fixtures.

## Git discipline

- inspect repository state before editing;
- preserve unrelated/user-authored work;
- do not reset/discard uncertain changes;
- keep coherent code/docs together when practical;
- do not publish to Steam Workshop;
- do not invent release claims.

## True blocker definition

A blocker must genuinely prevent safe developer-side progress, for example:

- a required supported PZ file/numeric capability is proven unavailable and no supported alternative exists;
- required model metadata cannot be inferred or overridden safely;
- a needed tokenizer/operator/datatype cannot be implemented within the runtime boundary and no approved compatible model path remains;
- repository/auth/user-conflict prevents safe work.

These are not blockers by themselves:

- one live test remains open;
- one model/export is unsupported;
- inference is initially slow;
- one optimization fails;
- a phase completes.

## Stop conditions

Stop only when:

1. a genuine blocker meets the definition above;
2. all mandatory P9+ developer-side work is implemented and only bounded user-owned native verification remains;
3. the complete parent goal has accepted evidence.

Do not revert to the superseded "P8 complete / READY FOR USER LIVE TEST" state while mandatory P9+ work remains.
