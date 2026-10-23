package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local ModelProfile = require "PZONNX/Models/ModelProfile"
local ModelProbe = require "PZONNX/Models/ModelProbe"

local package = {
    id = "generic/model.onnx",
    modelPath = "generic/model.onnx",
}
local originalInspect = ModelProfile.inspect
ModelProfile.inspect = function(modelPackage)
    return {
        packageId = modelPackage.id,
        modelPath = modelPackage.modelPath,
        opsets = {{ domain = "", version = 18 }},
        requiredDatatypes = { 1, 3 },
        tokenizer = { status = "MISSING" },
        inputIds = nil,
        logits = nil,
        pastKeyPattern = nil,
        pastValuePattern = nil,
        presentKeyPattern = nil,
        presentValuePattern = nil,
        externalData = { diagnostics = {} },
        compatibility = {
            operators = {{ opType = "MatMul", execution = "supported" }},
            unsupported = { "custom operator is not registered" },
        },
    }
end

local incomplete = ModelProbe.probe(package)
ModelProfile.inspect = originalInspect
if incomplete.parse.status ~= "PASS" or incomplete.generationContract.status ~= "INCOMPLETE" then
    error("P9D did not report an incomplete generation contract")
end
if #incomplete.executionGaps < 4 or #incomplete.opsets ~= 1 or #incomplete.operators ~= 1 then
    error("P9D did not aggregate compatibility and contract gaps")
end

local forwardCalled = false
local originalInspectAgain = ModelProfile.inspect
ModelProfile.inspect = function()
    return {
        opsets = {},
        requiredDatatypes = {},
        tokenizer = { status = "PRESENT_METADATA_ONLY" },
        inputIds = { name = "input_ids" },
        logits = { name = "logits" },
        pastKeyPattern = "past.key",
        pastValuePattern = "past.value",
        presentKeyPattern = "present.key",
        presentValuePattern = "present.value",
        externalData = { diagnostics = {} },
        compatibility = { operators = {}, unsupported = {} },
    }
end
local complete = ModelProbe.probe(package, {
    forwardPass = function(modelPackage, profile)
        forwardCalled = modelPackage == package and profile.inputIds.name == "input_ids"
        return { bounded = true }
    end,
})
ModelProfile.inspect = originalInspectAgain
if complete.generationContract.status ~= "READY" or not complete.generationContract.supported or
        complete.forwardPass.status ~= "PASS" or not forwardCalled then
    error("P9D did not expose opt-in bounded forward evidence")
end

local originalInspectFailure = ModelProfile.inspect
ModelProfile.inspect = function() error("synthetic parse failure") end
local failed = ModelProbe.probe(package)
ModelProfile.inspect = originalInspectFailure
if failed.parse.status ~= "FAILED" or #failed.executionGaps ~= 1 then
    error("P9D did not preserve parse failure diagnostics")
end

print("PZONNX P9D model probe tests passed")
