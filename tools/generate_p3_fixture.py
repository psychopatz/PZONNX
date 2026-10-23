#!/usr/bin/env python3
"""Generate the P3 broadcast-add operator fixture."""

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


def value_info(name: str, shape) -> bytes:
    shape_message = b"".join(field_bytes(1, field_varint(1, dimension)) for dimension in shape)
    tensor_type = field_varint(1, 1) + field_bytes(2, shape_message)
    return field_string(1, name) + field_bytes(2, field_bytes(1, tensor_type))


def tensor(name: str, shape, values) -> bytes:
    dimensions = b"".join(varint(dimension) for dimension in shape)
    raw_data = struct.pack("<" + "f" * len(values), *values)
    return b"".join([
        field_bytes(1, dimensions),
        field_varint(2, 1),
        field_string(8, name),
        field_bytes(9, raw_data),
    ])


node = b"".join([
    field_string(1, "input"),
    field_string(1, "bias"),
    field_string(2, "output"),
    field_string(3, "broadcast_add"),
    field_string(4, "Add"),
])
graph = b"".join([
    field_bytes(1, node),
    field_string(2, "pzonxx_p3_broadcast_graph"),
    field_bytes(5, tensor("bias", [2], [0.5, -0.5])),
    field_bytes(11, value_info("input", [1, 2])),
    field_bytes(12, value_info("output", [1, 2])),
])
model = b"".join([
    field_varint(1, 8),
    field_string(2, "PZONNX"),
    field_string(3, "0.1.0"),
    field_bytes(7, graph),
    field_bytes(8, field_varint(2, 13)),
])

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p3_broadcast.onnx"
REFERENCE = ROOT / "tools/p3_reference.json"
FIXTURE.parent.mkdir(parents=True, exist_ok=True)
FIXTURE.write_bytes(model)
REFERENCE.write_text(json.dumps({
    "fixture": "media/pzonnx/fixtures/p3_broadcast.onnx",
    "reference_runtime": "onnxruntime",
    "input_name": "input",
    "input_shape": [1, 2],
    "input_values": [3.0, 4.0],
    "output_name": "output",
    "expected_values": [3.5, 3.5],
    "tolerance": 1e-6,
}, indent=2) + "\n", encoding="utf-8")
print(f"wrote {FIXTURE} ({len(model)} bytes)")
print(f"wrote {REFERENCE}")
