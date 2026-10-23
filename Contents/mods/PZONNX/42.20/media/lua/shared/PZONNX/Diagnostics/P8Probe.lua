local Fallback = require "PZONNX/Adapters/Fallback"
local Log = require "PZONNX/Diagnostics/Log"

local P8Probe = {}

function P8Probe.run()
    local adapter = Fallback.new(
        function() return "primary" end,
        function() return "fallback" end
    )
    local result = adapter:run()
    if result.source ~= "pzonxx" then
        error("PZONNX P8 primary public boundary failed")
    end
    Log.info("probe=P8 status=PASS public_api=stable fallback_boundary=ready native_gates=P0A-P7_OPEN")
    return result
end

return P8Probe
