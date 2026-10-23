local Log = require "PZONNX/Diagnostics/Log"
local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
local TinyTTS = require "PZONNX/Adapters/TinyTTS"

local P7Probe = {}
P7Probe.FIXTURE_PATH = "media/pzonnx/fixtures/p7_tiny_tts.onnx"

function P7Probe.run()
    local model = Model.loadFile(P7Probe.FIXTURE_PATH)
    local audio = TinyTTS.new(Session.new(model), "token_ids", "pcm"):synthesize({ 1 })
    if math.abs(audio.pcm[1] - 0.5) > 1e-6 or math.abs(audio.pcm[4] - 0.3) > 1e-6 then
        error("PZONNX P7 numeric audio mismatch")
    end
    Log.info(
        "probe=P7 status=PASS path=" .. P7Probe.FIXTURE_PATH ..
        " input_token=1 sample_rate=" .. tostring(audio.sampleRate) ..
        " samples=" .. tostring(#audio.pcm) ..
        " pcm=" .. tostring(audio.pcm[1]) .. "," .. tostring(audio.pcm[2]) ..
        "," .. tostring(audio.pcm[3]) .. "," .. tostring(audio.pcm[4]) ..
        " reference=onnxruntime tolerance=1e-6"
    )
    return audio
end

return P7Probe
