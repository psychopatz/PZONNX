#!/usr/bin/env python3
"""Verify the P5 one-token logits with development-time ONNX Runtime."""

import json
from pathlib import Path

import numpy as np
import onnxruntime as ort


ROOT = Path(__file__).resolve().parents[1]
reference = json.loads((ROOT / "tools/p5_reference.json").read_text(encoding="utf-8"))
fixture = ROOT / "Contents/mods/PZONNX/42.20" / reference["fixture"]
session = ort.InferenceSession(str(fixture), providers=["CPUExecutionProvider"])
inputs = np.asarray(reference["input_values"], dtype=np.int64).reshape(reference["input_shape"])
actual = session.run([reference["output_name"]], {reference["input_name"]: inputs})[0].reshape(-1)
expected = np.asarray(reference["expected_values"], dtype=np.float32)
maximum_error = float(np.max(np.abs(actual - expected)))
token_id = int(np.argmax(actual))
if maximum_error > reference["tolerance"] or token_id != reference["expected_token_id"]:
    raise SystemExit(f"P5 reference mismatch: output={actual.tolist()} error={maximum_error} token={token_id}")
print(f"P5 ONNX Runtime reference passed: logits={actual.tolist()} token={token_id} max_error={maximum_error}")
