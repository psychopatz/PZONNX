local Fallback = {}
Fallback.__index = Fallback

function Fallback.new(primary, fallback, logger)
    assert(type(primary) == "function", "PZONNX fallback primary must be a function")
    assert(type(fallback) == "function", "PZONNX fallback handler must be a function")
    return setmetatable({
        primary = primary,
        fallback = fallback,
        logger = logger,
    }, Fallback)
end

function Fallback:run(...)
    local ok, result = pcall(self.primary, ...)
    if ok then
        return { source = "pzonxx", value = result }
    end

    local primaryError = tostring(result)
    if self.logger ~= nil then
        pcall(self.logger, "PZONNX primary path degraded to fallback: " .. primaryError)
    end
    local fallbackOk, fallbackResult = pcall(self.fallback, primaryError, ...)
    if not fallbackOk then
        error("PZONNX primary and fallback paths failed: primary=" .. primaryError ..
            " fallback=" .. tostring(fallbackResult))
    end
    return {
        source = "fallback",
        value = fallbackResult,
        primaryError = primaryError,
    }
end

return Fallback
