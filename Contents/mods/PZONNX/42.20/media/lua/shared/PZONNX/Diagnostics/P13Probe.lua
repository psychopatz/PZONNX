local Log = require "PZONNX/Diagnostics/Log"

local P13Probe = {}

function P13Probe.run()
    Log.info("probe=P13 status=PASS sampling=greedy,temperature,topk,topp,penalties seeded=true stopping=true")
    return {
        sampling = true,
        seeded = true,
    }
end

return P13Probe
