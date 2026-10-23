#!/usr/bin/env python3
"""Generate the bounded one-token tiny language-model fixture."""

import json
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


def value_info(name: str, shape, elem_type: int) -> bytes:
    shape_message = b"".join(field_bytes(1, field_varint(1, dimension)) for dimension in shape)
    tensor_type = field_varint(1, elem_type) + field_bytes(2, shape_message)
    return field_string(1, name) + field_bytes(2, field_bytes(1, tensor_type))


def tensor(name: str, shape, values) -> bytes:
    dims = b"".join(varint(dimension) for dimension in shape)
    raw_data = struct.pack("<" + "f" * len(values), *values)
    return field_bytes(1, dims) + field_varint(2, 1) + field_string(8, name) + field_bytes(9, raw_data)


axis_attribute = field_string(1, "axis") + field_varint(3, 0) + field_varint(20, 2)
gather = b"".join([
    field_string(1, "embedding"),
    field_string(1, "token_ids"),
    field_string(2, "hidden"),
    field_string(3, "embedding_lookup"),
    field_string(4, "Gather"),
    field_bytes(5, axis_attribute),
])
matmul = b"".join([
    field_string(1, "hidden"),
    field_string(1, "lm_head"),
    field_string(2, "raw_logits"),
    field_string(3, "language_head"),
    field_string(4, "MatMul"),
])
add = b"".join([
    field_string(1, "raw_logits"),
    field_string(1, "lm_bias"),
    field_string(2, "logits"),
    field_string(3, "logit_bias"),
    field_string(4, "Add"),
])
graph = b"".join([
    field_bytes(1, gather),
    field_bytes(1, matmul),
    field_bytes(1, add),
    field_string(2, "pzonxx_p5_tiny_lm"),
    field_bytes(5, tensor("embedding", [3, 2], [0.0, 0.0, 0.0, 1.0, 1.0, 1.0])),
    field_bytes(5, tensor("lm_head", [2, 3], [0.2, -0.1, 0.3, 0.5, 0.4, -0.1])),
    field_bytes(5, tensor("lm_bias", [3], [0.1, 0.0, 0.0])),
    field_bytes(11, value_info("token_ids", [1], 7)),
    field_bytes(12, value_info("logits", [1, 3], 1)),
])
model = b"".join([
    field_varint(1, 8),
    field_string(2, "PZONNX"),
    field_string(3, "0.1.0"),
    field_bytes(7, graph),
    field_bytes(8, field_varint(2, 13)),
])

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p5_tiny_lm.onnx"
REFERENCE = ROOT / "tools/p5_reference.json"
FIXTURE.parent.mkdir(parents=True, exist_ok=True)
FIXTURE.write_bytes(model)
REFERENCE.write_text(json.dumps({
    "fixture": "media/pzonnx/fixtures/p5_tiny_lm.onnx",
    "reference_runtime": "onnxruntime",
    "operator_inventory": ["Gather(axis=0)", "MatMul", "Add"],
    "vocab_size": 3,
    "hidden_size": 2,
    "input_name": "token_ids",
    "input_shape": [1],
    "input_values": [1],
    "output_name": "logits",
    "expected_values": [0.6, 0.4, -0.1],
    "expected_token_id": 0,
    "tolerance": 1e-6,
}, indent=2) + "\n", encoding="utf-8")
print(f"wrote {FIXTURE} ({len(model)} bytes)")
print(f"wrote {REFERENCE}")
