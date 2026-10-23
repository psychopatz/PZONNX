local CompatibilityMatrix = {}

local function sortedKeys(values)
    local result = {}
    for key in pairs(values or {}) do table.insert(result, key) end
    table.sort(result)
    return result
end

local function roleSet(profile)
    local roles = {}
    for _, input in ipairs(profile.inputRoles or {}) do roles["in:" .. tostring(input.role)] = true end
    for _, output in ipairs(profile.outputRoles or {}) do roles["out:" .. tostring(output.role)] = true end
    return table.concat(sortedKeys(roles), ",")
end

local function operatorSet(profile)
    local operators = {}
    for _, operator in ipairs(profile.requiredOperators or {}) do operators[operator] = true end
    return table.concat(sortedKeys(operators), ",")
end

function CompatibilityMatrix.structuralSignature(profile)
    assert(type(profile) == "table", "PZONNX compatibility signature requires a profile")
    local firstInput = profile.inputIds
    local firstLogits = profile.logits
    return table.concat({
        roleSet(profile),
        operatorSet(profile),
        tostring(firstInput and #firstInput.dims or 0),
        tostring(firstLogits and #firstLogits.dims or 0),
        tostring(#(profile.cacheInputs or {})),
        tostring(#(profile.cacheOutputs or {})),
        tostring(profile.tokenizer and profile.tokenizer.status or "unknown"),
    }, "|")
end

function CompatibilityMatrix.assess(report)
    assert(type(report) == "table", "PZONNX compatibility assessment requires a probe report")
    local gaps = {}
    if report.parse == nil or report.parse.status ~= "PASS" then
        table.insert(gaps, "parse did not pass")
    end
    if report.profile == nil then table.insert(gaps, "profile is unavailable") end
    if report.generationContract == nil or report.generationContract.status ~= "READY" then
        table.insert(gaps, "generation contract is incomplete")
    end
    for _, gap in ipairs(report.executionGaps or {}) do table.insert(gaps, gap) end
    return {
        status = #gaps == 0 and "COMPATIBLE" or "INCOMPLETE",
        compatible = #gaps == 0,
        signature = report.profile and CompatibilityMatrix.structuralSignature(report.profile) or nil,
        gaps = gaps,
        packageId = report.packageId,
    }
end

function CompatibilityMatrix.compare(reports)
    assert(type(reports) == "table", "PZONNX compatibility comparison requires reports")
    local assessments = {}
    local signatures = {}
    local readySignatures = {}
    for _, report in ipairs(reports) do
        local assessment = CompatibilityMatrix.assess(report)
        table.insert(assessments, assessment)
        if assessment.signature ~= nil then
            signatures[assessment.signature] = true
            if assessment.compatible then readySignatures[assessment.signature] = true end
        end
    end
    local distinct = 0
    for _ in pairs(signatures) do distinct = distinct + 1 end
    local distinctReady = 0
    for _ in pairs(readySignatures) do distinctReady = distinctReady + 1 end
    return {
        assessments = assessments,
        packageCount = #reports,
        distinctStructuralCount = distinct,
        distinctCompatibleCount = distinctReady,
        status = distinctReady >= 2 and "MULTI_FAMILY_EVIDENCE_READY" or "PARTIAL",
    }
end

return CompatibilityMatrix
