local UserFile = require "PZONNX/IO/UserFile"

local ModelStore = {}

ModelStore.STATUS_REGISTERED = "REGISTERED"
ModelStore.STATUS_MISSING = "MISSING"
ModelStore.STATUS_INVALID = "INVALID"

local current = {
    ledgerPath = UserFile.FULL_LEDGER_PATH,
    modelRoot = UserFile.MODEL_ROOT,
    ledgerStatus = "NOT_REFRESHED",
    readable = false,
    entries = {},
    diagnostics = {},
    entryCount = 0,
    registeredCount = 0,
    missingCount = 0,
    invalidCount = 0,
}

local function trim(value)
    return string.gsub(string.gsub(value, "^%s+", ""), "%s+$", "")
end

local function lineId(lineNumber)
    return "line:" .. tostring(lineNumber)
end

local function addDiagnostic(diagnostics, entry, kind, reason)
    local diagnostic = {
        kind = kind,
        line = entry.line,
        id = entry.id,
        path = entry.path,
        raw = entry.raw,
        reason = reason,
    }
    table.insert(diagnostics, diagnostic)
    entry.diagnostic = diagnostic
end

local function parseLedger(text)
    assert(type(text) == "string", "PZONNX ModelStore ledger text must be a string")

    local entries = {}
    local diagnostics = {}
    local seen = {}
    local lineNumber = 0
    local normalizedText = string.gsub(string.gsub(text, "\r\n", "\n"), "\r", "\n")

    for line in string.gmatch(normalizedText .. "\n", "(.-)\n") do
        lineNumber = lineNumber + 1
        local raw = line
        local candidate = trim(line)
        if candidate ~= "" and string.sub(candidate, 1, 1) ~= "#" then
            local entry = {
                id = lineId(lineNumber),
                line = lineNumber,
                raw = raw,
                path = nil,
                status = ModelStore.STATUS_INVALID,
                reason = nil,
            }
            local path, reason = UserFile.validateRelativePath(candidate)
            if path == nil then
                entry.reason = reason
                addDiagnostic(diagnostics, entry, "INVALID_PATH", reason)
            elseif seen[path] ~= nil then
                entry.path = path
                entry.reason = "duplicate of ledger line " .. tostring(seen[path])
                addDiagnostic(diagnostics, entry, "DUPLICATE", entry.reason)
            else
                seen[path] = lineNumber
                entry.id = path
                entry.path = path
                entry.status = nil
            end
            table.insert(entries, entry)
        end
    end

    return entries, diagnostics
end

local function countEntries(entries)
    local registered = 0
    local missing = 0
    local invalid = 0
    for _, entry in ipairs(entries) do
        if entry.status == ModelStore.STATUS_REGISTERED then
            registered = registered + 1
        elseif entry.status == ModelStore.STATUS_MISSING then
            missing = missing + 1
        else
            invalid = invalid + 1
        end
    end
    return registered, missing, invalid
end

local function copyRegistry(registry)
    return registry
end

function ModelStore.parseLedger(text)
    local entries, diagnostics = parseLedger(text)
    return entries, diagnostics
end

function ModelStore.refreshFromText(text, existsFn)
    existsFn = existsFn or UserFile.exists
    assert(type(existsFn) == "function", "PZONNX ModelStore exists callback must be a function")

    local entries, diagnostics = parseLedger(text)
    for _, entry in ipairs(entries) do
        if entry.status == nil then
            local ok, exists, reason = pcall(existsFn, entry.path)
            if ok and exists then
                entry.status = ModelStore.STATUS_REGISTERED
            else
                entry.status = ModelStore.STATUS_MISSING
                if not ok then
                    reason = "existence check failed: " .. tostring(exists)
                end
                entry.reason = reason or "user model file is missing"
                addDiagnostic(diagnostics, entry, "MISSING", entry.reason)
            end
        end
    end

    local registered, missing, invalid = countEntries(entries)
    current = {
        ledgerPath = UserFile.FULL_LEDGER_PATH,
        modelRoot = UserFile.MODEL_ROOT,
        ledgerStatus = "READABLE",
        readable = true,
        entries = entries,
        diagnostics = diagnostics,
        entryCount = #entries,
        registeredCount = registered,
        missingCount = missing,
        invalidCount = invalid,
    }
    return copyRegistry(current)
end

function ModelStore.refresh()
    local text, reason = UserFile.tryReadText(UserFile.LEDGER_PATH)
    if text == nil then
        local missing = string.find(tostring(reason), "missing", 1, true) ~= nil
        local ledgerStatus = missing and "MISSING" or "UNAVAILABLE"
        local diagnostic = {
            kind = missing and "LEDGER_MISSING" or "LEDGER_UNAVAILABLE",
            line = nil,
            id = nil,
            path = UserFile.LEDGER_PATH,
            raw = nil,
            reason = reason,
        }
        current = {
            ledgerPath = UserFile.FULL_LEDGER_PATH,
            modelRoot = UserFile.MODEL_ROOT,
            ledgerStatus = ledgerStatus,
            readable = false,
            entries = {},
            diagnostics = { diagnostic },
            entryCount = 0,
            registeredCount = 0,
            missingCount = 0,
            invalidCount = 0,
        }
        return copyRegistry(current)
    end
    return ModelStore.refreshFromText(text, UserFile.exists)
end

function ModelStore.listModels()
    return current.entries
end

function ModelStore.getModelEntry(idOrPath)
    if type(idOrPath) ~= "string" then
        return nil
    end
    for _, entry in ipairs(current.entries) do
        if entry.id == idOrPath or entry.path == idOrPath then
            return entry
        end
    end
    return nil
end

function ModelStore.getDiagnostics()
    return current.diagnostics
end

function ModelStore.getState()
    return copyRegistry(current)
end

return ModelStore
