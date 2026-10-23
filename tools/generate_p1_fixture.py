#!/usr/bin/env python3
"""Generate the P1 graph/index metadata fixture (development time only)."""

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


def string_entry(key: str, value: str) -> bytes:
    return field_string(1, key) + field_string(2, value)


def value_info(name: str) -> bytes:
    dim = field_varint(1, 1)
    shape = field_bytes(1, dim)
    tensor_type = field_varint(1, 1) + field_bytes(2, shape)
    return field_string(1, name) + field_bytes(2, field_bytes(1, tensor_type))


def build_model() -> bytes:
    node = b"".join([
        field_string(1, "input"),
        field_string(1, "weight"),
        field_string(2, "output"),
        field_string(3, "add_node"),
        field_string(4, "Add"),
    ])
    initializer = b"".join([
        field_bytes(1, varint(1)),  # packed dims = [1]
        field_varint(2, 1),         # TensorProto.FLOAT
        field_string(8, "weight"),
        field_bytes(9, struct.pack("<f", 0.5)),
    ])
    external_initializer = b"".join([
        field_bytes(1, varint(1)),
        field_varint(2, 1),
        field_string(8, "external_weight"),
        field_bytes(13, string_entry("location", "p1_external_weights.bin")),
        field_bytes(13, string_entry("offset", "0")),
        field_bytes(13, string_entry("length", "4")),
        field_varint(14, 1),
    ])
    graph = b"".join([
        field_bytes(1, node),
        field_string(2, "pzonxx_p1_graph"),
        field_bytes(5, initializer),
        field_bytes(5, external_initializer),
        field_bytes(11, value_info("input")),
        field_bytes(12, value_info("output")),
    ])
    opset_import = field_varint(2, 13)
    return b"".join([
        field_varint(1, 8),
        field_string(2, "PZONNX"),
        field_string(3, "0.1.0"),
        field_bytes(7, graph),
        field_bytes(8, opset_import),
    ])


def build_attribute_model() -> bytes:
    attribute = b"".join([
        field_string(1, "to"),
        field_varint(3, 1),
        field_varint(20, 2),  # AttributeProto.INT
    ])
    node = b"".join([
        field_string(1, "input"),
        field_string(2, "output"),
        field_string(3, "cast_node"),
        field_string(4, "Cast"),
        field_bytes(5, attribute),
    ])
    graph = b"".join([
        field_bytes(1, node),
        field_string(2, "pzonxx_p1_attribute_graph"),
        field_bytes(11, value_info("input")),
        field_bytes(12, value_info("output")),
    ])
    return b"".join([
        field_varint(1, 8),
        field_string(2, "PZONNX"),
        field_string(3, "0.1.0"),
        field_bytes(7, graph),
        field_bytes(8, field_varint(2, 13)),
    ])


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p1_metadata.onnx"
REFERENCE = ROOT / "tools/p1_reference.json"
ATTRIBUTE_FIXTURE = ROOT / "Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p1_attribute.onnx"
ATTRIBUTE_REFERENCE = ROOT / "tools/p1_attribute_reference.json"
EXTERNAL_WEIGHTS = FIXTURE.parent / "p1_external_weights.bin"

data = build_model()
attribute_data = build_attribute_model()
FIXTURE.parent.mkdir(parents=True, exist_ok=True)
FIXTURE.write_bytes(data)
ATTRIBUTE_FIXTURE.write_bytes(attribute_data)
EXTERNAL_WEIGHTS.write_bytes(struct.pack("<f", 0.25))

reference = {
    "fixture": "media/pzonnx/fixtures/p1_metadata.onnx",
    "format": "onnx.ModelProto",
    "ir_version": 8,
    "producer_name": "PZONNX",
    "producer_version": "0.1.0",
    "opset_imports": [{"domain": "", "version": 13}],
    "graph_name": "pzonxx_p1_graph",
    "nodes": [{
        "inputs": ["input", "weight"],
        "outputs": ["output"],
        "name": "add_node",
        "op_type": "Add",
        "domain": "",
        "attribute_count": 0,
        "attributes": [],
    }],
    "inputs": [{"name": "input", "kind": "tensor", "elem_type": 1, "dims": [1]}],
    "outputs": [{"name": "output", "kind": "tensor", "elem_type": 1, "dims": [1]}],
    "initializers": [{
        "name": "weight",
        "dims": [1],
        "data_type": 1,
        "raw_data_relative_offset": 15,
        "raw_data_length": 4,
        "data_location": 0,
        "external_data": [],
    }, {
        "name": "external_weight",
        "dims": [1],
        "data_type": 1,
        "raw_data_relative_offset": None,
        "raw_data_length": 0,
        "data_location": 1,
        "external_data": [
            {"key": "location", "value": "p1_external_weights.bin"},
            {"key": "offset", "value": "0"},
            {"key": "length", "value": "4"},
        ],
    }],
}
REFERENCE.write_text(json.dumps(reference, indent=2) + "\n", encoding="utf-8")
attribute_reference = {
    "fixture": "media/pzonnx/fixtures/p1_attribute.onnx",
    "format": "onnx.ModelProto",
    "ir_version": 8,
    "producer_name": "PZONNX",
    "producer_version": "0.1.0",
    "opset_imports": [{"domain": "", "version": 13}],
    "graph_name": "pzonxx_p1_attribute_graph",
    "nodes": [{
        "inputs": ["input"],
        "outputs": ["output"],
        "name": "cast_node",
        "op_type": "Cast",
        "domain": "",
        "attribute_count": 1,
        "attributes": [{"name": "to", "type": 2, "payload_kind": "int"}],
    }],
    "inputs": [{"name": "input", "kind": "tensor", "elem_type": 1, "dims": [1]}],
    "outputs": [{"name": "output", "kind": "tensor", "elem_type": 1, "dims": [1]}],
    "initializers": [],
}
ATTRIBUTE_REFERENCE.write_text(json.dumps(attribute_reference, indent=2) + "\n", encoding="utf-8")
print(f"wrote {FIXTURE} ({len(data)} bytes)")
print(f"wrote {ATTRIBUTE_FIXTURE} ({len(attribute_data)} bytes)")
print(f"wrote {EXTERNAL_WEIGHTS} (4 bytes)")
print(f"wrote {REFERENCE}")
