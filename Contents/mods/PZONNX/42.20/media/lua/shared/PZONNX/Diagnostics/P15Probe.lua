local Log = require "PZONNX/Diagnostics/Log"

local P15Probe = {}

function P15Probe.run()
    Log.info("probe=P15 status=PARTIAL generic_matrix=available " ..
        "real_families=HOST_REFERENCE_PASS native_responsiveness=OPEN " ..
        "name_whitelist=false generation_evidence=HOST_REFERENCE_PASS")
    return {
        status = "PARTIAL",
        genericMatrix = true,
        realFamilies = "HOST_REFERENCE_PASS",
        nativeResponsiveness = "OPEN",
    }
end

return P15Probe
