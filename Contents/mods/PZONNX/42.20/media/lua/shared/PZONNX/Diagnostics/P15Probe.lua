local Log = require "PZONNX/Diagnostics/Log"

local P15Probe = {}

function P15Probe.run()
    Log.info("probe=P15 status=PARTIAL generic_matrix=available real_families=OPEN " ..
        "name_whitelist=false generation_evidence=OPEN")
    return {
        status = "PARTIAL",
        genericMatrix = true,
        realFamilies = "OPEN",
    }
end

return P15Probe
