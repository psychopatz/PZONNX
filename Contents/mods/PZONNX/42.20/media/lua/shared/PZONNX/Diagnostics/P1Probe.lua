local Log = require "PZONNX/Diagnostics/Log"
local Model = require "PZONNX/ONNX/Model"

local P1Probe = {}

P1Probe.FIXTURE_PATH = "media/pzonnx/fixtures/p1_metadata.onnx"
P1Probe.ATTRIBUTE_FIXTURE_PATH = "media/pzonnx/fixtures/p1_attribute.onnx"

local function expect(actual, expected, label)
    if actual ~= expected then
        error(label .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
end

function P1Probe.run()
    local model = Model.loadFile(P1Probe.FIXTURE_PATH)
    local node = model.graph.nodes[1]
    local inline = model.graph.initializerIndex.weight
    local external = model.graph.initializerIndex.external_weight
    local attributeModel = Model.loadFile(P1Probe.ATTRIBUTE_FIXTURE_PATH)
    local attribute = attributeModel.graph.nodes[1].attributes[1]

    expect(node.opType, "Add", "node op_type")
    expect(node.inputs[2], "weight", "node input")
    expect(model.graph.inputs[1].type.tensor.elemType, 1, "input elem_type")
    expect(inline.rawData.length, 4, "inline raw_data length")
    expect(inline.rawData.bytes, nil, "inline raw_data expansion")
    expect(external.dataLocation, 1, "external data location")
    expect(external.externalData[1].value, "p1_external_weights.bin", "external data path")
    expect(model.compatibility.operators[1].execution, "supported", "operator execution status")
    expect(attribute.name, "to", "attribute name")
    expect(attribute.type, 2, "attribute type")
    expect(attribute.payloadKind, "int", "attribute payload kind")
    expect(attributeModel.compatibility.unsupported[1],
        "operator is not registered: :Cast", "attribute fixture unsupported report")

    Log.info(
        "probe=P1 status=PASS path=" .. P1Probe.FIXTURE_PATH ..
        " graph=" .. tostring(model.graph.name) ..
        " node=" .. tostring(node.opType) ..
        " opset=" .. tostring(model.compatibility.operators[1].opsetVersion) ..
        " initializers=" .. tostring(#model.graph.initializers) ..
        " inline_raw_bytes=" .. tostring(inline.rawData.length) ..
        " external=" .. tostring(external.externalData[1].value) ..
        " attribute=" .. tostring(attribute.name) .. ":" .. tostring(attribute.payloadKind) ..
        " execution=inspection-only"
    )

    return model
end

return P1Probe
