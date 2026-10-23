local UserFile = require "PZONNX/IO/UserFile"
local ModelStore = require "PZONNX/Models/ModelStore"

local ModelPackage = {}
ModelPackage.__index = ModelPackage

ModelPackage.COMPANION_NAMES = {
    "config.json",
    "generation_config.json",
    "tokenizer.json",
    "tokenizer_config.json",
    "special_tokens_map.json",
    "added_tokens.json",
    "vocab.json",
    "merges.txt",
    "tokenizer.model",
    "spiece.model",
}

local companionNameSet = {}
for _, name in ipairs(ModelPackage.COMPANION_NAMES) do
    companionNameSet[name] = true
end

local function directoryOf(path)
    local slash = nil
    for index = 1, #path do
        if string.sub(path, index, index) == "/" then
            slash = index
        end
    end
    if slash == nil then
        return ""
    end
    return string.sub(path, 1, slash - 1)
end

local function joinRelative(root, child)
    if root == "" then
        return child
    end
    return root .. "/" .. child
end

local function assertCompanionName(name)
    if type(name) ~= "string" or not companionNameSet[name] then
        error("PZONNX unknown model companion: " .. tostring(name))
    end
end

function ModelPackage.new(entry)
    assert(type(entry) == "table", "PZONNX ModelPackage requires a ModelEntry")
    assert(entry.status == ModelStore.STATUS_REGISTERED,
        "PZONNX ModelPackage requires a registered model entry")
    local modelPath, reason = UserFile.validateRelativePath(entry.path)
    assert(modelPath ~= nil, "PZONNX ModelPackage has an unsafe model path: " .. tostring(reason))

    return setmetatable({
        id = entry.id,
        entry = entry,
        modelPath = modelPath,
        modelRoot = directoryOf(modelPath),
        fullModelPath = UserFile.MODEL_ROOT .. "/" .. modelPath,
    }, ModelPackage)
end

function ModelPackage.forEntry(idOrPath)
    local entry = ModelStore.getModelEntry(idOrPath)
    if entry == nil then
        return nil, "model entry was not found: " .. tostring(idOrPath)
    end
    if entry.status ~= ModelStore.STATUS_REGISTERED then
        return nil, "model entry is not registered: " .. tostring(entry.status)
    end
    return ModelPackage.new(entry)
end

function ModelPackage:listCompanions()
    local result = {}
    for _, name in ipairs(ModelPackage.COMPANION_NAMES) do
        local path = joinRelative(self.modelRoot, name)
        local exists, reason = UserFile.exists(path)
        table.insert(result, {
            name = name,
            path = path,
            status = exists and "PRESENT" or "MISSING",
            present = exists,
            reason = exists and nil or reason,
        })
    end
    return result
end

function ModelPackage:getCompanion(name)
    assertCompanionName(name)
    local path = joinRelative(self.modelRoot, name)
    local exists, reason = UserFile.exists(path)
    return {
        name = name,
        path = path,
        status = exists and "PRESENT" or "MISSING",
        present = exists,
        reason = exists and nil or reason,
    }
end

function ModelPackage:openCompanion(name)
    assertCompanionName(name)
    return UserFile.open(joinRelative(self.modelRoot, name))
end

function ModelPackage:readCompanionText(name, limit)
    assertCompanionName(name)
    return UserFile.tryReadText(joinRelative(self.modelRoot, name), limit)
end

function ModelPackage:resolveExternalData(location)
    local normalized, reason = UserFile.validateRelativePath(location)
    if normalized == nil then
        return nil, reason
    end
    local packageRelativePath = joinRelative(self.modelRoot, normalized)
    local fullPath, resolveReason = UserFile.resolve(packageRelativePath)
    if fullPath == nil then
        return nil, resolveReason
    end
    return {
        location = normalized,
        path = packageRelativePath,
        fullPath = fullPath,
    }
end

function ModelPackage:openExternalData(location)
    local resolved, reason = self:resolveExternalData(location)
    if resolved == nil then
        error("PZONNX external data path is unsafe: " .. tostring(reason))
    end
    return UserFile.open(resolved.path)
end

return ModelPackage
