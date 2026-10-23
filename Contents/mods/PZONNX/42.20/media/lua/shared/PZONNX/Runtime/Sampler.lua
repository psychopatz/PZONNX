local Tensor = require "PZONNX/Tensor"

local Sampler = {}
Sampler.__index = Sampler

local UINT32 = 4294967296

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function validateProbability(value, name)
    if not finite(value) or value <= 0 or value > 1 then
        error("PZONNX Sampler " .. name .. " must be in (0,1]")
    end
end

local function historyCounts(history)
    local counts = {}
    for _, tokenId in ipairs(history or {}) do
        counts[tokenId] = (counts[tokenId] or 0) + 1
    end
    return counts
end

local function logitsValues(logits)
    if Tensor.isTensor(logits) then
        local rank = #logits.shape
        local start = 1
        local count = logits.shape[rank]
        if rank == 1 then
            count = logits.shape[1]
        elseif rank == 2 then
            start = (logits.shape[1] - 1) * logits.shape[2] + 1
            count = logits.shape[2]
        elseif rank == 3 then
            start = (logits.shape[1] * logits.shape[2] - 1) * logits.shape[3] + 1
            count = logits.shape[3]
        else
            error("PZONNX Sampler supports rank-1, rank-2, or rank-3 logits")
        end
        local values = {}
        for index = 0, count - 1 do values[index + 1] = Tensor.valueAt(logits, start + index) end
        return values
    end
    assert(type(logits) == "table" and #logits > 0, "PZONNX Sampler requires logits")
    local values = {}
    for index = 1, #logits do values[index] = logits[index] end
    return values
end

local function sortedCandidates(values)
    local candidates = {}
    for index, logit in ipairs(values) do
        if logit ~= logit then error("PZONNX Sampler received NaN logits") end
        table.insert(candidates, { index = index, logit = logit })
    end
    table.sort(candidates, function(left, right)
        if left.logit == right.logit then return left.index < right.index end
        return left.logit > right.logit
    end)
    return candidates
end

function Sampler.new(options)
    options = options or {}
    local seed = options.seed or 1
    if not finite(seed) then error("PZONNX Sampler seed must be finite") end
    seed = math.floor(seed) % UINT32
    if seed == 0 then seed = 1 end
    return setmetatable({ seed = seed, state = seed }, Sampler)
end

function Sampler:reset(seed)
    seed = seed or self.seed
    if not finite(seed) then error("PZONNX Sampler seed must be finite") end
    self.seed = math.floor(seed) % UINT32
    if self.seed == 0 then self.seed = 1 end
    self.state = self.seed
end

function Sampler:_random()
    self.state = (self.state * 1664525 + 1013904223) % UINT32
    return self.state / UINT32
end

function Sampler:_penalize(values, history, options)
    local counts = historyCounts(history)
    local repetition = options.repetitionPenalty or 1
    local presence = options.presencePenalty or 0
    local frequency = options.frequencyPenalty or 0
    if not finite(repetition) or repetition < 1 then error("PZONNX Sampler repetitionPenalty must be >= 1") end
    if not finite(presence) or not finite(frequency) or presence < 0 or frequency < 0 then
        error("PZONNX Sampler presence/frequency penalties must be non-negative")
    end
    local adjusted = {}
    for index, logit in ipairs(values) do
        if logit == -math.huge then
            adjusted[index] = logit
        else
            local tokenId = index - 1
            local value = logit
            if counts[tokenId] ~= nil then
                if value >= 0 then value = value / repetition else value = value * repetition end
                value = value - presence - counts[tokenId] * frequency
            end
            adjusted[index] = value
        end
    end
    return adjusted
end

function Sampler:sample(logits, history, options)
    options = options or {}
    local values = self:_penalize(logitsValues(logits), history, options)
    local temperature = options.temperature
    if temperature == nil then temperature = 1 end
    if not finite(temperature) or temperature < 0 then error("PZONNX Sampler temperature must be >= 0") end
    local greedy = options.greedy == true or temperature == 0
    local candidates = sortedCandidates(values)
    if candidates[1] == nil or candidates[1].logit == -math.huge then
        error("PZONNX Sampler has no selectable finite logit")
    end

    local topK = options.topK or 0
    if not finite(topK) or topK < 0 or topK ~= math.floor(topK) then
        error("PZONNX Sampler topK must be a non-negative integer")
    end
    if topK > 0 and #candidates > topK then
        while #candidates > topK do table.remove(candidates) end
    end
    validateProbability(options.topP or 1, "topP")
    local topP = options.topP or 1

    local maximum = candidates[1].logit
    if maximum == math.huge then
        local chosen = candidates[1]
        return { tokenId = chosen.index - 1, probability = 1, mode = "infinite-greedy" }
    end
    local weighted = {}
    local total = 0
    for _, candidate in ipairs(candidates) do
        local weight = math.exp((candidate.logit - maximum) / (temperature == 0 and 1 or temperature))
        weighted[#weighted + 1] = { candidate = candidate, weight = weight }
        total = total + weight
    end
    if total <= 0 or total ~= total then error("PZONNX Sampler could not normalize logits") end

    local kept = {}
    local cumulative = 0
    for _, item in ipairs(weighted) do
        local probability = item.weight / total
        table.insert(kept, { candidate = item.candidate, probability = probability })
        cumulative = cumulative + probability
        if cumulative >= topP then break end
    end
    if greedy then
        local chosen = kept[1]
        return { tokenId = chosen.candidate.index - 1, probability = chosen.probability, mode = "greedy" }
    end

    local draw = self:_random()
    local running = 0
    for _, item in ipairs(kept) do
        running = running + item.probability / cumulative
        if draw < running or item == kept[#kept] then
            return { tokenId = item.candidate.index - 1, probability = item.probability / cumulative,
                mode = "sampled" }
        end
    end
    error("PZONNX Sampler failed to select a candidate")
end

function Sampler:shouldStop(tokenId, generatedCount, options)
    options = options or {}
    if options.maxNewTokens ~= nil then
        if not finite(options.maxNewTokens) or options.maxNewTokens < 0 or
            options.maxNewTokens ~= math.floor(options.maxNewTokens) then
            error("PZONNX Sampler maxNewTokens must be a non-negative integer")
        end
        if generatedCount >= options.maxNewTokens then return true, "length" end
    end
    local eosTokens = options.eosTokens or {}
    if options.eosToken ~= nil then table.insert(eosTokens, options.eosToken) end
    for _, eosToken in ipairs(eosTokens) do
        if tokenId == eosToken then return true, "eos" end
    end
    return false, nil
end

return Sampler
