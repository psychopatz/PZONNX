local BinaryReader = require "PZONNX/IO/BinaryReader"
local GameFile = require "PZONNX/IO/GameFile"
local Wire = require "PZONNX/Protobuf/Wire"
local OperatorRegistry = require "PZONNX/Runtime/OperatorRegistry"

local Model = {}

local function requireWireType(fieldName, actual, expected)
    if actual ~= expected then
        error("PZONNX ONNX " .. fieldName .. " has wire type " .. tostring(actual) ..
            ", expected " .. tostring(expected))
    end
end

local function readNested(reader, label, parse)
    local length = Wire.readLength(reader)
    return reader:withLimit(length, parse)
end

local function parseOperatorSetId(reader)
    local result = {
        domain = "",
        version = nil,
    }

    while not reader:isAtEnd() do
        local field, wireType = Wire.readTag(reader)
        if field == 1 then
            requireWireType("OperatorSetIdProto.domain", wireType, Wire.LENGTH_DELIMITED)
            result.domain = Wire.readLengthDelimitedString(reader)
        elseif field == 2 then
            requireWireType("OperatorSetIdProto.version", wireType, Wire.VARINT)
            result.version = reader:readVarint()
        else
            Wire.skipField(reader, wireType)
        end
    end

    if result.version == nil then
        error("PZONNX ONNX OperatorSetIdProto is missing version")
    end
    return result
end

local function readPackedInt64(reader, target)
    local length = Wire.readLength(reader)
    reader:withLimit(length, function(section)
        while not section:isAtEnd() do
            table.insert(target, section:readInt64())
        end
    end)
end

local function parseDimension(reader)
    local result = {
        value = nil,
        param = nil,
    }

    while not reader:isAtEnd() do
        local field, wireType = Wire.readTag(reader)
        if field == 1 then
            requireWireType("TensorShapeProto.Dimension.dim_value", wireType, Wire.VARINT)
            result.value = reader:readInt64()
        elseif field == 2 then
            requireWireType("TensorShapeProto.Dimension.dim_param", wireType, Wire.LENGTH_DELIMITED)
            result.param = Wire.readLengthDelimitedString(reader)
        else
            Wire.skipField(reader, wireType)
        end
    end

    return result
end

local function parseTensorShape(reader)
    local result = {
        dims = {},
    }

    while not reader:isAtEnd() do
        local field, wireType = Wire.readTag(reader)
        if field == 1 then
            requireWireType("TensorShapeProto.dim", wireType, Wire.LENGTH_DELIMITED)
            table.insert(result.dims, readNested(reader, "TensorShapeProto.Dimension", parseDimension))
        else
            Wire.skipField(reader, wireType)
        end
    end

    return result
end

local function parseTensorType(reader)
    local result = {
        elemType = nil,
        shape = nil,
    }

    while not reader:isAtEnd() do
        local field, wireType = Wire.readTag(reader)
        if field == 1 then
            requireWireType("TypeProto.Tensor.elem_type", wireType, Wire.VARINT)
            result.elemType = reader:readVarint()
        elseif field == 2 then
            requireWireType("TypeProto.Tensor.shape", wireType, Wire.LENGTH_DELIMITED)
            result.shape = readNested(reader, "TensorShapeProto", parseTensorShape)
        else
            Wire.skipField(reader, wireType)
        end
    end

    if result.elemType == nil then
        error("PZONNX ONNX TypeProto.Tensor is missing elem_type")
    end
    return result
end

local function parseTypeProto(reader)
    local result = {
        kind = nil,
        tensor = nil,
    }

    while not reader:isAtEnd() do
        local field, wireType = Wire.readTag(reader)
        if field == 1 then
            requireWireType("TypeProto.tensor_type", wireType, Wire.LENGTH_DELIMITED)
            result.kind = "tensor"
            result.tensor = readNested(reader, "TypeProto.Tensor", parseTensorType)
        elseif field == 4 then
            requireWireType("TypeProto.sequence_type", wireType, Wire.LENGTH_DELIMITED)
            result.kind = "sequence"
            Wire.skipField(reader, wireType)
        elseif field == 5 then
            requireWireType("TypeProto.map_type", wireType, Wire.LENGTH_DELIMITED)
            result.kind = "map"
            Wire.skipField(reader, wireType)
        elseif field == 7 then
            requireWireType("TypeProto.opaque_type", wireType, Wire.LENGTH_DELIMITED)
            result.kind = "opaque"
            Wire.skipField(reader, wireType)
        elseif field == 8 then
            requireWireType("TypeProto.sparse_tensor_type", wireType, Wire.LENGTH_DELIMITED)
            result.kind = "sparse_tensor"
            Wire.skipField(reader, wireType)
        elseif field == 9 then
            requireWireType("TypeProto.optional_type", wireType, Wire.LENGTH_DELIMITED)
            result.kind = "optional"
            Wire.skipField(reader, wireType)
        else
            Wire.skipField(reader, wireType)
        end
    end

    if result.kind == nil then
        error("PZONNX ONNX TypeProto is missing a supported type discriminator")
    end
    return result
