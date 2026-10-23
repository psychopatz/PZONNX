# PZONNX Agent Runbook

## Mission

Own the **complete approved PZONNX roadmap** as one autonomous implementation assignment.

The goal is not P0, not "parse ONNX," and not "make MatMul work." The goal is the full experimental runtime through the approved LLM/TTS and integration milestones, subject to proven technical limits.

A phase organizes work; it never redefines completion.

## Mandatory runtime boundary

Do not solve inference by adding:

- DLL/shared libraries;
- JNI;
- custom Java classes;
- Java patching/injection;
- Python at game runtime;
- external/localhost inference services;
- companion executables.

If a required capability appears impossible within this boundary, build the smallest reproducer/probe, verify the limitation as far as possible, and document it. Never quietly cross the boundary.

## Development tools

Outside-game tooling may:

- generate ONNX fixtures;
- export selected models;
- inspect protobuf/model metadata;
- run ONNX Runtime for trusted outputs;
- generate operator inventories;
- compare numerical outputs;
- benchmark reference behavior.

These are development/reference tools only.

## Required reading order

At the start of work:

1. `PZONNX_ARCHITECTURE.md`
2. `PZONNX_ROADMAP.md`
3. `PZONNX_ACCEPTANCE.md`
4. `PZONNX_PROGRESS.md`
5. current phase/subsystem document such as `P0_BINARY_PROTOBUF.md`
6. `GOAL_PROMPT.md`

Then inspect repository HEAD and the relevant implementation before editing.

## Autonomous execution loop

For each current Next Chunk:

1. audit existing code/evidence;
2. implement one coherent developer-side responsibility;
3. create/refresh focused fixtures and reference outputs;
4. run available validation;
5. add or update bounded in-game probes where required;
6. update PROGRESS with exact evidence status;
7. if the chunk is accepted, immediately continue to the next mandatory developer-implementable chunk;
8. do not wait for a new `/goal` merely because a phase completed.

## Live Project Zomboid rule

Native PZ evidence is mandatory for claims about in-game behavior, but missing native evidence is **not automatically permission to stop development**.

When a live PZ probe has not been run:

- mark the native gate OPEN / UNVERIFIED;
- never claim it passed;
- preserve the probe and expected evidence;
- continue implementation when the next work can be safely developed from documented APIs, isolated adapters, and reference fixtures;
- accumulate native gates for later bounded live verification.

Do not repeatedly tell the user to launch the game after every chunk.

Only stop on native evidence when the next implementation genuinely cannot be decided safely without it and no adapter/fallback can isolate the uncertainty.

## Evidence discipline

Never claim:

- "works in PZ" from host tests;
- "loads ONNX" from a hand-authored protobuf-only fixture;
- "supports an operator" from one happy-path shortcut;
- "LLM works" from model parsing or arbitrary text output;
- "TTS works" from creating a WAV container without reference-consistent numeric audio.

Use the categories in `PZONNX_ACCEPTANCE.md`.

## Numerical discipline

Correctness precedes optimization.

For every numerical fixture/model proof record:

- model/fixture identity;
- exact input;
- trusted reference;
- PZONNX output;
- declared tolerance;
- comparison result.

Do not loosen tolerance merely to pass.

## Memory discipline

Avoid full-model boxed-scalar expansion.

Prefer bounded/lazy initializer access, compact metadata, scratch-buffer reuse, bounded activations, and explicit cache limits. Preserve a clear correct path while optimizing.

## Performance discipline

Slow is not failure during early correctness phases.

Do not abandon a correct one-token transformer proof because it is slow. Measure it, preserve it, then optimize in the appropriate roadmap phase.

## Git discipline

- inspect repository state before editing;
- preserve unrelated/user-authored work;
- keep code and directly related docs together when practical;
- do not reset/discard uncertain work;
- do not publish to Steam Workshop;
- do not invent release claims;
- repository access does not authorize destructive unrelated changes.

## True blocker definition

A blocker is a condition that genuinely prevents further safe developer-side progress, such as:

- required supported PZ binary/numeric capability is proven unavailable with no safe alternative;
- the next architectural decision depends on a runtime fact that cannot be isolated and proceeding would likely be invalid;
- repository/auth state prevents required work;
- user-authored conflicts make edits unsafe;
- the selected target model is impossible under the hard boundary and no approved alternate target remains.

The following are **not** blockers by themselves:

- one phase completed;
- one test failed;
- a live PZ probe has not yet been run;
- one model/export is unsupported;
- initial inference is extremely slow;
- user live testing remains outstanding.

## Stop conditions

Stop only when one of these is true:

1. a genuine blocker meets the definition above;
2. the entire mandatory developer-side roadmap is complete and the project is **READY FOR USER LIVE TEST**;
3. the complete parent goal has accepted evidence and is truly complete.

Never stop simply after an audit, docs update, passing test, P0 completion, parser milestone, or single successful model operation.
