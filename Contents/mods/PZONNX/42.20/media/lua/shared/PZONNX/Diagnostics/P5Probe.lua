local Log = require "PZONNX/Diagnostics/Log"
local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
local TinyLM = require "PZONNX/Adapters/TinyLM"

local P5Probe = {}
P5Probe.FIXTURE_PATH = "media/pzonnx/fixtures/p5_tiny_lm.onnx"

function P5Probe.run()
    local model = Model.loadFile(P5Probe.FIXTURE_PATH)
    local result = TinyLM.new(Session.new(model), "token_ids", "logits"):nextToken(1)
    if result.tokenId ~= 0 or math.abs(result.logits.data[1] - 0.6) > 1e-6 then
        error("PZONNX P5 one-token proof mismatch")
    end
    Log.info(
        "probe=P5 status=PASS path=" .. P5Probe.FIXTURE_PATH ..
        " vocab=3 hidden=2 input_token=1 next_token=" .. tostring(result.tokenId) ..
        " logits=" .. tostring(result.logits.data[1]) .. "," .. tostring(result.logits.data[2]) ..
        "," .. tostring(result.logits.data[3]) ..
        " reference=onnxruntime tolerance=1e-6"
    )
    return result
end

return P5Probe