end

local function parseValueInfo(reader)
    local result = {
        name = nil,
        type = nil,
    }

    while not reader:isAtEnd() do
        local field, wireType = Wire.readTag(reader)
        if field == 1 then
            requireWireType("ValueInfoProto.name", wireType, Wire.LENGTH_DELIMITED)
            result.name = Wire.readLengthDelimitedString(reader)
        elseif field == 2 then
            requireWireType("ValueInfoProto.type", wireType, Wire.LENGTH_DELIMITED)
            result.type = readNested(reader, "TypeProto", parseTypeProto)
        else
            Wire.skipField(reader, wireType)
        end
    end

    if result.name == nil or result.name == "" then
        error("PZONNX ONNX ValueInfoProto is missing name")
    end
    if result.type == nil then
        error("PZONNX ONNX ValueInfoProto is missing type")
    end
    return result
end

local function parseStringEntry(reader)
    local result = {
        key = nil,
        value = nil,
    }

    while not reader:isAtEnd() do
        local field, wireType = Wire.readTag(reader)
        if field == 1 then
            requireWireType("StringStringEntryProto.key", wireType, Wire.LENGTH_DELIMITED)
            result.key = Wire.readLengthDelimitedString(reader)
        elseif field == 2 then
            requireWireType("StringStringEntryProto.value", wireType, Wire.LENGTH_DELIMITED)
            result.value = Wire.readLengthDelimitedString(reader)
        else
            Wire.skipField(reader, wireType)
        end
    end
    return result
end

local parseTensor
local readPackedFixed32

local function parseAttribute(reader)
    local result = {
        name = nil,
        type = nil,
        payloadKind = nil,
        payloadLength = 0,
        value = nil,
        values = {},
    }

    while not reader:isAtEnd() do
        local field, wireType = Wire.readTag(reader)
        if field == 1 then
            requireWireType("AttributeProto.name", wireType, Wire.LENGTH_DELIMITED)
            result.name = Wire.readLengthDelimitedString(reader)
        elseif field == 2 then
            requireWireType("AttributeProto.f", wireType, Wire.FIXED32)
            reader:skip(4)
            result.payloadKind = "float"
            result.payloadLength = 4
        elseif field == 3 then
            requireWireType("AttributeProto.i", wireType, Wire.VARINT)
            result.value = reader:readInt64()
            result.payloadKind = "int"
            result.payloadLength = 1
        elseif field == 4 then
            requireWireType("AttributeProto.s", wireType, Wire.LENGTH_DELIMITED)
            result.payloadLength = Wire.readLength(reader)
            reader:skip(result.payloadLength)
            result.payloadKind = "string"
        elseif field == 5 then
            requireWireType("AttributeProto.t", wireType, Wire.LENGTH_DELIMITED)
            result.tensor = readNested(reader, "TensorProto", function(section)
                return parseTensor(section, true)
            end)
            result.payloadKind = "tensor"
        elseif field == 6 then
            requireWireType("AttributeProto.g", wireType, Wire.LENGTH_DELIMITED)
            result.payloadLength = Wire.readLength(reader)
            reader:skip(result.payloadLength)
            result.payloadKind = "graph"
        elseif field == 7 or field == 8 then
            if field == 7 and wireType == Wire.FIXED32 then
                table.insert(result.values, reader:readFloat32LE())
            elseif field == 7 and wireType == Wire.LENGTH_DELIMITED then
                readPackedFixed32(reader, result.values)
            elseif field == 8 and wireType == Wire.VARINT then
                table.insert(result.values, reader:readInt64())
            elseif field == 8 and wireType == Wire.LENGTH_DELIMITED then
                readPackedInt64(reader, result.values)
            else
                error("PZONNX ONNX AttributeProto list has unsupported wire type " .. tostring(wireType))
            end
            result.payloadKind = field == 7 and "floats" or "ints"
        elseif field == 9 then
            requireWireType("AttributeProto.strings", wireType, Wire.LENGTH_DELIMITED)
            table.insert(result.values, Wire.readLengthDelimitedString(reader))
            result.payloadKind = "strings"
        elseif field == 10 or field == 11 or field == 14 or field == 15 or field == 22 or field == 23 then
            requireWireType("AttributeProto.complex_payload", wireType, Wire.LENGTH_DELIMITED)
            result.payloadLength = Wire.readLength(reader)
            reader:skip(result.payloadLength)
            result.payloadKind = "complex"
        elseif field == 13 then
            requireWireType("AttributeProto.doc_string", wireType, Wire.LENGTH_DELIMITED)
            Wire.readLengthDelimitedString(reader)
        elseif field == 20 then
            requireWireType("AttributeProto.type", wireType, Wire.VARINT)
            result.type = reader:readVarint()
        elseif field == 21 then
            requireWireType("AttributeProto.ref_attr_name", wireType, Wire.LENGTH_DELIMITED)
            Wire.readLengthDelimitedString(reader)
        else
            Wire.skipField(reader, wireType)
        end
    end

    if result.name == nil or result.name == "" then
        error("PZONNX ONNX AttributeProto is missing name")
    end
    return result
