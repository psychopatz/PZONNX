local Log = require "PZONNX/Diagnostics/Log"
local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
local Tensor = require "PZONNX/Tensor"

local P4Probe = {}
P4Probe.FIXTURE_PATH = "media/pzonnx/fixtures/p4_tiny_attention.onnx"

function P4Probe.run()
    local model = Model.loadFile(P4Probe.FIXTURE_PATH)
    local output = Session.new(model):run({
        hidden = Tensor.new({ 1, 2 }, { 1.0, -1.0 }),
    }).logits
    if math.abs(output.data[1] - 1.9807970523834229) > 1e-6 or
        math.abs(output.data[2] - 1.0192029476165771) > 1e-6 then
        error("PZONNX P4 transformer-style logits mismatch")
    end
    Log.info(
        "probe=P4 status=PASS path=" .. P4Probe.FIXTURE_PATH ..
        " inventory=MatMul,Softmax,MatMul,Add logits=" ..
        tostring(output.data[1]) .. "," .. tostring(output.data[2]) ..
        " reference=onnxruntime tolerance=1e-6"
    )
    return output
end

return P4Probe
