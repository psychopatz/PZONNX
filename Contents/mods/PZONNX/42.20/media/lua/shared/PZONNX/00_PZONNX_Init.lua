local PZONNX = require("PZONNX/PZONNX")

PZONNX.Log.info("loaded version=" .. tostring(PZONNX.VERSION) .. " phase=" .. tostring(PZONNX.PHASE))

local function runP0ProbeSafely()
    local ok, result = pcall(PZONNX.runP0Probe)
    if not ok then
        PZONNX.Log.warn("probe=P0A status=FAIL error=" .. tostring(result))
    end
end

if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(runP0ProbeSafely)
else
    PZONNX.Log.warn("probe=P0A status=DEFERRED reason=OnGameStart_unavailable")
end
