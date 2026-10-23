local Log = require "PZONNX/Diagnostics/Log"
local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
local Tensor = require "PZONNX/Tensor"

local P6Probe = {}
P6Probe.FIXTURE_PATH = "media/pzonnx/fixtures/p2_linear.onnx"

function P6Probe.run()
    local model = Model.loadFile(P6Probe.FIXTURE_PATH)
    local session = Session.new(model, { quantizedWeightScale = 0.02 })
    local job = session:newJob({ input = Tensor.new({ 1, 2 }, { 3.0, 4.0 }) })
    local first = job:step(1)
    local second = job:step(1)
    local output = second.outputs.output
    if first.done or not second.done or math.abs(output.data[1] - 2.5) > 1e-6 then
        error("PZONNX P6 cooperative/quantized proof mismatch")
    end
    local storageBytes = Tensor.storageBytes(session.initializerTensors.weight)
    Log.info(
        "probe=P6 status=PASS path=" .. P6Probe.FIXTURE_PATH ..
        " budget=node work=" .. tostring(first.work + second.work) ..
        " state=" .. tostring(second.state) ..
        " quantized=int8 scale=0.02 weight_storage_bytes=" .. tostring(storageBytes) ..
        " output=" .. tostring(output.data[1]) .. " tolerance=1e-6"
    )
    return second
end

return P6Probe