end

readPackedFixed32 = function(reader, target)
    local length = Wire.readLength(reader)
    reader:withLimit(length, function(section)
        while not section:isAtEnd() do
            table.insert(target, section:readFloat32LE())
        end
    end)
end

parseTensor = function(reader, captureValues)
    local result = {
        dims = {},
        dataType = nil,
        name = nil,
        dataLocation = 0,
        rawData = nil,
        externalData = {},
        sourceOffset = reader:tell(),
        values = {},
        rawDataBytes = nil,
    }

    while not reader:isAtEnd() do
        local field, wireType = Wire.readTag(reader)
        if field == 1 then
            if wireType == Wire.VARINT then
                table.insert(result.dims, reader:readInt64())
            elseif wireType == Wire.LENGTH_DELIMITED then
                readPackedInt64(reader, result.dims)
            else
                error("PZONNX ONNX TensorProto.dims has unsupported wire type " .. tostring(wireType))
            end
        elseif field == 2 then
            requireWireType("TensorProto.data_type", wireType, Wire.VARINT)
            result.dataType = reader:readVarint()
        elseif field == 4 then
            if wireType == Wire.FIXED32 then
                table.insert(result.values, reader:readFloat32LE())
            elseif wireType == Wire.LENGTH_DELIMITED then
                readPackedFixed32(reader, result.values)
            else
                error("PZONNX ONNX TensorProto.float_data has unsupported wire type " .. tostring(wireType))
            end
        elseif field == 5 then
            if wireType == Wire.VARINT then
                table.insert(result.values, reader:readInt64())
            elseif wireType == Wire.LENGTH_DELIMITED then
                readPackedInt64(reader, result.values)
            else
                error("PZONNX ONNX TensorProto.int32_data has unsupported wire type " .. tostring(wireType))
            end
        elseif field == 6 then
            if wireType == Wire.LENGTH_DELIMITED then
                table.insert(result.values, Wire.readLengthDelimitedString(reader))
            else
                error("PZONNX ONNX TensorProto.string_data has unsupported wire type " .. tostring(wireType))
            end
        elseif field == 7 then
            if wireType == Wire.VARINT then
                table.insert(result.values, reader:readInt64())
            elseif wireType == Wire.LENGTH_DELIMITED then
                readPackedInt64(reader, result.values)
            else
                error("PZONNX ONNX TensorProto.int64_data has unsupported wire type " .. tostring(wireType))
            end
        elseif field == 8 then
            requireWireType("TensorProto.name", wireType, Wire.LENGTH_DELIMITED)
            result.name = Wire.readLengthDelimitedString(reader)
        elseif field == 9 then
            requireWireType("TensorProto.raw_data", wireType, Wire.LENGTH_DELIMITED)
            local length = Wire.readLength(reader)
            local offset = reader:tell()
            if captureValues then
                result.rawDataBytes = reader:readBytes(length)
            else
                reader:skip(length)
            end
            result.rawData = {
                offset = offset,
                relativeOffset = offset - result.sourceOffset,
                length = length,
            }
        elseif field == 13 then
            requireWireType("TensorProto.external_data", wireType, Wire.LENGTH_DELIMITED)
            table.insert(result.externalData,
                readNested(reader, "StringStringEntryProto", parseStringEntry))
        elseif field == 14 then
            requireWireType("TensorProto.data_location", wireType, Wire.VARINT)
            result.dataLocation = reader:readVarint()
        elseif field == 10 then
            if captureValues then
                error("PZONNX ONNX TensorProto.double_data is not supported for captured constants")
            end
            Wire.skipField(reader, wireType)
        else
            Wire.skipField(reader, wireType)
        end
    end

    if not captureValues and (result.name == nil or result.name == "") then
        error("PZONNX ONNX TensorProto initializer is missing name")
    end
    if result.dataType == nil then
        error("PZONNX ONNX TensorProto initializer is missing data_type")
    end
    return result
