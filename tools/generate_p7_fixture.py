#!/usr/bin/env python3
"""Generate the bounded token-ID to numeric-audio TTS fixture."""

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
    raw = struct.pack("<" + "f" * len(values), *values)
    return field_bytes(1, dims) + field_varint(2, 1) + field_string(8, name) + field_bytes(9, raw)


def node(inputs, output, name, op_type) -> bytes:
    payload = b"".join(field_string(1, value) for value in inputs)
    return payload + field_string(2, output) + field_string(3, name) + field_string(4, op_type)


graph = b"".join([
    field_bytes(1, node(["embedding", "token_ids"], "hidden", "phoneme_embedding", "Gather")),
    field_bytes(1, node(["hidden", "decoder_weight"], "raw_audio", "audio_decoder", "MatMul")),
    field_bytes(1, node(["raw_audio", "decoder_bias"], "pcm", "audio_bias", "Add")),
    field_string(2, "pzonxx_p7_tiny_tts"),
    field_bytes(5, tensor("embedding", [2, 2], [0.0, 0.0, 0.0, 1.0])),
    field_bytes(5, tensor("decoder_weight", [2, 4], [0.2, 0.1, -0.1, 0.0, 0.5, -0.2, 0.3, 0.4])),
    field_bytes(5, tensor("decoder_bias", [4], [0.0, 0.05, 0.02, -0.1])),
    field_bytes(11, value_info("token_ids", [1], 7)),
    field_bytes(12, value_info("pcm", [1, 4], 1)),
])
model = b"".join([
    field_varint(1, 8),
    field_string(2, "PZONNX"),
    field_string(3, "0.1.0"),
    field_bytes(7, graph),
    field_bytes(8, field_varint(2, 13)),
])

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p7_tiny_tts.onnx"
REFERENCE = ROOT / "tools/p7_reference.json"
FIXTURE.parent.mkdir(parents=True, exist_ok=True)
FIXTURE.write_bytes(model)
REFERENCE.write_text(json.dumps({
    "fixture": "media/pzonnx/fixtures/p7_tiny_tts.onnx",
    "reference_runtime": "onnxruntime",
    "operator_inventory": ["Gather", "MatMul", "Add"],
    "input_name": "token_ids",
    "input_shape": [1],
    "input_values": [1],
    "output_name": "pcm",
    "expected_values": [0.5, -0.15, 0.32, 0.3],
    "tolerance": 1e-6,
}, indent=2) + "\n", encoding="utf-8")
print(f"wrote {FIXTURE} ({len(model)} bytes)")
print(f"wrote {REFERENCE}")
