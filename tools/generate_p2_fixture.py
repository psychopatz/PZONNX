#!/usr/bin/env python3
"""Generate the P2 MatMul -> Add ONNX fixture and reference contract."""

import json
import struct
from pathlib import Path


def varint(value: int) -> bytes:
    encoded = bytearray()
    while True:
        byte = value & 0x7F
        value >>= 7
        encoded.append(byte | 0x80 if value else byte)
        if not value:
            return bytes(encoded)


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


def build_model() -> bytes:
    matmul = b"".join([
        field_string(1, "input"),
        field_string(1, "weight"),
        field_string(2, "product"),
        field_string(3, "matmul_node"),
        field_string(4, "MatMul"),
    ])
    add = b"".join([
        field_string(1, "product"),
        field_string(1, "bias"),
        field_string(2, "output"),
        field_string(3, "add_node"),
        field_string(4, "Add"),
    ])
    graph = b"".join([
        field_bytes(1, matmul),
        field_bytes(1, add),
        field_string(2, "pzonxx_p2_linear_graph"),
        field_bytes(5, tensor("weight", [2, 1], [2.0, -1.0])),
        field_bytes(5, tensor("bias", [1, 1], [0.5])),
        field_bytes(11, value_info("input", [1, 2])),
        field_bytes(12, value_info("output", [1, 1])),
    ])
    return b"".join([
        field_varint(1, 8),
        field_string(2, "PZONNX"),
        field_string(3, "0.1.0"),
        field_bytes(7, graph),
        field_bytes(8, field_varint(2, 13)),
    ])


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p2_linear.onnx"
REFERENCE = ROOT / "tools/p2_reference.json"

data = build_model()
FIXTURE.parent.mkdir(parents=True, exist_ok=True)
FIXTURE.write_bytes(data)

reference = {
    "fixture": "media/pzonnx/fixtures/p2_linear.onnx",
    "reference_runtime": "onnxruntime",
    "input_name": "input",
    "input_shape": [1, 2],
    "input_values": [3.0, 4.0],
    "output_name": "output",
    "expected_values": [2.5],
    "tolerance": 1e-6,
}
REFERENCE.write_text(json.dumps(reference, indent=2) + "\n", encoding="utf-8")
print(f"wrote {FIXTURE} ({len(data)} bytes)")
print(f"wrote {REFERENCE}")
