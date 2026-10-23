#!/usr/bin/env python3
"""Independently inspect P0B/P1 ONNX ModelProto metadata.

The inspector intentionally uses a separate small protobuf reader rather than
importing PZONNX or the fixture generators. It is a development-time trusted
metadata lane, not a game-runtime dependency.
"""

import argparse
import json
from pathlib import Path


class Reader:
    def __init__(self, data: bytes):
        self.data = data
        self.offset = 0

    def varint(self) -> int:
        result = 0
        shift = 0
        for _ in range(10):
            if self.offset >= len(self.data):
                raise ValueError(f"truncated varint at offset {self.offset}")
            byte = self.data[self.offset]
            self.offset += 1
            result |= (byte & 0x7F) << shift
            if byte < 0x80:
                return result
            shift += 7
        raise ValueError(f"malformed varint near offset {self.offset}")

    def field(self):
        raw = self.varint()
        field_number, wire_type = raw >> 3, raw & 7
        if field_number <= 0:
            raise ValueError(f"invalid field number at offset {self.offset}")
        if wire_type == 0:
            return field_number, wire_type, self.varint(), None
        if wire_type == 1:
            start = self.offset
            return field_number, wire_type, self.take(8), start
        if wire_type == 2:
            length = self.varint()
            start = self.offset
            return field_number, wire_type, self.take(length), start
        if wire_type == 5:
            start = self.offset
            return field_number, wire_type, self.take(4), start
        raise ValueError(f"unsupported wire type {wire_type} at offset {self.offset}")

    def take(self, count: int) -> bytes:
        end = self.offset + count
        if end > len(self.data):
            raise ValueError(f"truncated length-delimited field at offset {self.offset}")
        result = self.data[self.offset:end]
        self.offset = end
        return result


def text(value: bytes) -> str:
    return value.decode("utf-8")


def parse_dimension(data: bytes):
    reader = Reader(data)
    result = {"value": None, "param": None}
    while reader.offset < len(reader.data):
        field, wire_type, value, _ = reader.field()
        if field == 1 and wire_type == 0:
            result["value"] = value
        elif field == 2 and wire_type == 2:
            result["param"] = text(value)
    return result


def parse_tensor_shape(data: bytes):
    reader = Reader(data)
    dims = []
    while reader.offset < len(reader.data):
        field, wire_type, value, _ = reader.field()
        if field == 1 and wire_type == 2:
            dims.append(parse_dimension(value))
    return dims


def parse_type(data: bytes):
    reader = Reader(data)
    result = {"kind": None, "elem_type": None, "dims": []}
    while reader.offset < len(reader.data):
        field, wire_type, value, _ = reader.field()
        if field == 1 and wire_type == 2:
            tensor_reader = Reader(value)
            result["kind"] = "tensor"
            while tensor_reader.offset < len(tensor_reader.data):
                tensor_field, tensor_wire, tensor_value, _ = tensor_reader.field()
                if tensor_field == 1 and tensor_wire == 0:
                    result["elem_type"] = tensor_value
                elif tensor_field == 2 and tensor_wire == 2:
                    result["dims"] = [
                        dim["value"] if dim["value"] is not None else dim["param"]
                        for dim in parse_tensor_shape(tensor_value)
                    ]
        elif field == 4 and wire_type == 2:
            result["kind"] = "sequence"
        elif field == 5 and wire_type == 2:
            result["kind"] = "map"
        elif field == 7 and wire_type == 2:
            result["kind"] = "opaque"
        elif field == 8 and wire_type == 2:
            result["kind"] = "sparse_tensor"
        elif field == 9 and wire_type == 2:
            result["kind"] = "optional"
    return result


def parse_value_info(data: bytes):
    reader = Reader(data)
    result = {"name": None, "kind": None, "elem_type": None, "dims": []}
    while reader.offset < len(reader.data):
        field, wire_type, value, _ = reader.field()
        if field == 1 and wire_type == 2:
            result["name"] = text(value)
        elif field == 2 and wire_type == 2:
            result.update(parse_type(value))
    return result


def parse_node(data: bytes):
    reader = Reader(data)
    result = {
        "inputs": [],
        "outputs": [],
        "name": "",
        "op_type": None,
        "domain": "",
        "attribute_count": 0,
        "attributes": [],
    }
    while reader.offset < len(reader.data):
        field, wire_type, value, _ = reader.field()
        if field == 1 and wire_type == 2:
            result["inputs"].append(text(value))
        elif field == 2 and wire_type == 2:
            result["outputs"].append(text(value))
        elif field == 3 and wire_type == 2:
            result["name"] = text(value)
        elif field == 4 and wire_type == 2:
            result["op_type"] = text(value)
        elif field == 5 and wire_type == 2:
            result["attribute_count"] += 1
            result["attributes"].append(parse_attribute(value))
        elif field == 7 and wire_type == 2:
            result["domain"] = text(value)
    return result


