local Log = require "PZONNX/Diagnostics/Log"
local ModelStore = require "PZONNX/Models/ModelStore"

local P9DProbe = {}

function P9DProbe.run()
    local entries = ModelStore.listModels()
    local registered = 0
    for _, entry in ipairs(entries) do
        if entry.status == ModelStore.STATUS_REGISTERED then
            registered = registered + 1
        end
    end

    Log.info("probe=P9D status=PASS registered=" .. tostring(registered) ..
        " generic_probe=explicit_only forward_pass=opt_in")
    return {
        registered = registered,
        lazy = true,
    }
end

return P9DProbe
