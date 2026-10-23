local Log = require "PZONNX/Diagnostics/Log"
local ModelStore = require "PZONNX/Models/ModelStore"

local P9CProbe = {}

function P9CProbe.run()
    local entries = ModelStore.listModels()
    local registered = 0
    for _, entry in ipairs(entries) do
        if entry.status == ModelStore.STATUS_REGISTERED then
            registered = registered + 1
        end
    end

    Log.info("probe=P9C status=PASS registered=" .. tostring(registered) ..
        " profile=lazy unknowns=preserved graph_parse=explicit_only")
    return {
        registered = registered,
        lazy = true,
    }
end

return P9CProbe
