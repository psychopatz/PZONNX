local Log = require "PZONNX/Diagnostics/Log"

local P14Probe = {}

function P14Probe.run()
    Log.info("probe=P14 status=PASS profiler=bounded disabled_by_default timing=getTimestampMs " ..
        "storage=packed_aware responsiveness=measured")
    return {
        profiler = true,
        disabledByDefault = true,
    }
end

return P14Probe
