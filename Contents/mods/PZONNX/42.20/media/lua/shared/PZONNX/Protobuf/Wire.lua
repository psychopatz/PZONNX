local Wire = {}

Wire.VARINT = 0
Wire.FIXED64 = 1
Wire.LENGTH_DELIMITED = 2
Wire.START_GROUP = 3
Wire.END_GROUP = 4
Wire.FIXED32 = 5

function Wire.readTag(reader)
    local raw = reader:readVarint()
    local fieldNumber = math.floor(raw / 8)
    local wireType = raw % 8

    if fieldNumber <= 0 then
        error("PZONNX protobuf field number must be positive at byte offset " .. tostring(reader:tell()))
    end

    return fieldNumber, wireType, raw
end

function Wire.readLength(reader)
    local length = reader:readVarint()
    if length < 0 or length ~= math.floor(length) then
        error("PZONNX invalid protobuf length at byte offset " .. tostring(reader:tell()))
    end
    return length
end

function Wire.readLengthDelimitedBytes(reader)
    local length = Wire.readLength(reader)
    return reader:readBytes(length)
end

function Wire.readLengthDelimitedString(reader)
    local length = Wire.readLength(reader)
    return reader:readAscii(length)
end

function Wire.skipField(reader, wireType)
    if wireType == Wire.VARINT then
        reader:readVarint()
        return
    end

    if wireType == Wire.FIXED64 then
        reader:skip(8)
        return
    end

    if wireType == Wire.LENGTH_DELIMITED then
        reader:skip(Wire.readLength(reader))
        return
    end

    if wireType == Wire.FIXED32 then
        reader:skip(4)
        return
    end

    if wireType == Wire.START_GROUP or wireType == Wire.END_GROUP then
        error("PZONNX protobuf groups are not supported in the bootstrap decoder")
    end

    error("PZONNX unknown protobuf wire type " .. tostring(wireType))
end

return Wire
