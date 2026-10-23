local BinaryReader = {}
BinaryReader.__index = BinaryReader

local MAX_EXACT_INTEGER = 9007199254740991 -- 2^53 - 1

function BinaryReader.new(stream)
    assert(stream ~= nil, "PZONNX BinaryReader requires a stream")

    return setmetatable({
        stream = stream,
        offset = 0,
    }, BinaryReader)
end

function BinaryReader:tell()
    return self.offset
end

function BinaryReader:readU8()
    local value = self.stream:readUnsignedByte()
    self.offset = self.offset + 1
    return value
end

function BinaryReader:readBytes(count)
    assert(type(count) == "number" and count >= 0 and count == math.floor(count),
        "PZONNX readBytes count must be a non-negative integer")

    local out = {}
    for i = 1, count do
        out[i] = self:readU8()
    end
    return out
end

function BinaryReader:readAscii(count)
    local bytes = self:readBytes(count)
    local chars = {}
    for i = 1, #bytes do
        chars[i] = string.char(bytes[i])
    end
    return table.concat(chars)
end

function BinaryReader:skip(count)
    assert(type(count) == "number" and count >= 0 and count == math.floor(count),
        "PZONNX skip count must be a non-negative integer")

    -- Keep the bootstrap path deliberately portable: consume bytes through the
    -- same primitive rather than depending on an additional Java bridge method.
    for _ = 1, count do
        self:readU8()
    end
end

function BinaryReader:readVarint()
    local result = 0
    local multiplier = 1

    for _ = 1, 10 do
        local byte = self:readU8()
        local payload = byte % 128

        if payload ~= 0 and multiplier > (MAX_EXACT_INTEGER / payload) then
            error("PZONNX varint exceeds Lua's exact integer range at byte offset " .. tostring(self.offset - 1))
        end

        result = result + payload * multiplier

        if byte < 128 then
            return result
        end

        multiplier = multiplier * 128
    end

    error("PZONNX malformed varint exceeds 10 bytes near offset " .. tostring(self.offset))
end

function BinaryReader:readFixed32LE()
    local b0 = self:readU8()
    local b1 = self:readU8()
    local b2 = self:readU8()
    local b3 = self:readU8()

    return b0 + b1 * 256 + b2 * 65536 + b3 * 16777216
end

function BinaryReader:readFloat32LE()
    local bits = self:readFixed32LE()

    local sign = 1
    if bits >= 2147483648 then
        sign = -1
        bits = bits - 2147483648
    end

    local exponent = math.floor(bits / 8388608)
    local mantissa = bits % 8388608

    if exponent == 255 then
        if mantissa == 0 then
            return sign * math.huge
        end
        return 0 / 0
    end

    if exponent == 0 then
        if mantissa == 0 then
            return sign * 0
        end
        return sign * (mantissa / 8388608) * (2 ^ -126)
    end

    return sign * (1 + mantissa / 8388608) * (2 ^ (exponent - 127))
end

return BinaryReader