def parse_attribute(data: bytes):
    reader = Reader(data)
    result = {"name": None, "type": None, "payload_kind": None}
    while reader.offset < len(reader.data):
        field, wire_type, value, _ = reader.field()
        if field == 1 and wire_type == 2:
            result["name"] = text(value)
        elif field == 2 and wire_type == 5:
            result["payload_kind"] = "float"
        elif field == 3 and wire_type == 0:
            result["payload_kind"] = "int"
        elif field == 4 and wire_type == 2:
            result["payload_kind"] = "string"
        elif field == 5 and wire_type == 2:
            result["payload_kind"] = "tensor"
        elif field == 6 and wire_type == 2:
            result["payload_kind"] = "graph"
        elif field == 7 and wire_type in (2, 5):
            result["payload_kind"] = "floats"
        elif field == 8 and wire_type in (0, 2):
            result["payload_kind"] = "ints"
        elif field == 9 and wire_type == 2:
            result["payload_kind"] = "strings"
        elif field in (10, 11, 14, 15, 22, 23) and wire_type == 2:
            result["payload_kind"] = "complex"
        elif field == 20 and wire_type == 0:
            result["type"] = value
    return result


def parse_string_entry(data: bytes):
    reader = Reader(data)
    result = {"key": "", "value": ""}
    while reader.offset < len(reader.data):
        field, wire_type, value, _ = reader.field()
        if field == 1 and wire_type == 2:
            result["key"] = text(value)
        elif field == 2 and wire_type == 2:
            result["value"] = text(value)
    return result


def parse_tensor(data: bytes):
    reader = Reader(data)
    result = {
        "name": None,
        "dims": [],
        "data_type": None,
        "raw_data_relative_offset": None,
        "raw_data_length": 0,
        "data_location": 0,
        "external_data": [],
    }
    while reader.offset < len(reader.data):
        field, wire_type, value, value_offset = reader.field()
        if field == 1 and wire_type == 0:
            result["dims"].append(value)
        elif field == 1 and wire_type == 2:
            packed = Reader(value)
            while packed.offset < len(packed.data):
                result["dims"].append(packed.varint())
        elif field == 2 and wire_type == 0:
            result["data_type"] = value
        elif field == 8 and wire_type == 2:
            result["name"] = text(value)
        elif field == 9 and wire_type == 2:
            result["raw_data_relative_offset"] = value_offset
            result["raw_data_length"] = len(value)
        elif field == 13 and wire_type == 2:
            result["external_data"].append(parse_string_entry(value))
        elif field == 14 and wire_type == 0:
            result["data_location"] = value
    return result


def parse_graph(data: bytes, detailed: bool):
    reader = Reader(data)
    result = {"graph_name": None}
    if detailed:
        result.update({"nodes": [], "inputs": [], "outputs": [], "initializers": []})
    else:
        result.update({"node_count": 0, "input_count": 0, "output_count": 0})

    while reader.offset < len(reader.data):
        field, wire_type, value, _ = reader.field()
        if field == 1 and wire_type == 2:
            if detailed:
                result["nodes"].append(parse_node(value))
            else:
                result["node_count"] += 1
        elif field == 2 and wire_type == 2:
            result["graph_name"] = text(value)
        elif field == 5 and wire_type == 2 and detailed:
            result["initializers"].append(parse_tensor(value))
        elif field == 11 and wire_type == 2:
            if detailed:
                result["inputs"].append(parse_value_info(value))
            else:
                result["input_count"] += 1
        elif field == 12 and wire_type == 2:
            if detailed:
                result["outputs"].append(parse_value_info(value))
            else:
                result["output_count"] += 1
    return result


def parse_opset(data: bytes):
    reader = Reader(data)
    result = {"domain": "", "version": None}
    while reader.offset < len(reader.data):
        field, wire_type, value, _ = reader.field()
        if field == 1 and wire_type == 2:
            result["domain"] = text(value)
        elif field == 2 and wire_type == 0:
            result["version"] = value
    if result["version"] is None:
        raise ValueError("opset import is missing version")
    return result


def inspect(data: bytes, detailed: bool = False):
    reader = Reader(data)
    result = {
        "format": "onnx.ModelProto",
        "ir_version": None,
        "producer_name": None,
        "producer_version": None,
        "opset_imports": [],
    }
    while reader.offset < len(reader.data):
        field, wire_type, value, _ = reader.field()
        if field == 1 and wire_type == 0:
            result["ir_version"] = value
        elif field == 2 and wire_type == 2:
            result["producer_name"] = text(value)
        elif field == 3 and wire_type == 2:
            result["producer_version"] = text(value)
        elif field == 7 and wire_type == 2:
            result.update(parse_graph(value, detailed))
        elif field == 8 and wire_type == 2:
            result["opset_imports"].append(parse_opset(value))
    return result


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", type=Path, default=root /
                        "Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p0b_minimal.onnx")
    parser.add_argument("--reference", type=Path, default=Path(__file__).resolve().parent / "p0b_reference.json")
    parser.add_argument("--detailed", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    actual = inspect(args.fixture.read_bytes(), args.detailed)
    model_root = root / "Contents/mods/PZONNX/42.20"
    try:
        actual["fixture"] = args.fixture.resolve().relative_to(model_root).as_posix()
    except ValueError:
        actual["fixture"] = str(args.fixture)
    if args.check:
        expected = json.loads(args.reference.read_text(encoding="utf-8"))
        if actual != expected:
            raise SystemExit(f"P0B/P1 metadata mismatch:\nexpected={expected}\nactual={actual}")
    print(json.dumps(actual, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
