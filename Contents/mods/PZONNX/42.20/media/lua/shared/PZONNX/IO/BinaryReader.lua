local BinaryReader = {}
BinaryReader.__index = BinaryReader

local MAX_EXACT_INTEGER = 9007199254740991 -- 2^53 - 1

local function streamAvailable(stream)
    if type(stream.available) ~= "function" then
        return nil
    end

    local ok, value = pcall(function()
        return stream:available()
    end)
    if ok and type(value) == "number" and value >= 0 then
        return value
    end
    return nil
end

function BinaryReader.new(stream, limit)
    assert(stream ~= nil, "PZONNX BinaryReader requires a stream")
    if limit ~= nil then
        assert(type(limit) == "number" and limit >= 0 and limit == math.floor(limit),
            "PZONNX BinaryReader limit must be a non-negative integer")
    end

    return setmetatable({
        stream = stream,
        offset = 0,
        limit = limit,
    }, BinaryReader)
end

function BinaryReader.fromBytes(bytes)
    assert(type(bytes) == "table", "PZONNX BinaryReader.fromBytes requires a byte table")

    local stream = {
        index = 0,
        bytes = bytes,
    }
    function stream:readUnsignedByte()
        self.index = self.index + 1
        local value = self.bytes[self.index]
        if value == nil then
            error("EOF")
        end
        return value
    end
    function stream:available()
        return #self.bytes - self.index
    end

    return BinaryReader.new(stream, #bytes)
end

function BinaryReader:tell()
    return self.offset
end

function BinaryReader:remaining()
    if self.limit ~= nil then
        return self.limit - self.offset
    end

    return streamAvailable(self.stream)
end

function BinaryReader:isAtEnd()
    local remaining = self:remaining()
    if remaining == nil then
        error("PZONNX reader requires a bounded stream or stream:available()")
    end
    return remaining == 0
end

function BinaryReader:withLimit(length, callback)
    assert(type(length) == "number" and length >= 0 and length == math.floor(length),
        "PZONNX reader section length must be a non-negative integer")
    assert(type(callback) == "function", "PZONNX reader section requires a callback")

    local remaining = self:remaining()
    if remaining ~= nil and length > remaining then
        error("PZONNX truncated section at byte offset " .. tostring(self.offset) ..
            ": declared=" .. tostring(length) .. " remaining=" .. tostring(remaining))
    end

    local previousLimit = self.limit
    local sectionEnd = self.offset + length
    self.limit = sectionEnd
    local ok, result = pcall(callback, self)
    local consumed = self.offset
    self.limit = previousLimit

    if not ok then
        error(result)
    end
    if previousLimit ~= nil and consumed > previousLimit then
        error("PZONNX reader section crossed its parent boundary at byte offset " .. tostring(consumed))
    end
    if consumed ~= sectionEnd then
        error("PZONNX section parser left " .. tostring(sectionEnd - consumed) ..
            " trailing bytes")
    end
    return result
end

function BinaryReader:readU8()
    if self.limit ~= nil and self.offset >= self.limit then
        error("PZONNX truncated binary input at byte offset " .. tostring(self.offset))
    end

    local ok, value = pcall(function()
        return self.stream:readUnsignedByte()
    end)
    if not ok then
        error("PZONNX binary read failed at byte offset " .. tostring(self.offset) .. ": " .. tostring(value))
    end
    if type(value) ~= "number" or value < 0 or value > 255 or value ~= math.floor(value) then
        error("PZONNX binary stream returned an invalid byte at offset " .. tostring(self.offset))
    end

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

function BinaryReader:readPackedString(count, chunkSize)
    assert(type(count) == "number" and count >= 0 and count == math.floor(count),
        "PZONNX readPackedString count must be a non-negative integer")
    chunkSize = chunkSize or 4096
    assert(chunkSize > 0 and chunkSize == math.floor(chunkSize),
        "PZONNX readPackedString chunk size must be a positive integer")

    local chunks = {}
    local remaining = count
    while remaining > 0 do
        local length = math.min(chunkSize, remaining)
        local chars = {}
        for i = 1, length do chars[i] = string.char(self:readU8()) end
        chunks[#chunks + 1] = table.concat(chars)
        remaining = remaining - length
    end
    return table.concat(chunks)
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

-- ONNX uses signed int64 for tensor dimensions and several attribute values.
-- Kahlua/Lua numbers are doubles, so decode the two's-complement payload with
-- 32-bit halves and reject values that cannot be represented exactly.
function BinaryReader:readInt64()
    local low = 0
    local high = 0

    for index = 1, 10 do
        local byte = self:readU8()
        local payload = byte % 128

        if index <= 4 then
            low = low + payload * (2 ^ ((index - 1) * 7))
        elseif index == 5 then
            low = low + (payload % 16) * 268435456 -- 2^28
            high = high + math.floor(payload / 16)
        elseif index <= 9 then
            high = high + payload * (2 ^ ((index - 1) * 7 - 32))
        else
            if payload > 1 then
                error("PZONNX signed int64 has an invalid tenth byte at byte offset " .. tostring(self.offset - 1))
            end
            high = high + payload * 2147483648 -- 2^31
        end

        if byte < 128 then
            local value
            if high >= 2147483648 then
                value = (high - 4294967296) * 4294967296 + low
            else
                value = high * 4294967296 + low
            end
            if math.abs(value) > MAX_EXACT_INTEGER then
                error("PZONNX signed int64 exceeds Lua's exact integer range at byte offset " .. tostring(self.offset - 1))
            end
            return value
        end
    end

    error("PZONNX malformed signed int64 exceeds 10 bytes near offset " .. tostring(self.offset))
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

function BinaryReader:readInt64LE()
    local low = self:readU8() + self:readU8() * 256 + self:readU8() * 65536 + self:readU8() * 16777216
    local high = self:readU8() + self:readU8() * 256 + self:readU8() * 65536 + self:readU8() * 16777216
    if high == 2147483647 and low == 4294967295 then
        return math.huge -- ONNX uses INT64_MAX as an open-ended Slice bound.
    end
    if high == 2147483648 and low == 0 then
        return -math.huge
    end
    local value
    if high >= 2147483648 then
        value = (high - 4294967296) * 4294967296 + low
    else
        value = high * 4294967296 + low
    end
    if math.abs(value) > MAX_EXACT_INTEGER then
        error("PZONNX little-endian int64 exceeds Lua's exact integer range at byte offset " .. tostring(self.offset - 8))
    end
    return value
end

return BinaryReader
