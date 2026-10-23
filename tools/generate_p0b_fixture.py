#!/usr/bin/env python3
"""Generate the genuine minimal ONNX ModelProto used by the P0B probe.

This is development tooling only. The game receives the generated .onnx bytes;
Python is not a runtime dependency of PZONNX.
"""

import json
from pathlib import Path


def varint(value: int) -> bytes:
    if value < 0:
        raise ValueError("P0B generator only encodes non-negative integers")
    encoded = bytearray()
    while True:
        byte = value & 0x7F
        value >>= 7
        if value:
            encoded.append(byte | 0x80)
        else:
            encoded.append(byte)
            return bytes(encoded)


def field_varint(number: int, value: int) -> bytes:
    return varint(number << 3) + varint(value)


def field_bytes(number: int, value: bytes) -> bytes:
    return varint((number << 3) | 2) + varint(len(value)) + value


def field_string(number: int, value: str) -> bytes:
    return field_bytes(number, value.encode("utf-8"))


def message(*fields: bytes) -> bytes:
    return b"".join(fields)


def value_info(name: str) -> bytes:
    # TypeProto.tensor_type.elem_type = FLOAT (1), shape = [1].
    dim = field_varint(1, 1)
    shape = field_bytes(1, dim)
    tensor_type = field_varint(1, 1) + field_bytes(2, shape)
    type_proto = field_bytes(1, tensor_type)
    return field_string(1, name) + field_bytes(2, type_proto)


def build_model() -> bytes:
    node = message(
        field_string(1, "input"),
        field_string(2, "output"),
        field_string(3, "identity_node"),
        field_string(4, "Identity"),
    )
    graph = message(
        field_bytes(1, node),
        field_string(2, "pzonxx_p0b_graph"),
        field_bytes(11, value_info("input")),
        field_bytes(12, value_info("output")),
    )
    opset_import = field_varint(2, 13)  # empty domain is the default ONNX domain
    return message(
        field_varint(1, 8),
        field_string(2, "PZONNX"),
        field_string(3, "0.1.0"),
        field_bytes(7, graph),
        field_bytes(8, opset_import),
    )


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p0b_minimal.onnx"
REFERENCE = ROOT / "tools/p0b_reference.json"

FIXTURE.parent.mkdir(parents=True, exist_ok=True)
FIXTURE.write_bytes(build_model())

reference = {
    "fixture": "media/pzonnx/fixtures/p0b_minimal.onnx",
    "format": "onnx.ModelProto",
    "ir_version": 8,
    "producer_name": "PZONNX",
    "producer_version": "0.1.0",
    "opset_imports": [{"domain": "", "version": 13}],
    "graph_name": "pzonxx_p0b_graph",
    "node_count": 1,
    "input_count": 1,
    "output_count": 1,
}
REFERENCE.write_text(json.dumps(reference, indent=2) + "\n", encoding="utf-8")

print(f"wrote {FIXTURE} ({len(build_model())} bytes)")
print(f"wrote {REFERENCE}")
