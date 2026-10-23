local Log = {}

local PREFIX = "[PZONNX]"

local function emit(level, message)
    print(PREFIX .. " " .. tostring(level) .. " " .. tostring(message))
end

function Log.info(message)
    emit("INFO", message)
end

function Log.warn(message)
    emit("WARN", message)
end

function Log.error(message)
    emit("ERROR", message)
end

return Log
