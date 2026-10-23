local Log = require "PZONNX/Diagnostics/Log"
local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
local Tensor = require "PZONNX/Tensor"

local P3Probe = {}
P3Probe.FIXTURE_PATH = "media/pzonnx/fixtures/p3_broadcast.onnx"

function P3Probe.run()
    local model = Model.loadFile(P3Probe.FIXTURE_PATH)
    local output = Session.new(model):run({
        input = Tensor.new({ 1, 2 }, { 3.0, 4.0 }),
    }).output
    if math.abs(output.data[1] - 3.5) > 1e-6 or math.abs(output.data[2] - 3.5) > 1e-6 then
        error("PZONNX P3 broadcast mismatch")
    end
    Log.info(
        "probe=P3 status=PASS path=" .. P3Probe.FIXTURE_PATH ..
        " registry=MatMul,Add broadcast=1 output=3.5,3.5 reference=onnxruntime tolerance=1e-6"
    )
    return output
end

return P3Probe
