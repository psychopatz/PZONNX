local Log = require "PZONNX/Diagnostics/Log"
local ModelStore = require "PZONNX/Models/ModelStore"

local P9AProbe = {}

function P9AProbe.run()
    local state = ModelStore.refresh()
    if type(state) ~= "table" or type(state.entries) ~= "table" then
        error("PZONNX P9A model store returned an invalid registry")
    end

    Log.info("probe=P9A status=PASS ledger=" .. tostring(state.ledgerPath) ..
        " ledger_status=" .. tostring(state.ledgerStatus) ..
        " entries=" .. tostring(state.entryCount) ..
        " registered=" .. tostring(state.registeredCount) ..
        " missing=" .. tostring(state.missingCount) ..
        " invalid=" .. tostring(state.invalidCount) ..
        " lazy=true")
    return state
end

return P9AProbe