end

local function parseNode(reader)
    local result = {
        inputs = {},
        outputs = {},
        name = "",
        opType = nil,
        domain = "",
        attributes = {},
        attributeCount = 0,
    }

    while not reader:isAtEnd() do
        local field, wireType = Wire.readTag(reader)
        if field == 1 then
            requireWireType("NodeProto.input", wireType, Wire.LENGTH_DELIMITED)
            table.insert(result.inputs, Wire.readLengthDelimitedString(reader))
        elseif field == 2 then
            requireWireType("NodeProto.output", wireType, Wire.LENGTH_DELIMITED)
            table.insert(result.outputs, Wire.readLengthDelimitedString(reader))
        elseif field == 3 then
            requireWireType("NodeProto.name", wireType, Wire.LENGTH_DELIMITED)
            result.name = Wire.readLengthDelimitedString(reader)
        elseif field == 4 then
            requireWireType("NodeProto.op_type", wireType, Wire.LENGTH_DELIMITED)
            result.opType = Wire.readLengthDelimitedString(reader)
        elseif field == 5 then
            requireWireType("NodeProto.attribute", wireType, Wire.LENGTH_DELIMITED)
            table.insert(result.attributes, readNested(reader, "AttributeProto", parseAttribute))
            result.attributeCount = result.attributeCount + 1
        elseif field == 7 then
            requireWireType("NodeProto.domain", wireType, Wire.LENGTH_DELIMITED)
            result.domain = Wire.readLengthDelimitedString(reader)
        else
            Wire.skipField(reader, wireType)
        end
    end

    if result.opType == nil or result.opType == "" then
        error("PZONNX ONNX NodeProto is missing op_type")
    end
    return result
end

local function parseGraph(reader)
    local result = {
        name = nil,
        nodes = {},
        inputs = {},
        outputs = {},
        valueInfo = {},
        initializers = {},
        initializerIndex = {},
        nodeCount = 0,
        inputCount = 0,
        outputCount = 0,
    }

    while not reader:isAtEnd() do
        local field, wireType = Wire.readTag(reader)
        if field == 1 then
            requireWireType("GraphProto.node", wireType, Wire.LENGTH_DELIMITED)
            table.insert(result.nodes, readNested(reader, "NodeProto", parseNode))
            result.nodeCount = result.nodeCount + 1
        elseif field == 2 then
            requireWireType("GraphProto.name", wireType, Wire.LENGTH_DELIMITED)
            result.name = Wire.readLengthDelimitedString(reader)
        elseif field == 5 then
            requireWireType("GraphProto.initializer", wireType, Wire.LENGTH_DELIMITED)
            local initializer = readNested(reader, "TensorProto", parseTensor)
            initializer.messageOffset = initializer.sourceOffset
            table.insert(result.initializers, initializer)
            result.initializerIndex[initializer.name] = initializer
        elseif field == 11 then
            requireWireType("GraphProto.input", wireType, Wire.LENGTH_DELIMITED)
            table.insert(result.inputs, readNested(reader, "ValueInfoProto", parseValueInfo))
            result.inputCount = result.inputCount + 1
        elseif field == 12 then
            requireWireType("GraphProto.output", wireType, Wire.LENGTH_DELIMITED)
            table.insert(result.outputs, readNested(reader, "ValueInfoProto", parseValueInfo))
            result.outputCount = result.outputCount + 1
        elseif field == 13 then
            requireWireType("GraphProto.value_info", wireType, Wire.LENGTH_DELIMITED)
            table.insert(result.valueInfo, readNested(reader, "ValueInfoProto", parseValueInfo))
        else
            Wire.skipField(reader, wireType)
        end
    end

    if result.name == nil or result.name == "" then
        error("PZONNX ONNX GraphProto is missing name")
    end
    return result
