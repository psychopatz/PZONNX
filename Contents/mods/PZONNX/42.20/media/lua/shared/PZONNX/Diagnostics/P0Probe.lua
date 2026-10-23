local GameFile = require "PZONNX/IO/GameFile"
local Wire = require "PZONNX/Protobuf/Wire"
local Log = require "PZONNX/Diagnostics/Log"

local P0Probe = {}

P0Probe.FIXTURE_PATH = "media/pzonnx/fixtures/p0_probe.pb"

local function expect(actual, expected, label)
    if actual ~= expected then
        error(label .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
end

function P0Probe.run()
    local result = GameFile.withReader(P0Probe.FIXTURE_PATH, function(reader)
        local field1, wire1 = Wire.readTag(reader)
        expect(field1, 1, "field1 number")
        expect(wire1, Wire.VARINT, "field1 wire")
        expect(reader:readVarint(), 150, "field1 value")

        local field2, wire2 = Wire.readTag(reader)
        expect(field2, 2, "field2 number")
        expect(wire2, Wire.LENGTH_DELIMITED, "field2 wire")
        expect(Wire.readLengthDelimitedString(reader), "PZONNX", "field2 value")

        local field3, wire3 = Wire.readTag(reader)
        expect(field3, 3, "field3 number")
        expect(wire3, Wire.FIXED32, "field3 wire")
        expect(reader:readFloat32LE(), 1.0, "field3 value")

        return {
            bytesConsumed = reader:tell(),
            field1 = 150,
            field2 = "PZONNX",
            field3 = 1.0,
        }
    end)

    Log.info(
        "probe=P0A status=PASS path=" .. P0Probe.FIXTURE_PATH ..
        " bytes=" .. tostring(result.bytesConsumed) ..
        " varint=" .. tostring(result.field1) ..
        " text=" .. tostring(result.field2) ..
        " float32=" .. tostring(result.field3)
    )

    return result
end

return P0Probe
