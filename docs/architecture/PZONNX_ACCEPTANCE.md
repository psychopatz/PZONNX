# PZONNX Acceptance Model

## Purpose

PZONNX needs stronger evidence discipline than an ordinary Lua mod because it is attempting binary parsing, numerical execution, model compatibility, and eventually LLM/TTS inference inside Kahlua.

Acceptance is therefore split into evidence lanes. Missing evidence in one lane must remain visible, but it must not automatically stop unrelated developer-side work.

## Evidence lanes

### 1. Source acceptance

Proves that the implementation exists and its contracts are internally coherent.

Examples:

- module exists;
- API shape is correct;
- unsupported behavior fails explicitly;
- model metadata is represented without hidden native execution.

Source acceptance is necessary but never proves runtime behavior.

### 2. Host/reference acceptance

Uses development tooling outside Project Zomboid to produce trusted fixtures and expected outputs.

Examples:

- Python generates a real ONNX fixture;
- ONNX Runtime produces expected tensor outputs;
- protobuf/model metadata from PZONNX-oriented fixtures is independently inspected;
- static or host-compatible Lua tests exercise portable logic.

Host/reference acceptance may use Python, ONNX, ONNX Runtime, and model-export tooling because those are **development-only reference systems**, not game runtime dependencies.

### 3. Project Zomboid runtime acceptance

Proves that the code actually works through stock supported Project Zomboid Lua/Kahlua APIs.

Examples:

- packaged binary fixture opens through the selected PZ API;
- a real `.onnx` is parsed in-game;
- a tiny graph executes in-game;
- a transformer forward pass produces the expected result in-game.

Only this lane can justify claims such as "works in Project Zomboid."

### 4. Real-model acceptance

Proves that a non-toy target model works through PZONNX rather than merely parsing synthetic fixtures.

Examples:

- selected tiny transformer reaches reference-consistent logits;
- selected TTS model reaches reference-consistent PCM/numeric audio.

### 5. Adopter acceptance

Proves that another mod can consume PZONNX through its public API without copying or bypassing the runtime.

This belongs late in the roadmap.

## Non-blocking native evidence rule

Missing Project Zomboid runtime evidence is an **open acceptance gate**, not automatically a developer blocker.

If P0A has not been run live, the agent must:

1. keep P0A marked unverified;
2. avoid claiming that the packaged path works;
3. continue implementing P0B/P1/P2 developer-side components when they can be built safely from documented APIs and reference fixtures;
4. keep native probes ready so the open gates can be exercised later;
5. stop only if the next implementation decision truly depends on a runtime fact that cannot be safely isolated behind an adapter or fallback.

This rule exists to prevent the project from repeatedly stopping and asking the user to perform live tests after every phase.

## Native gate accumulation

It is acceptable for multiple native gates to remain open during development.

For example:

```text
P0A source + reference work complete
P0A native gate open

P0B source + reference work complete
P0B native gate open

P1 source + reference work complete
P1 native gate open
```

The parent goal remains IN PROGRESS.

Before final developer-side handoff, the agent should make every required native probe simple, bounded, and diagnostically useful. User-owned final live testing can then validate the accumulated native gates efficiently.

## Hard blocker definition

A native/runtime issue is a true blocker only when all of the following are true:

- the missing fact materially determines the next implementation;
- no safe adapter boundary, reference fixture, documented API contract, or conservative fallback can isolate it;
- proceeding would likely create invalid architecture or data corruption;
- the blocker is documented with the exact unanswered question and the smallest reproducer/probe needed to resolve it.

"Need user to launch PZ" by itself is not a blocker.

## Numerical acceptance

Every numerical proof needs:

- fixture/model identity;
- input values;
- trusted reference implementation;
- output values;
- declared tolerance;
- comparison result.

Do not loosen tolerances merely to make a test pass.

## Parent completion

PZONNX is not complete because:

- P0 passed;
- a real ONNX parsed;
- MatMul worked;
- one phase's tests passed;
- a model loaded;
- one token was produced without reference agreement.

Parent completion requires the approved mandatory roadmap to be completed and accepted, or a hard limitation to be proven and documented.
