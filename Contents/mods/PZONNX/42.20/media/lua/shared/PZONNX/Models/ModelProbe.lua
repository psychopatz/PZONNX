local ModelProfile = require "PZONNX/Models/ModelProfile"

local ModelProbe = {}

local function appendAll(target, values)
    for _, value in ipairs(values or {}) do
        table.insert(target, value)
    end
end

local function generationContract(profile)
    local gaps = {}
    if profile.inputIds == nil then table.insert(gaps, "input_ids role was not detected") end
    if profile.logits == nil then table.insert(gaps, "logits output role was not detected") end
    if profile.tokenizer == nil or profile.tokenizer.status == "MISSING" then
        table.insert(gaps, "tokenizer metadata is missing")
    end
    if profile.pastKeyPattern == nil or profile.presentKeyPattern == nil then
        table.insert(gaps, "KV cache input/output pattern is unknown")
    end

    local status = "READY"
    if #gaps > 0 then
        status = "INCOMPLETE"
    end
    return {
        status = status,
        supported = status == "READY",
        gaps = gaps,
        tokenizer = profile.tokenizer,
        inputIds = profile.inputIds,
        logits = profile.logits,
        pastKeyPattern = profile.pastKeyPattern,
        pastValuePattern = profile.pastValuePattern,
        presentKeyPattern = profile.presentKeyPattern,
        presentValuePattern = profile.presentValuePattern,
    }
end

function ModelProbe.probe(modelPackage, options)
    assert(type(modelPackage) == "table", "PZONNX ModelProbe requires a ModelPackage")
    options = options or {}
    local report = {
        packageId = modelPackage.id,
        modelPath = modelPackage.modelPath,
        parse = {
            status = "NOT_RUN",
            error = nil,
        },
        profile = nil,
        opsets = {},
        operators = {},
        datatypes = {},
        externalData = nil,
        tokenizer = nil,
        generationContract = {
            status = "NOT_RUN",
            supported = false,
            gaps = { "profile parse was not completed" },
        },
        executionGaps = {},
        forwardPass = {
            status = "NOT_RUN",
            evidence = nil,
        },
    }

    local ok, profileOrError = pcall(ModelProfile.inspect, modelPackage)
    if not ok then
        report.parse.status = "FAILED"
        report.parse.error = tostring(profileOrError)
        table.insert(report.executionGaps, "model/profile parse failed")
        return report
    end

    local profile = profileOrError
    report.parse.status = "PASS"
    report.profile = profile
    report.opsets = profile.opsets or {}
    report.operators = profile.compatibility.operators or {}
    report.datatypes = profile.requiredDatatypes or {}
    report.externalData = profile.externalData
    report.tokenizer = profile.tokenizer
    report.generationContract = generationContract(profile)
    appendAll(report.executionGaps, profile.compatibility.unsupported)
    appendAll(report.executionGaps, report.generationContract.gaps)
    if report.externalData ~= nil then
        appendAll(report.executionGaps, report.externalData.diagnostics)
    end

    if type(options.forwardPass) == "function" then
        local forwardOk, evidence = pcall(options.forwardPass, modelPackage, profile)
        if forwardOk then
            report.forwardPass.status = "PASS"
            report.forwardPass.evidence = evidence
        else
            report.forwardPass.status = "FAILED"
            report.forwardPass.evidence = tostring(evidence)
            table.insert(report.executionGaps, "bounded forward-pass evidence failed")
        end
    end
    return report
end

function ModelProbe.forEntry(idOrPath, options)
    local ModelPackage = require "PZONNX/Models/ModelPackage"
    local modelPackage, reason = ModelPackage.forEntry(idOrPath)
    if modelPackage == nil then
        return nil, reason
    end
    return ModelProbe.probe(modelPackage, options)
end

return ModelProbe
