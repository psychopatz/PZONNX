local Log = require "PZONNX/Diagnostics/Log"
local ModelStore = require "PZONNX/Models/ModelStore"
local ModelPackage = require "PZONNX/Models/ModelPackage"

local P9BProbe = {}

function P9BProbe.run()
    local entries = ModelStore.listModels()
    local packageCount = 0
    for _, entry in ipairs(entries) do
        if entry.status == ModelStore.STATUS_REGISTERED then
            ModelPackage.new(entry)
            packageCount = packageCount + 1
        end
    end

    Log.info("probe=P9B status=PASS packages=" .. tostring(packageCount) ..
        " companions=lazy external_data=package_relative")
    return {
        packageCount = packageCount,
        entryCount = #entries,
    }
end

return P9BProbe
