local Tensor = require "PZONNX/Tensor"

local Decoder = {}
Decoder.__index = Decoder

local function contains(value, fragment)
    return string.find(string.lower(tostring(value or "")), fragment, 1, true) ~= nil
end

local function integerTokens(tokenIds)
    assert(type(tokenIds) == "table" and #tokenIds > 0,
        "PZONNX Decoder requires at least one token ID")
    local result = {}
    for index = 1, #tokenIds do
        local token = tonumber(tokenIds[index])
        assert(token ~= nil and token == math.floor(token),
            "PZONNX Decoder token IDs must be integers")
        result[index] = token
    end
    return result
end

local function shapeFromDescriptor(descriptor, sequenceLength, cacheLength)
    local shape = {}
    for index, dimension in ipairs(descriptor.dims or {}) do
        local value = dimension.value
        if value == nil then
            local parameter = string.lower(tostring(dimension.param or ""))
            if contains(parameter, "seq") or contains(parameter, "length") or contains(parameter, "cache") or
                contains(parameter, "past") then
                value = cacheLength
            elseif index == 1 then
                value = 1
            else
                error("PZONNX Decoder cannot resolve dynamic cache dimension " .. tostring(dimension.param))
            end
        end
        if value < 0 then
            error("PZONNX Decoder received a negative cache dimension")
        end
        if index == 1 and value == 0 then value = 1 end
        shape[index] = value
    end
    if #shape == 0 then error("PZONNX Decoder input has no tensor shape") end
    return shape
end

