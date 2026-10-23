local BinaryReader = require "PZONNX/IO/BinaryReader"

local UserFile = {}

UserFile.MODEL_ROOT = "Models"
UserFile.LEDGER_PATH = "ledger.txt"
UserFile.FULL_LEDGER_PATH = UserFile.MODEL_ROOT .. "/" .. UserFile.LEDGER_PATH
UserFile.DEFAULT_TEXT_LIMIT = 262144

local function trim(value)
    return string.gsub(string.gsub(value, "^%s+", ""), "%s+$", "")
end

local function hasControlCharacter(value)
    for index = 1, #value do
        local byte = string.byte(value, index)
        if byte == 0 or byte < 32 or byte == 127 then
            return true
        end
    end
    return false
end

-- Paths accepted here are relative to Zomboid/Lua/Models/.  The returned
-- value is the canonical path passed to getFileInput, not a host filesystem
-- path.  Keeping this check in one adapter prevents callers from accidentally
-- crossing the user-model root.
function UserFile.validateRelativePath(relativePath)
    if type(relativePath) ~= "string" then
        return nil, "path must be a string"
    end

    local path = trim(relativePath)
    if path == "" then
        return nil, "path is empty"
    end
    if hasControlCharacter(path) then
        return nil, "path contains a control character"
    end

    path = string.gsub(path, "\\", "/")
    if path == "" then
        return nil, "path is empty"
    end
    if string.sub(path, 1, 1) == "/" then
        return nil, "absolute and UNC paths are not allowed"
    end
    if string.find(path, ":", 1, true) ~= nil then
        return nil, "drive, URI, and network paths are not allowed"
    end
    if string.find(path, "//", 1, true) ~= nil then
        return nil, "empty path segments are not allowed"
    end
    if string.sub(path, -1) == "/" then
        return nil, "path must identify a file"
    end

    local parts = {}
    for part in string.gmatch(path, "[^/]+") do
        if part == "." or part == ".." then
            return nil, "relative traversal segments are not allowed"
        end
        table.insert(parts, part)
    end
    if #parts == 0 then
        return nil, "path has no file segments"
    end

    return table.concat(parts, "/")
end

function UserFile.resolve(relativePath)
    local normalized, reason = UserFile.validateRelativePath(relativePath)
    if normalized == nil then
        return nil, reason
    end
    return UserFile.MODEL_ROOT .. "/" .. normalized, nil, normalized
end

local function closeStream(stream)
    local closed = false
    local ok = pcall(function() stream:close() end)
    if ok then
        closed = true
    end
    if not closed and endFileInput ~= nil then
        pcall(endFileInput)
    end
end

function UserFile.tryOpen(relativePath)
    local fullPath, reason, normalized = UserFile.resolve(relativePath)
    if fullPath == nil then
        return nil, reason
    end
    if getFileInput == nil then
        return nil, "PZONNX getFileInput is unavailable in this Lua environment"
    end

    local ok, stream = pcall(getFileInput, fullPath)
    if not ok then
        return nil, "getFileInput failed for " .. fullPath .. ": " .. tostring(stream)
    end
    if stream == nil then
        return nil, "user file is missing: " .. fullPath
    end
    return stream, nil, normalized, fullPath
end

function UserFile.open(relativePath)
    local stream, reason = UserFile.tryOpen(relativePath)
    if stream == nil then
        error("PZONNX could not open user model file: " .. tostring(reason))
    end
    return stream
end

function UserFile.exists(relativePath)
    local stream, reason = UserFile.tryOpen(relativePath)
    if stream == nil then
        return false, reason
    end
    closeStream(stream)
    return true
end

function UserFile.withReader(relativePath, callback, limit)
    assert(type(callback) == "function", "PZONNX UserFile.withReader requires a callback")
    local stream = UserFile.open(relativePath)
    local reader = BinaryReader.new(stream, limit)
    local ok, result = pcall(callback, reader, stream)
    closeStream(stream)
    if not ok then
        error(result)
    end
    return result
end

function UserFile.tryReadText(relativePath, limit)
    limit = limit or UserFile.DEFAULT_TEXT_LIMIT
    assert(type(limit) == "number" and limit >= 0 and limit == math.floor(limit),
        "PZONNX UserFile text limit must be a non-negative integer")

    local stream, reason = UserFile.tryOpen(relativePath)
    if stream == nil then
        return nil, reason
    end

    local ok, text = pcall(function()
        local reader = BinaryReader.new(stream)
        local available = reader:remaining()
        if available == nil then
            error("user file stream does not expose a bounded byte count")
        end
        if available > limit then
            error("user text file exceeds the " .. tostring(limit) .. " byte limit")
        end
        return reader:readAscii(available)
    end)
    closeStream(stream)
    if not ok then
        return nil, tostring(text)
    end
    return text
end

function UserFile.readText(relativePath, limit)
    local text, reason = UserFile.tryReadText(relativePath, limit)
    if text == nil then
        error("PZONNX could not read user model file: " .. tostring(reason))
    end
    return text
end

return UserFile
