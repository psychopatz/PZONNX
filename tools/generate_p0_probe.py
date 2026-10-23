#!/usr/bin/env python3
"""Regenerate the deterministic P0 protobuf binary probe.

This is development tooling only. PZONNX does not require Python at game runtime.
"""

from pathlib import Path

DATA = bytes([
    0x08, 0x96, 0x01,
    0x12, 0x06, 0x50, 0x5A, 0x4F, 0x4E, 0x4E, 0x58,
    0x1D, 0x00, 0x00, 0x80, 0x3F,
])

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p0_probe.pb"

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_bytes(DATA)

print(f"wrote {OUTPUT} ({len(DATA)} bytes)")
print(DATA.hex())
