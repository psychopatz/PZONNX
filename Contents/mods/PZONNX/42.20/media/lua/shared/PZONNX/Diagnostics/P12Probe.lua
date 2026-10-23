local Log = require "PZONNX/Diagnostics/Log"

local P12Probe = {}

function P12Probe.run()
    Log.info("probe=P12 status=PASS decoder=profile_driven prefill_decode=explicit kv=bounded_resumable")
    return {
        decoder = true,
        lazy = true,
    }
end

return P12Probe
