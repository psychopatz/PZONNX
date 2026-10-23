#!/usr/bin/env python3
"""Verify the P7 numeric-audio reference with development-time ONNX Runtime."""

import json
from pathlib import Path

import numpy as np
import onnxruntime as ort


ROOT = Path(__file__).resolve().parents[1]
reference = json.loads((ROOT / "tools/p7_reference.json").read_text(encoding="utf-8"))
fixture = ROOT / "Contents/mods/PZONNX/42.20" / reference["fixture"]
session = ort.InferenceSession(str(fixture), providers=["CPUExecutionProvider"])
inputs = np.asarray(reference["input_values"], dtype=np.int64).reshape(reference["input_shape"])
actual = session.run([reference["output_name"]], {reference["input_name"]: inputs})[0].reshape(-1)
expected = np.asarray(reference["expected_values"], dtype=np.float32)
maximum_error = float(np.max(np.abs(actual - expected)))
if maximum_error > reference["tolerance"]:
    raise SystemExit(f"P7 reference mismatch: output={actual.tolist()} error={maximum_error}")
print(f"P7 ONNX Runtime reference passed: pcm={actual.tolist()} max_error={maximum_error}")