local function tokenTensor(descriptor, tokenIds)
    local shape = shapeFromDescriptor(descriptor, #tokenIds, 0)
    local count = 1
    for _, value in ipairs(shape) do count = count * value end
    if count ~= #tokenIds then
        if #shape == 2 and shape[1] == 1 then
            shape[2] = #tokenIds
        elseif #shape == 1 then
            shape[1] = #tokenIds
        else
            error("PZONNX Decoder token shape does not match sequence length")
        end
    end
    return Tensor.new(shape, tokenIds, 7)
end

local function filled(count, value)
    local values = {}
    for index = 1, count do values[index] = value end
    return values
end

local function cacheTensor(descriptor, cacheLength)
    local shape = shapeFromDescriptor(descriptor, 0, cacheLength)
    local count = 1
    for _, value in ipairs(shape) do count = count * value end
    return Tensor.new(shape, filled(count, 0), 1)
end

function Decoder.new(session, profile, options)
    assert(session ~= nil and session.model ~= nil, "PZONNX Decoder requires a Session")
    assert(type(profile) == "table", "PZONNX Decoder requires a ModelProfile")
    assert(profile.inputIds ~= nil and profile.logits ~= nil,
        "PZONNX Decoder requires generic input_ids and logits roles")
    options = options or {}
    return setmetatable({
        session = session,
        profile = profile,
        state = "ready",
        job = nil,
        cache = {},
        sequenceLength = 0,
        lastResult = nil,
        maxSequenceLength = options.maxSequenceLength or profile.contextLength,
        profiler = options.profiler,
    }, Decoder)
end

function Decoder:_buildInputs(tokenIds, cacheLength)
    local inputs = {}
    inputs[self.profile.inputIds.name] = tokenTensor(self.profile.inputIds, tokenIds)
    if self.profile.attentionMask ~= nil then
        local descriptor = self.profile.attentionMask
        local shape = shapeFromDescriptor(descriptor, self.sequenceLength + #tokenIds, cacheLength)
        local count = 1
        for index, value in ipairs(shape) do
            if index == #shape then shape[index] = self.sequenceLength + #tokenIds end
            count = count * shape[index]
        end
        inputs[descriptor.name] = Tensor.new(shape, filled(count, 1), 7)
    end
    if self.profile.positionIds ~= nil then
        local positions = {}
        for index = 1, #tokenIds do positions[index] = self.sequenceLength + index - 1 end
        inputs[self.profile.positionIds.name] = tokenTensor(self.profile.positionIds, positions)
    end

    for index, descriptor in ipairs(self.profile.cacheInputs or {}) do
        inputs[descriptor.name] = self.cache[index] or cacheTensor(descriptor, cacheLength)
    end
    return inputs
end

function Decoder:_begin(kind, tokenIds)
    if self.job ~= nil then error("PZONNX Decoder already has a running job") end
    tokenIds = integerTokens(tokenIds)
    if self.maxSequenceLength ~= nil and self.sequenceLength + #tokenIds > self.maxSequenceLength then
        error("PZONNX Decoder context length exceeded")
    end
    if kind == "decode" and self.sequenceLength == 0 then
        error("PZONNX Decoder decode requires a completed prefill")
    end
    local inputs = self:_buildInputs(tokenIds, self.sequenceLength)
    self.job = self.session:newJob(inputs)
    self.pendingKind = kind
    self.pendingTokenCount = #tokenIds
    self.state = kind == "prefill" and "prefilling" or "decoding"
    self.lastResult = nil
end

function Decoder:beginPrefill(tokenIds)
    if self.sequenceLength ~= 0 then error("PZONNX Decoder prefill requires a fresh state") end
    self:_begin("prefill", tokenIds)
end

function Decoder:beginDecode(tokenId)
    self:_begin("decode", { tokenId })
end

function Decoder:_complete(result)
    local outputs = result.outputs or {}
    local logits = outputs[self.profile.logits.name]
    if not Tensor.isTensor(logits) then
        error("PZONNX Decoder logits output is not a Tensor")
    end
    local nextCache = {}
    local outputCount = #(self.profile.cacheOutputs or {})
    local inputCount = #(self.profile.cacheInputs or {})
    if outputCount ~= inputCount then
        error("PZONNX Decoder cache input/output count mismatch")
    end
    for index, descriptor in ipairs(self.profile.cacheOutputs or {}) do
        local value = outputs[descriptor.name]
        if not Tensor.isTensor(value) then
            error("PZONNX Decoder cache output is unavailable: " .. tostring(descriptor.name))
        end
        nextCache[index] = value
    end
    self.cache = nextCache
    self.sequenceLength = self.sequenceLength + self.pendingTokenCount
    self.lastResult = {
        kind = self.pendingKind,
        logits = logits,
        outputs = outputs,
        sequenceLength = self.sequenceLength,
        cursor = result.cursor,
    }
    self.job = nil
    self.pendingKind = nil
    self.pendingTokenCount = nil
    self.state = "ready"
    return self.lastResult
end

function Decoder:step(budget)
    assert(self.job ~= nil, "PZONNX Decoder has no pending work")
    local profilerToken = self.profiler and self.profiler:begin("decoder.step", {
        state = self.state,
        sequenceLength = self.sequenceLength,
    })
    local result = self.job:step(budget or 1)
    if result.done then
        local completed = self:_complete(result)
        if profilerToken ~= nil then self.profiler:finish(profilerToken, { work = result.work or 0 }) end
        return true, completed
    end
    if profilerToken ~= nil then self.profiler:finish(profilerToken, { work = result.work or 0 }) end
    return false, {
        state = self.state,
        cursor = result.cursor,
        work = result.work,
    }
end

function Decoder:prefill(tokenIds, budget)
    self:beginPrefill(tokenIds)
    local done, result = self:step(budget or 1)
    while not done do done, result = self:step(budget or 1) end
    return result
end

function Decoder:decode(tokenId, budget)
    self:beginDecode(tokenId)
    local done, result = self:step(budget or 1)
    while not done do done, result = self:step(budget or 1) end
    return result
end

function Decoder:cancel()
    if self.job == nil then return false end
    local cancelled = self.job:cancel()
    self.job = nil
    self.state = "cancelled"
    return cancelled
end

function Decoder:reset()
    if self.job ~= nil then self.job:cancel() end
    self.job = nil
    self.cache = {}
    self.sequenceLength = 0
    self.lastResult = nil
    self.state = "ready"
end

function Decoder:isBusy()
    return self.job ~= nil
end

return Decoder
