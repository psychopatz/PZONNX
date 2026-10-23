#!/usr/bin/env python3
"""Generate a bounded transformer-style attention projection fixture."""

import json
import math
import struct
from pathlib import Path


def varint(value: int) -> bytes:
    out = bytearray()
    while True:
        byte = value & 0x7F
        value >>= 7
        out.append(byte | 0x80 if value else byte)
        if not value:
            return bytes(out)


def field_varint(number: int, value: int) -> bytes:
    return varint(number << 3) + varint(value)


def field_bytes(number: int, value: bytes) -> bytes:
    return varint((number << 3) | 2) + varint(len(value)) + value


def field_string(number: int, value: str) -> bytes:
    return field_bytes(number, value.encode("utf-8"))


def value_info(name: str, shape) -> bytes:
    shape_message = b"".join(field_bytes(1, field_varint(1, d)) for d in shape)
    tensor_type = field_varint(1, 1) + field_bytes(2, shape_message)
    return field_string(1, name) + field_bytes(2, field_bytes(1, tensor_type))


def tensor(name: str, shape, values) -> bytes:
    dims = b"".join(varint(d) for d in shape)
    raw = struct.pack("<" + "f" * len(values), *values)
    return field_bytes(1, dims) + field_varint(2, 1) + field_string(8, name) + field_bytes(9, raw)


def node(inputs, output, name, op_type, attributes=b"") -> bytes:
    payload = b"".join(field_string(1, value) for value in inputs)
    payload += field_string(2, output) + field_string(3, name) + field_string(4, op_type)
    if attributes:
        payload += field_bytes(5, attributes)
    return payload


axis_attribute = field_string(1, "axis") + field_varint(3, 1) + field_varint(20, 2)
graph = b"".join([
    field_bytes(1, node(["hidden", "score_weight"], "scores", "score_projection", "MatMul")),
    field_bytes(1, node(["scores"], "probabilities", "attention_softmax", "Softmax", axis_attribute)),
    field_bytes(1, node(["probabilities", "value_weight"], "context", "value_projection", "MatMul")),
    field_bytes(1, node(["context", "bias"], "logits", "output_bias", "Add")),
    field_string(2, "pzonxx_p4_tiny_attention"),
    field_bytes(5, tensor("score_weight", [2, 2], [1.0, 0.0, 0.0, 1.0])),
    field_bytes(5, tensor("value_weight", [2, 2], [2.0, 1.0, 1.0, 2.0])),
    field_bytes(5, tensor("bias", [2], [0.1, -0.1])),
    field_bytes(11, value_info("hidden", [1, 2])),
    field_bytes(12, value_info("logits", [1, 2])),
])
model = b"".join([
    field_varint(1, 8),
    field_string(2, "PZONNX"),
    field_string(3, "0.1.0"),
    field_bytes(7, graph),
    field_bytes(8, field_varint(2, 13)),
])

probability = math.exp(1.0) / (math.exp(1.0) + math.exp(-1.0))
expected = [2.0 * probability + (1.0 - probability) + 0.1,
            probability + 2.0 * (1.0 - probability) - 0.1]

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p4_tiny_attention.onnx"
REFERENCE = ROOT / "tools/p4_reference.json"
FIXTURE.parent.mkdir(parents=True, exist_ok=True)
FIXTURE.write_bytes(model)
REFERENCE.write_text(json.dumps({
    "fixture": "media/pzonnx/fixtures/p4_tiny_attention.onnx",
    "reference_runtime": "onnxruntime",
    "operator_inventory": ["MatMul", "Softmax(axis=1)", "MatMul", "Add"],
    "input_name": "hidden",
    "input_shape": [1, 2],
    "input_values": [1.0, -1.0],
    "output_name": "logits",
    "expected_values": expected,
    "tolerance": 1e-6,
}, indent=2) + "\n", encoding="utf-8")
print(f"wrote {FIXTURE} ({len(model)} bytes)")
print(f"wrote {REFERENCE}")
