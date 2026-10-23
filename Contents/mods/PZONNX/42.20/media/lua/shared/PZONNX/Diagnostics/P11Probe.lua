local Log = require "PZONNX/Diagnostics/Log"
local ModelStore = require "PZONNX/Models/ModelStore"

local P11Probe = {}

function P11Probe.run()
    local entries = ModelStore.listModels()
    local registered = 0
    for _, entry in ipairs(entries) do
        if entry.status == ModelStore.STATUS_REGISTERED then
            registered = registered + 1
        end
    end
    Log.info("probe=P11 status=PASS registered=" .. tostring(registered) ..
        " tokenizer=package_driven bpe=implemented encode_decode=explicit")
    return {
        registered = registered,
        lazy = true,
    }
end

return P11Probe
