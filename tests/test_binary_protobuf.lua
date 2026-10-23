local BinaryReader = dofile("Contents/mods/PZONNX/42.20/media/lua/shared/PZONNX/IO/BinaryReader.lua")
local Wire = dofile("Contents/mods/PZONNX/42.20/media/lua/shared/PZONNX/Protobuf/Wire.lua")

local function fakeStream(bytes)
    return {
        index = 0,
        readUnsignedByte = function(self)
            self.index = self.index + 1
            local value = bytes[self.index]
            if value == nil then
                error("EOF")
            end
            return value
        end,
    }
end

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

do
    local reader = BinaryReader.new(fakeStream({ 0x96, 0x01 }))
    assertEqual(reader:readVarint(), 150, "varint 150")
    assertEqual(reader:tell(), 2, "varint offset")
end

do
    -- field 2, wire type 2
    local reader = BinaryReader.new(fakeStream({ 0x12 }))
    local fieldNumber, wireType = Wire.readTag(reader)
    assertEqual(fieldNumber, 2, "tag field")
    assertEqual(wireType, Wire.LENGTH_DELIMITED, "tag wire")
end

do
    local reader = BinaryReader.new(fakeStream({ 0x00, 0x00, 0x80, 0x3F }))
    assertEqual(reader:readFloat32LE(), 1.0, "float32 1.0")
end

do
    local reader = BinaryReader.new(fakeStream({ 0x03, 0x50, 0x5A, 0x4F }))
    assertEqual(Wire.readLengthDelimitedString(reader), "PZO", "length-delimited string")
end

print("PZONNX binary/protobuf smoke tests passed")
