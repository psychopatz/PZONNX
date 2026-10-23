local Log = require "PZONNX/Diagnostics/Log"
local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
local Tensor = require "PZONNX/Tensor"

local P2Probe = {}

P2Probe.FIXTURE_PATH = "media/pzonnx/fixtures/p2_linear.onnx"

local function expect(actual, expected, label)
    if actual ~= expected then
        error(label .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
end

function P2Probe.run()
    local model = Model.loadFile(P2Probe.FIXTURE_PATH)
    local session = Session.new(model)
    local outputs = session:run({
        input = Tensor.new({ 1, 2 }, { 3.0, 4.0 }),
    })
    local output = outputs.output
    expect(output.shape[1], 1, "output rows")
    expect(output.shape[2], 1, "output columns")
    if math.abs(output.data[1] - 2.5) > 1e-6 then
        error("PZONNX P2 numerical mismatch expected=2.5 actual=" .. tostring(output.data[1]))
    end

    Log.info(
        "probe=P2 status=PASS path=" .. P2Probe.FIXTURE_PATH ..
        " graph=" .. tostring(model.graph.name) ..
        " operators=MatMul,Add" ..
        " input=3.0,4.0" ..
        " output=" .. tostring(output.data[1]) ..
        " registry=MatMul,Add reference=onnxruntime tolerance=1e-6"
    )
    return outputs
end

return P2Probe
