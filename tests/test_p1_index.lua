package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Model = require "PZONNX/ONNX/Model"

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function readFixture(path)
    local file = assert(io.open(path, "rb"))
    local data = file:read("*all")
    file:close()
    local bytes = {}
    for i = 1, #data do
        bytes[i] = string.byte(data, i)
    end
    return bytes
end

local model = Model.parseBytes(readFixture("Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p1_metadata.onnx"))
assertEqual(model.graph.name, "pzonxx_p1_graph", "graph name")
assertEqual(#model.graph.nodes, 1, "node count")
assertEqual(model.graph.nodes[1].opType, "Add", "node op type")
assertEqual(model.graph.nodes[1].inputs[2], "weight", "node second input")
assertEqual(model.graph.nodes[1].outputs[1], "output", "node output")
assertEqual(#model.graph.nodes[1].attributes, 0, "node attribute count")

assertEqual(model.graph.inputs[1].name, "input", "input name")
assertEqual(model.graph.inputs[1].type.kind, "tensor", "input type kind")
assertEqual(model.graph.inputs[1].type.tensor.elemType, 1, "input element type")
assertEqual(model.graph.inputs[1].type.tensor.shape.dims[1].value, 1, "input dimension")

local inline = model.graph.initializerIndex.weight
assertEqual(inline.dataType, 1, "inline initializer type")
assertEqual(inline.dims[1], 1, "inline initializer dimension")
assertEqual(inline.rawData.relativeOffset, 15, "inline raw data offset")
assertEqual(inline.rawData.length, 4, "inline raw data length")
assertEqual(inline.rawData.bytes, nil, "inline raw data is not expanded")

local external = model.graph.initializerIndex.external_weight
assertEqual(external.dataLocation, 1, "external data location")
assertEqual(external.rawData, nil, "external raw data absent")
assertEqual(external.externalData[1].key, "location", "external data key")
assertEqual(external.externalData[1].value, "p1_external_weights.bin", "external data path")

assertEqual(model.compatibility.operators[1].opType, "Add", "inventory operator")
assertEqual(model.compatibility.operators[1].opsetVersion, 13, "inventory opset")
assertEqual(model.compatibility.operators[1].execution, "supported", "inventory execution status")
assertEqual(#model.compatibility.unsupported, 0, "supported compatibility count")

do
    local attributeModel = Model.parseBytes(readFixture(
        "Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p1_attribute.onnx"))
    local attribute = attributeModel.graph.nodes[1].attributes[1]
    assertEqual(attribute.name, "to", "attribute name")
    assertEqual(attribute.type, 2, "attribute type")
    assertEqual(attribute.payloadKind, "int", "attribute payload kind")
    assertEqual(#attributeModel.compatibility.unsupported, 0, "attribute compatibility count")
end

do
    local bytes = readFixture("Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p1_metadata.onnx")
    table.insert(bytes, 0xA0)
    table.insert(bytes, 0x01)
    table.insert(bytes, 0x07)
    local unknownFieldModel = Model.parseBytes(bytes)
    assertEqual(unknownFieldModel.graph.name, "pzonxx_p1_graph", "unknown-field graph")
end

do
    local malformedNodeModel = {
        0x08, 0x08,
        0x3A, 0x0A,
        0x0A, 0x04, 0x20, 0x01, 0x00, 0x00,
        0x12, 0x01, 0x67,
        0x42, 0x02, 0x10, 0x0D,
    }
    local ok, err = pcall(function() Model.parseBytes(malformedNodeModel) end)
    if ok or not string.find(tostring(err), "NodeProto.op_type has wire type", 1, true) then
        error("wrong NodeProto wire type was not rejected explicitly: " .. tostring(err))
    end
end

print("PZONNX P1 model indexing tests passed")