end

local function findOpsetVersion(opsetImports, domain)
    for i = 1, #opsetImports do
        if opsetImports[i].domain == domain then
            return opsetImports[i].version
        end
    end
    return nil
end

function Model.buildCompatibilityReport(model)
    local report = {
        operators = {},
        datatypes = {},
        unsupported = {},
    }

    for i = 1, #model.graph.nodes do
        local node = model.graph.nodes[i]
        local opsetVersion = findOpsetVersion(model.opsetImports, node.domain)
        local execution = OperatorRegistry.describe(node.domain, node.opType, node.attributeCount)
        local operator = {
            domain = node.domain,
            opType = node.opType,
            opsetVersion = opsetVersion,
            attributeCount = node.attributeCount,
            attributes = node.attributes,
            execution = execution,
        }
        table.insert(report.operators, operator)
        if opsetVersion == nil then
            table.insert(report.unsupported,
                "missing opset import for operator domain '" .. tostring(node.domain) .. "'")
        end
        if execution == "unsupported" then
            table.insert(report.unsupported,
                "operator is not registered: " .. tostring(node.domain) .. ":" .. tostring(node.opType))
        elseif execution == "unsupported-attributes" then
            table.insert(report.unsupported,
                "registered operator does not accept attributes: " .. tostring(node.opType))
        end

        local expectedPayloadKinds = {
            [1] = "float",
            [2] = "int",
            [3] = "string",
            [4] = "tensor",
            [5] = "graph",
            [6] = "floats",
            [7] = "ints",
            [8] = "strings",
        }
        for j = 1, #node.attributes do
            local attribute = node.attributes[j]
            local expectedPayloadKind = expectedPayloadKinds[attribute.type]
            if attribute.type == nil then
                table.insert(report.unsupported,
                    "attribute type is missing: " .. tostring(attribute.name))
            elseif expectedPayloadKind == nil then
                table.insert(report.unsupported,
                    "attribute type is not indexed: " .. tostring(attribute.name) ..
                    " type=" .. tostring(attribute.type))
            elseif attribute.payloadKind ~= expectedPayloadKind then
                table.insert(report.unsupported,
                    "attribute payload mismatch: " .. tostring(attribute.name) ..
                    " expected=" .. tostring(expectedPayloadKind) ..
                    " actual=" .. tostring(attribute.payloadKind))
            end
        end
    end

    local function collectTypes(values)
        for i = 1, #values do
            local valueType = values[i].type
            if valueType.kind ~= "tensor" then
                table.insert(report.unsupported,
                    "non-tensor value type is not supported: " .. tostring(valueType.kind))
            else
                table.insert(report.datatypes, valueType.tensor.elemType)
            end
        end
    end

    collectTypes(model.graph.inputs)
    collectTypes(model.graph.outputs)
    collectTypes(model.graph.valueInfo)
    for i = 1, #model.graph.initializers do
        local dataType = model.graph.initializers[i].dataType
        table.insert(report.datatypes, dataType)
        if dataType == nil or dataType < 1 or dataType > 28 then
            table.insert(report.unsupported,
                "unknown TensorProto data_type: " .. tostring(dataType))
        end
        local initializer = model.graph.initializers[i]
        if initializer.dataLocation ~= 0 and initializer.dataLocation ~= 1 then
            table.insert(report.unsupported,
                "unsupported TensorProto data_location: " .. tostring(initializer.dataLocation))
        elseif initializer.dataLocation == 1 and #initializer.externalData == 0 then
            table.insert(report.unsupported,
                "external TensorProto has no external_data references: " .. tostring(initializer.name))
        end
    end

    return report
