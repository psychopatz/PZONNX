local Log = require "PZONNX/Diagnostics/Log"

local P17Probe = {}

function P17Probe.run()
    Log.info("probe=P17 status=PARTIAL pipeline=available tts_provider=caller_owned " ..
        "audio_acceptance=OPEN model_specific_tts=false")
    return {
        status = "PARTIAL",
        pipeline = true,
        ttsProvider = "CALLER_OWNED",
        audioAcceptance = "OPEN",
    }
end

return P17Probe
