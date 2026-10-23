package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Matrix = require "PZONNX/Models/CompatibilityMatrix"

local function profile(shape, cacheCount, tokenizer, operator)
    local cacheInputs = {}
    local cacheOutputs = {}
    for _ = 1, cacheCount do
        table.insert(cacheInputs, {})
        table.insert(cacheOutputs, {})
    end
    return {
        inputRoles = {{ role = "input_ids" }},
        outputRoles = {{ role = "logits" }},
        inputIds = { dims = shape },
        logits = { dims = {{ value = 1 }, { value = 8 }} },
        cacheInputs = cacheInputs,
        cacheOutputs = cacheOutputs,
        tokenizer = { status = tokenizer },
        requiredOperators = { operator },
    }
end

local function report(id, p, ready)
    return {
        packageId = id,
        parse = { status = "PASS" },
        profile = p,
        generationContract = { status = ready and "READY" or "INCOMPLETE" },
        executionGaps = ready and {} or { "unsupported contract fixture" },
    }
end

local first = profile({{ value = 1 }, { param = "sequence" }}, 2, "PRESENT_METADATA_ONLY", "MatMul")
local second = profile({{ value = 1 }, { param = "tokens" }}, 4, "PRESENT_METADATA_ONLY", "MatMulInteger")
local unsupported = profile({{ value = 1 }, { value = 1 }}, 0, "MISSING", "Custom")

local comparison = Matrix.compare({
    report("decoder-a", first, true),
    report("decoder-b", second, true),
    report("decoder-c", unsupported, false),
})
if comparison.packageCount ~= 3 or comparison.distinctStructuralCount ~= 3 or
        comparison.distinctCompatibleCount ~= 2 or comparison.status ~= "MULTI_FAMILY_EVIDENCE_READY" then
    error("P15 structural compatibility matrix did not distinguish generic decoder contracts")
end
local incomplete = comparison.assessments[3]
if incomplete.compatible or #incomplete.gaps == 0 then
    error("P15 unsupported family did not expose actionable compatibility gaps")
end

print("PZONNX P15 compatibility matrix tests passed")
