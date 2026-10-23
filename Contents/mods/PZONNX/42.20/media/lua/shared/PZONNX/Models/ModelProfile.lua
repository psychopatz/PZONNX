local Model = require "PZONNX/ONNX/Model"
local ModelStore = require "PZONNX/Models/ModelStore"
local ModelPackage = require "PZONNX/Models/ModelPackage"
local UserFile = require "PZONNX/IO/UserFile"

local ModelProfile = {}

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function contains(value, fragment)
    return string.find(lower(value), fragment, 1, true) ~= nil
end

local function uniqueInsert(values, seen, value)
    if value ~= nil and not seen[value] then
        seen[value] = true
        table.insert(values, value)
    end
end

local function trim(value)
    return string.gsub(string.gsub(value, "^%s+", ""), "%s+$", "")
end

local function jsonFieldStart(text, key)
    local quoted = '"' .. key .. '"'
    local keyStart = string.find(text, quoted, 1, true)
    if keyStart == nil then
        return nil
    end
    local colon = string.find(text, ":", keyStart + #quoted, true)
    if colon == nil then
        return nil
    end
    local valueStart = colon + 1
    while valueStart <= #text and string.find(" \t\r\n", string.sub(text, valueStart, valueStart), 1, true) ~= nil do
        valueStart = valueStart + 1
    end
    return valueStart
end

local function jsonString(text, key)
    local start = jsonFieldStart(text, key)
    if start == nil or string.sub(text, start, start) ~= '"' then
        return nil
    end
    local result = {}
    local escaped = false
    for index = start + 1, #text do
        local character = string.sub(text, index, index)
        if escaped then
            if character == "n" then
                table.insert(result, "\n")
            elseif character == "r" then
                table.insert(result, "\r")
            elseif character == "t" then
                table.insert(result, "\t")
            else
                table.insert(result, character)
            end
            escaped = false
        elseif character == "\\" then
            escaped = true
        elseif character == '"' then
            return table.concat(result)
        else
            table.insert(result, character)
        end
    end
    return nil
end

local function jsonNumber(text, key)
    local start = jsonFieldStart(text, key)
    if start == nil then
        return nil
    end
    local token = string.match(string.sub(text, start), "^[%-]?[%d]+%.?[%d]*")
    if token == nil then
        return nil
    end
    return tonumber(token)
end

local function jsonStringArray(text, key)
    local start = jsonFieldStart(text, key)
    if start == nil or string.sub(text, start, start) ~= "[" then
        return nil
    end
    local close = string.find(text, "]", start + 1, true)
    if close == nil then
        return nil
    end
    local values = {}
    for value in string.gmatch(string.sub(text, start + 1, close - 1), '"([^"\\]*)"') do
        table.insert(values, value)
    end
    return values
end

local function jsonNumberOrArray(text, key)
    local start = jsonFieldStart(text, key)
    if start == nil then
        return nil
    end
    if string.sub(text, start, start) ~= "[" then
        return jsonNumber(text, key)
    end
    local close = string.find(text, "]", start + 1, true)
    if close == nil then
        return nil
    end
    local values = {}
    for token in string.gmatch(string.sub(text, start + 1, close - 1), "[%-]?[%d]+%.?[%d]*") do
        table.insert(values, tonumber(token))
    end
    return values
end

local function readJsonCompanion(modelPackage, name)
    local text, reason = modelPackage:readCompanionText(name)
    if text == nil then
        return nil, reason
    end
    return {
        name = name,
        text = text,
    }
end

local function valueInfoDescriptor(valueInfo, role)
    local descriptor = {
        name = valueInfo.name,
        role = role,
        elemType = nil,
        dims = {},
    }
    if valueInfo.type ~= nil and valueInfo.type.kind == "tensor" and valueInfo.type.tensor ~= nil then
        descriptor.elemType = valueInfo.type.tensor.elemType
        local shape = valueInfo.type.tensor.shape
        if shape ~= nil then
            for _, dimension in ipairs(shape.dims) do
                table.insert(descriptor.dims, {
                    value = dimension.value,
                    param = dimension.param,
                })
            end
        end
    end
    return descriptor
end

local function roleForName(name, direction)
    local value = lower(name)
    if contains(value, "input_ids") or contains(value, "inputids") or
            value == "ids" or contains(value, "token_ids") then
        return "input_ids"
    end
    if contains(value, "attention_mask") or contains(value, "attentionmask") then
        return "attention_mask"
    end
    if contains(value, "position_ids") or contains(value, "positionids") then
        return "position_ids"
    end
    if contains(value, "past") and contains(value, "key") then
        return "past_key"
    end
    if contains(value, "past") and contains(value, "value") then
        return "past_value"
    end
    if contains(value, "present") and contains(value, "key") then
        return "present_key"
    end
    if contains(value, "present") and contains(value, "value") then
        return "present_value"
    end
    if direction == "output" and (value == "logits" or contains(value, "logits")) then
        return "logits"
    end
    return "unknown"
end

local function collectValueInfos(values, direction, profile)
    local result = {}
    for _, valueInfo in ipairs(values) do
        local role = roleForName(valueInfo.name, direction)
        local descriptor = valueInfoDescriptor(valueInfo, role)
        table.insert(result, descriptor)
        if role == "input_ids" then profile.inputIds = descriptor end
        if role == "attention_mask" then profile.attentionMask = descriptor end
        if role == "position_ids" then profile.positionIds = descriptor end
        if role == "logits" then profile.logits = descriptor end
        if role == "past_key" then profile.pastKeyPattern = descriptor.name end
        if role == "past_value" then profile.pastValuePattern = descriptor.name end
        if role == "present_key" then profile.presentKeyPattern = descriptor.name end
        if role == "present_value" then profile.presentValuePattern = descriptor.name end
        if role == "past_key" or role == "past_value" then table.insert(profile.cacheInputs, descriptor) end
        if role == "present_key" or role == "present_value" then table.insert(profile.cacheOutputs, descriptor) end
    end
    return result
end

local function graphEvidence(model, profile)
    local operatorNames = {}
    local operatorSeen = {}
    for _, node in ipairs(model.graph.nodes) do
        uniqueInsert(operatorNames, operatorSeen, node.domain .. ":" .. node.opType)
    end
    profile.requiredOperators = operatorNames

    local datatypeValues = {}
    local datatypeSeen = {}
    for _, datatype in ipairs(model.compatibility.datatypes) do
        uniqueInsert(datatypeValues, datatypeSeen, datatype)
    end
    profile.requiredDatatypes = datatypeValues
    profile.detectionEvidence.graph = {
        graphName = model.graph.name,
        nodeCount = #model.graph.nodes,
        inputCount = #model.graph.inputs,
        outputCount = #model.graph.outputs,
    }
end

local function configEvidence(modelPackage, profile)
    local config = readJsonCompanion(modelPackage, "config.json")
    local generation = readJsonCompanion(modelPackage, "generation_config.json")
    local sources = {}
    if config ~= nil then table.insert(sources, config) end
    if generation ~= nil then table.insert(sources, generation) end

    for _, source in ipairs(sources) do
        local text = source.text
        local modelType = jsonString(text, "model_type")
        local architectures = jsonStringArray(text, "architectures")
        if profile.architecture == nil and modelType ~= nil then
            profile.architecture = modelType
            profile.detectionEvidence.architecture = "config:" .. source.name .. ":model_type"
        end
        if profile.architecture == nil and architectures ~= nil and #architectures > 0 then
            profile.architecture = architectures[1]
            profile.detectionEvidence.architecture = "config:" .. source.name .. ":architectures"
        end
        if profile.task == nil then
            profile.task = jsonString(text, "task")
            if profile.task ~= nil then
                profile.detectionEvidence.task = "config:" .. source.name
            end
        end
        if profile.contextLength == nil then
            profile.contextLength = jsonNumber(text, "max_position_embeddings") or
                jsonNumber(text, "max_sequence_length") or jsonNumber(text, "n_positions")
            if profile.contextLength ~= nil then
                profile.detectionEvidence.contextLength = "config:" .. source.name
            end
        end
        if profile.vocabSize == nil then
            profile.vocabSize = jsonNumber(text, "vocab_size")
            if profile.vocabSize ~= nil then
                profile.detectionEvidence.vocabSize = "config:" .. source.name
            end
        end
        if profile.bosToken == nil then profile.bosToken = jsonNumber(text, "bos_token_id") end
        if profile.padToken == nil then profile.padToken = jsonNumber(text, "pad_token_id") end
        if profile.eosTokens == nil then
            local eosToken = jsonNumberOrArray(text, "eos_token_id")
            if type(eosToken) == "number" then
                profile.eosTokens = { eosToken }
            else
                profile.eosTokens = eosToken
            end
        end
        if profile.bosToken ~= nil or profile.padToken ~= nil or profile.eosTokens ~= nil then
            profile.detectionEvidence.tokens = "config:" .. source.name
        end
    end
    profile.detectionEvidence.config = {
        present = config ~= nil,
        generationPresent = generation ~= nil,
    }
end

local function tokenizerEvidence(modelPackage, profile)
    local names = {
        "tokenizer.json",
        "tokenizer_config.json",
        "special_tokens_map.json",
        "vocab.json",
        "merges.txt",
        "tokenizer.model",
        "spiece.model",
    }
    local files = {}
    local present = 0
    for _, name in ipairs(names) do
        local companion = modelPackage:getCompanion(name)
        files[name] = companion.status
        if companion.present then present = present + 1 end
    end
    profile.tokenizer = {
        status = present > 0 and "PRESENT_METADATA_ONLY" or "MISSING",
        files = files,
        decoded = false,
    }
    profile.detectionEvidence.tokenizer = "known_companion_probe"
end

local function externalDataEvidence(modelPackage, model, profile)
    local files = {}
    local diagnostics = {}
    for _, initializer in ipairs(model.graph.initializers) do
        if initializer.dataLocation == 1 then
            for _, pair in ipairs(initializer.externalData) do
                if pair.key == "location" then
                    local resolved, reason = modelPackage:resolveExternalData(pair.value)
                    if resolved == nil then
                        table.insert(diagnostics, {
                            initializer = initializer.name,
                            location = pair.value,
                            reason = reason,
                        })
                    elseif files[resolved.path] == nil then
                        local present, existsReason = UserFile.exists(resolved.path)
                        files[resolved.path] = {
                            location = resolved.location,
                            path = resolved.path,
                            fullPath = resolved.fullPath,
                            status = present and "PRESENT" or "MISSING",
                            reason = present and nil or existsReason,
                        }
                    end
                end
            end
        end
    end
    local fileList = {}
    for _, file in pairs(files) do table.insert(fileList, file) end
    profile.externalData = {
        required = #fileList > 0 or #diagnostics > 0,
        files = fileList,
        diagnostics = diagnostics,
    }
end

local function calculateConfidence(profile)
    local score = 0
    if profile.architecture ~= nil then score = score + 0.2 end
    if profile.inputIds ~= nil then score = score + 0.2 end
    if profile.logits ~= nil then score = score + 0.2 end
    if profile.tokenizer.status == "PRESENT_METADATA_ONLY" then score = score + 0.15 end
    if profile.contextLength ~= nil then score = score + 0.1 end
    if profile.vocabSize ~= nil then score = score + 0.1 end
    if profile.pastKeyPattern ~= nil and profile.presentKeyPattern ~= nil then score = score + 0.05 end
    return score
end

function ModelProfile.inspect(modelPackage)
    assert(type(modelPackage) == "table" and modelPackage.withModelReader ~= nil,
        "PZONNX ModelProfile.inspect requires a ModelPackage")
    local model = modelPackage:withModelReader(function(reader)
        return Model.parseReader(reader)
    end)
    local profile = {
        packageId = modelPackage.id,
        modelPath = modelPackage.modelPath,
        irVersion = model.irVersion,
        producerName = model.producerName,
        producerVersion = model.producerVersion,
        opsets = {},
        modelFiles = {
            primary = modelPackage.fullModelPath,
        },
        task = nil,
        architecture = nil,
        inputRoles = {},
        outputRoles = {},
        inputIds = nil,
        attentionMask = nil,
        positionIds = nil,
        logits = nil,
        pastKeyPattern = nil,
        pastValuePattern = nil,
        presentKeyPattern = nil,
        presentValuePattern = nil,
        cacheInputs = {},
        cacheOutputs = {},
        layerCount = nil,
        contextLength = nil,
        vocabSize = nil,
        bosToken = nil,
        eosTokens = nil,
        padToken = nil,
        tokenizer = nil,
        externalData = nil,
        requiredOperators = {},
        requiredDatatypes = {},
        compatibility = model.compatibility,
        detectionEvidence = {},
        confidence = 0,
        unknown = {},
    }

    configEvidence(modelPackage, profile)
    profile.inputRoles = collectValueInfos(model.graph.inputs, "input", profile)
    profile.outputRoles = collectValueInfos(model.graph.outputs, "output", profile)
    graphEvidence(model, profile)
    tokenizerEvidence(modelPackage, profile)
    externalDataEvidence(modelPackage, model, profile)
    for _, opset in ipairs(model.opsetImports) do
        table.insert(profile.opsets, {
            domain = opset.domain,
            version = opset.version,
        })
    end

    if profile.task == nil then table.insert(profile.unknown, "task") end
    if profile.architecture == nil then table.insert(profile.unknown, "architecture") end
    if profile.inputIds == nil then table.insert(profile.unknown, "inputIds") end
    if profile.logits == nil then table.insert(profile.unknown, "logits") end
    if profile.contextLength == nil then table.insert(profile.unknown, "contextLength") end
    if profile.vocabSize == nil then table.insert(profile.unknown, "vocabSize") end
    if profile.layerCount == nil then table.insert(profile.unknown, "layerCount") end
    if profile.eosTokens == nil then table.insert(profile.unknown, "eosTokens") end
    profile.confidence = calculateConfidence(profile)
    return profile
end

function ModelProfile.forEntry(idOrPath)
    local modelPackage, reason = ModelPackage.forEntry(idOrPath)
    if modelPackage == nil then
        return nil, reason
    end
    return ModelProfile.inspect(modelPackage)
end

return ModelProfile
