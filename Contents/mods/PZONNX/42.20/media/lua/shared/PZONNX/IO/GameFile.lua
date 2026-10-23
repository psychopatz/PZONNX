local BinaryReader = require "PZONNX/IO/BinaryReader"

local GameFile = {}

local function closeStream(stream)
    local closed = false
    local ok = pcall(function() stream:close() end)
    if ok then closed = true end
    if not closed and endFileInput ~= nil then
        pcall(endFileInput)
    end
end

function GameFile.open(relativePath)
    assert(type(relativePath) == "string" and relativePath ~= "",
        "PZONNX GameFile.open requires a non-empty relative path")
    if getGameFilesInput == nil then
        error("PZONNX getGameFilesInput is unavailable in this Lua environment")
    end
    local stream = getGameFilesInput(relativePath)
    if stream == nil then
        error("PZONNX could not open packaged game file: " .. tostring(relativePath))
    end
    return stream
end

function GameFile.withReader(relativePath, callback)
    assert(type(callback) == "function", "PZONNX GameFile.withReader requires a callback")
    local stream = GameFile.open(relativePath)
    local reader = BinaryReader.new(stream)
    local ok, result = pcall(callback, reader, stream)
    closeStream(stream)
    if not ok then error(result) end
    return result
end

return GameFile