end

function Model.parseReader(reader)
    assert(reader ~= nil, "PZONNX Model.parseReader requires a reader")

    local result = {
        irVersion = nil,
        producerName = nil,
        producerVersion = nil,
        opsetImports = {},
        graph = nil,
    }

    while not reader:isAtEnd() do
        local field, wireType = Wire.readTag(reader)
        if field == 1 then
            requireWireType("ModelProto.ir_version", wireType, Wire.VARINT)
            result.irVersion = reader:readVarint()
        elseif field == 2 then
            requireWireType("ModelProto.producer_name", wireType, Wire.LENGTH_DELIMITED)
            result.producerName = Wire.readLengthDelimitedString(reader)
        elseif field == 3 then
            requireWireType("ModelProto.producer_version", wireType, Wire.LENGTH_DELIMITED)
            result.producerVersion = Wire.readLengthDelimitedString(reader)
        elseif field == 7 then
            requireWireType("ModelProto.graph", wireType, Wire.LENGTH_DELIMITED)
            result.graph = readNested(reader, "GraphProto", parseGraph)
        elseif field == 8 then
            requireWireType("ModelProto.opset_import", wireType, Wire.LENGTH_DELIMITED)
            table.insert(result.opsetImports, readNested(reader, "OperatorSetIdProto", parseOperatorSetId))
        else
            Wire.skipField(reader, wireType)
        end
    end

    if result.irVersion == nil then
        error("PZONNX ONNX ModelProto is missing ir_version")
    end
    if #result.opsetImports == 0 then
        error("PZONNX ONNX ModelProto is missing opset_import")
    end
    if result.graph == nil then
        error("PZONNX ONNX ModelProto is missing graph")
    end

    result.compatibility = Model.buildCompatibilityReport(result)
    return result
end

function Model.parseBytes(bytes)
    local result = Model.parseReader(BinaryReader.fromBytes(bytes))
    result.sourceBytes = bytes
    return result
end

function Model.loadFile(relativePath)
    local result = GameFile.withReader(relativePath, function(reader)
        return Model.parseReader(reader)
    end)
    result.sourcePath = relativePath
    return result
end

function Model.readInitializerBytes(model, initializer)
    assert(model ~= nil and initializer ~= nil,
        "PZONNX Model.readInitializerBytes requires a model and initializer")
    if initializer.dataLocation == 1 then
        error("PZONNX external initializer loading is not implemented in P2")
    end
    if initializer.rawData == nil then
        error("PZONNX initializer has no inline raw_data: " .. tostring(initializer.name))
    end

    local function readFrom(reader)
        reader:skip(initializer.rawData.offset)
        return reader:readBytes(initializer.rawData.length)
    end

    if model.sourceBytes ~= nil then
        return readFrom(BinaryReader.fromBytes(model.sourceBytes))
    end
    if model.sourcePath ~= nil then
        return GameFile.withReader(model.sourcePath, readFrom)
    end
    error("PZONNX model has no source for lazy initializer access")
end

function Model.readInitializerPackedBytes(model, initializer)
    assert(model ~= nil and initializer ~= nil,
        "PZONNX Model.readInitializerPackedBytes requires a model and initializer")
    if initializer.dataLocation == 1 then
        error("PZONNX external initializer loading is not implemented")
    end
    if initializer.rawData == nil then
        error("PZONNX initializer has no inline raw_data: " .. tostring(initializer.name))
    end

    local function readFrom(reader)
        reader:skip(initializer.rawData.offset)
        return reader:readPackedString(initializer.rawData.length)
    end

    if model.sourceReader ~= nil then return model.sourceReader(readFrom) end
    if model.sourceBytes ~= nil then
        local chunks = {}
        local offset = initializer.rawData.offset + 1
        local finish = offset + initializer.rawData.length - 1
        while offset <= finish do
            local stop = math.min(offset + 4095, finish)
            local chars = {}
            for i = offset, stop do chars[#chars + 1] = string.char(model.sourceBytes[i]) end
            chunks[#chunks + 1] = table.concat(chars)
            offset = stop + 1
        end
        return table.concat(chunks)
    end
    if model.sourcePath ~= nil then return GameFile.withReader(model.sourcePath, readFrom) end
    error("PZONNX model has no source for lazy packed initializer access")
end

return Model
