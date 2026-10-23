local PZONNX = require "PZONNX/PZONNX"

PZONNX.Log.info("loaded version=" .. tostring(PZONNX.VERSION) .. " phase=" .. tostring(PZONNX.PHASE))

local function runP0ProbeSafely()
    local ok, result = pcall(PZONNX.runP0Probe)
    if not ok then
        PZONNX.Log.warn("probe=P0A status=FAIL error=" .. tostring(result))
    end
end

local function runP0BProbeSafely()
    local ok, result = pcall(PZONNX.runP0BProbe)
    if not ok then
        PZONNX.Log.warn("probe=P0B status=FAIL error=" .. tostring(result))
    end
end

local function runP1ProbeSafely()
    local ok, result = pcall(PZONNX.runP1Probe)
    if not ok then
        PZONNX.Log.warn("probe=P1 status=FAIL error=" .. tostring(result))
    end
end

local function runP2ProbeSafely()
    local ok, result = pcall(PZONNX.runP2Probe)
    if not ok then
        PZONNX.Log.warn("probe=P2 status=FAIL error=" .. tostring(result))
    end
end

local function runP3ProbeSafely()
    local ok, result = pcall(PZONNX.runP3Probe)
    if not ok then
        PZONNX.Log.warn("probe=P3 status=FAIL error=" .. tostring(result))
    end
end

local function runP4ProbeSafely()
    local ok, result = pcall(PZONNX.runP4Probe)
    if not ok then
        PZONNX.Log.warn("probe=P4 status=FAIL error=" .. tostring(result))
    end
end

local function runP5ProbeSafely()
    local ok, result = pcall(PZONNX.runP5Probe)
    if not ok then
        PZONNX.Log.warn("probe=P5 status=FAIL error=" .. tostring(result))
    end
end

local function runP6ProbeSafely()
    local ok, result = pcall(PZONNX.runP6Probe)
    if not ok then
        PZONNX.Log.warn("probe=P6 status=FAIL error=" .. tostring(result))
    end
end

local function runP7ProbeSafely()
    local ok, result = pcall(PZONNX.runP7Probe)
    if not ok then
        PZONNX.Log.warn("probe=P7 status=FAIL error=" .. tostring(result))
    end
end

local function runP8ProbeSafely()
    local ok, result = pcall(PZONNX.runP8Probe)
    if not ok then
        PZONNX.Log.warn("probe=P8 status=FAIL error=" .. tostring(result))
    end
end

local function runP9AProbeSafely()
    local ok, result = pcall(PZONNX.runP9AProbe)
    if not ok then
        PZONNX.Log.warn("probe=P9A status=FAIL error=" .. tostring(result))
    end
end

local function runP9BProbeSafely()
    local ok, result = pcall(PZONNX.runP9BProbe)
    if not ok then
        PZONNX.Log.warn("probe=P9B status=FAIL error=" .. tostring(result))
    end
end

local function runP9CProbeSafely()
    local ok, result = pcall(PZONNX.runP9CProbe)
    if not ok then
        PZONNX.Log.warn("probe=P9C status=FAIL error=" .. tostring(result))
    end
end

local function runP9DProbeSafely()
    local ok, result = pcall(PZONNX.runP9DProbe)
    if not ok then
        PZONNX.Log.warn("probe=P9D status=FAIL error=" .. tostring(result))
    end
end

local function runP10ProbeSafely()
    local ok, result = pcall(PZONNX.runP10Probe)
    if not ok then
        PZONNX.Log.warn("probe=P10 status=FAIL error=" .. tostring(result))
    end
end

if Events ~= nil and Events.OnGameStart ~= nil then
    Events.OnGameStart.Add(runP0ProbeSafely)
    Events.OnGameStart.Add(runP0BProbeSafely)
    Events.OnGameStart.Add(runP1ProbeSafely)
    Events.OnGameStart.Add(runP2ProbeSafely)
    Events.OnGameStart.Add(runP3ProbeSafely)
    Events.OnGameStart.Add(runP4ProbeSafely)
    Events.OnGameStart.Add(runP5ProbeSafely)
    Events.OnGameStart.Add(runP6ProbeSafely)
    Events.OnGameStart.Add(runP7ProbeSafely)
    Events.OnGameStart.Add(runP8ProbeSafely)
    Events.OnGameStart.Add(runP9AProbeSafely)
    Events.OnGameStart.Add(runP9BProbeSafely)
    Events.OnGameStart.Add(runP9CProbeSafely)
    Events.OnGameStart.Add(runP9DProbeSafely)
    Events.OnGameStart.Add(runP10ProbeSafely)
else
    PZONNX.Log.warn("probe=P0A status=DEFERRED reason=OnGameStart_unavailable")
    PZONNX.Log.warn("probe=P0B status=DEFERRED reason=OnGameStart_unavailable")
    PZONNX.Log.warn("probe=P1 status=DEFERRED reason=OnGameStart_unavailable")
    PZONNX.Log.warn("probe=P2 status=DEFERRED reason=OnGameStart_unavailable")
    PZONNX.Log.warn("probe=P3 status=DEFERRED reason=OnGameStart_unavailable")
    PZONNX.Log.warn("probe=P4 status=DEFERRED reason=OnGameStart_unavailable")
    PZONNX.Log.warn("probe=P5 status=DEFERRED reason=OnGameStart_unavailable")
    PZONNX.Log.warn("probe=P6 status=DEFERRED reason=OnGameStart_unavailable")
    PZONNX.Log.warn("probe=P7 status=DEFERRED reason=OnGameStart_unavailable")
    PZONNX.Log.warn("probe=P8 status=DEFERRED reason=OnGameStart_unavailable")
    PZONNX.Log.warn("probe=P9A status=DEFERRED reason=OnGameStart_unavailable")
    PZONNX.Log.warn("probe=P9B status=DEFERRED reason=OnGameStart_unavailable")
    PZONNX.Log.warn("probe=P9C status=DEFERRED reason=OnGameStart_unavailable")
    PZONNX.Log.warn("probe=P9D status=DEFERRED reason=OnGameStart_unavailable")
    PZONNX.Log.warn("probe=P10 status=DEFERRED reason=OnGameStart_unavailable")
end
