#!/usr/bin/env python3
"""Verify the P4 attention-style forward reference with ONNX Runtime."""

import json
from pathlib import Path

import numpy as np
import onnxruntime as ort


ROOT = Path(__file__).resolve().parents[1]
reference = json.loads((ROOT / "tools/p4_reference.json").read_text(encoding="utf-8"))
fixture = ROOT / "Contents/mods/PZONNX/42.20" / reference["fixture"]
session = ort.InferenceSession(str(fixture), providers=["CPUExecutionProvider"])
inputs = np.asarray(reference["input_values"], dtype=np.float32).reshape(reference["input_shape"])
actual = session.run([reference["output_name"]], {reference["input_name"]: inputs})[0]
expected = np.asarray(reference["expected_values"], dtype=np.float32).reshape(actual.shape)
maximum_error = float(np.max(np.abs(actual - expected)))
if maximum_error > reference["tolerance"]:
    raise SystemExit(f"P4 ONNX Runtime reference mismatch: error={maximum_error}")
print(f"P4 ONNX Runtime reference passed: output={actual.flatten().tolist()} max_error={maximum_error}")
