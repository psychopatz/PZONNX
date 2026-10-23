local Log = require "PZONNX/Diagnostics/Log"
local Model = require "PZONNX/ONNX/Model"

local P0BProbe = {}

P0BProbe.FIXTURE_PATH = "media/pzonnx/fixtures/p0b_minimal.onnx"

local function expect(actual, expected, label)
    if actual ~= expected then
        error(label .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
end

function P0BProbe.run()
    local result = Model.loadFile(P0BProbe.FIXTURE_PATH)
    expect(result.irVersion, 8, "ir_version")
    expect(result.producerName, "PZONNX", "producer_name")
    expect(result.producerVersion, "0.1.0", "producer_version")
    expect(#result.opsetImports, 1, "opset_import count")
    expect(result.opsetImports[1].domain, "", "opset_import domain")
    expect(result.opsetImports[1].version, 13, "opset_import version")
    expect(result.graph.name, "pzonxx_p0b_graph", "graph name")
    expect(result.graph.nodeCount, 1, "graph node count")
    expect(result.graph.inputCount, 1, "graph input count")
    expect(result.graph.outputCount, 1, "graph output count")

    Log.info(
        "probe=P0B status=PASS path=" .. P0BProbe.FIXTURE_PATH ..
        " ir_version=" .. tostring(result.irVersion) ..
        " producer=" .. tostring(result.producerName) ..
        " producer_version=" .. tostring(result.producerVersion) ..
        " opset_domain=" .. tostring(result.opsetImports[1].domain) ..
        " opset_version=" .. tostring(result.opsetImports[1].version) ..
        " graph=" .. tostring(result.graph.name) ..
        " nodes=" .. tostring(result.graph.nodeCount)
    )

    return result
end

return P0BProbe
