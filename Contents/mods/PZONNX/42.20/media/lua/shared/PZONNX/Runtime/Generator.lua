local Generator = {}
Generator.__index = Generator

local function integerOption(value, name, default)
    if value == nil then return default end
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or
        value < 0 or value ~= math.floor(value) then
        error("PZONNX Generator " .. name .. " must be a non-negative integer")
    end
    return value
end

local function copy(values)
    local result = {}
    for index, value in ipairs(values or {}) do result[index] = value end
    return result
end

local function copyOptions(values)
    local result = {}
    for key, value in pairs(values or {}) do result[key] = value end
    return result
end

function Generator.new(decoder, tokenizer, sampler, options)
    assert(decoder ~= nil and type(decoder.beginPrefill) == "function",
        "PZONNX Generator requires a Decoder")
    assert(tokenizer ~= nil and type(tokenizer.encode) == "function" and
        type(tokenizer.decode) == "function", "PZONNX Generator requires a Tokenizer")
    assert(sampler ~= nil and type(sampler.sample) == "function" and
        type(sampler.shouldStop) == "function", "PZONNX Generator requires a Sampler")
    options = options or {}
    local sampleOptions = copyOptions(options.sampleOptions)
    if sampleOptions.maxNewTokens == nil then sampleOptions.maxNewTokens = options.maxNewTokens end
    sampleOptions.maxNewTokens = integerOption(sampleOptions.maxNewTokens,
        "maxNewTokens", 32)
    return setmetatable({
        decoder = decoder,
        tokenizer = tokenizer,
        sampler = sampler,
        options = options,
        sampleOptions = sampleOptions,
        defaultMaxNewTokens = sampleOptions.maxNewTokens,
        promptEncodeOptions = copyOptions(options.promptEncodeOptions),
        phase = "idle",
        prompt = nil,
        promptTokens = {},
        allTokens = {},
        generatedTokens = {},
        text = "",
        generatedText = "",
        lastSample = nil,
        stopReason = nil,
        work = 0,
    }, Generator)
end

function Generator:_result(extra)
    local result = {
        done = self.phase == "done" or self.phase == "cancelled" or self.phase == "failed",
        phase = self.phase,
        prompt = self.prompt,
        text = self.text,
        generatedText = self.generatedText,
        promptTokens = self.promptTokens,
        generatedTokens = self.generatedTokens,
        tokenId = self.lastSample and self.lastSample.tokenId or nil,
        probability = self.lastSample and self.lastSample.probability or nil,
        stopReason = self.stopReason,
        work = self.work,
    }
    for key, value in pairs(extra or {}) do result[key] = value end
    return result
end

function Generator:_refreshText()
    self.text = self.tokenizer:decode(self.allTokens)
    self.generatedText = self.tokenizer:decode(self.generatedTokens)
end

function Generator:_finish(reason)
    self.stopReason = reason
    self.phase = "done"
    return self:_result()
end

function Generator:_acceptLogits(logits)
    local sampled = self.sampler:sample(logits, self.allTokens, self.sampleOptions)
    local tokenId = sampled.tokenId
    table.insert(self.allTokens, tokenId)
    table.insert(self.generatedTokens, tokenId)
    self.lastSample = sampled
    self:_refreshText()
    local stopped, reason = self.sampler:shouldStop(tokenId, #self.generatedTokens, self.sampleOptions)
    if stopped then return self:_finish(reason) end
    self.decoder:beginDecode(tokenId)
    self.phase = "decode"
    return self:_result()
end

function Generator:begin(prompt, options)
    assert(type(prompt) == "string", "PZONNX Generator prompt must be a string")
    if self.decoder:isBusy() then error("PZONNX Generator cannot begin while inference is running") end
    self.decoder:reset()
    options = options or {}
    self.prompt = prompt
    self.promptEncodeOptions = copyOptions(options.promptEncodeOptions or self.options.promptEncodeOptions)
    self.sampleOptions = copyOptions(options.sampleOptions or self.options.sampleOptions)
    self.sampleOptions.maxNewTokens = integerOption(options.maxNewTokens or self.sampleOptions.maxNewTokens or
        self.defaultMaxNewTokens,
        "maxNewTokens", 32)
    self.promptTokens = self.tokenizer:encode(prompt, self.promptEncodeOptions)
    if #self.promptTokens == 0 then error("PZONNX Generator tokenizer produced no prompt tokens") end
    self.allTokens = copy(self.promptTokens)
    self.generatedTokens = {}
    self.text = self.tokenizer:decode(self.allTokens)
    self.generatedText = ""
    self.lastSample = nil
    self.stopReason = nil
    self.work = 0
    if self.sampleOptions.maxNewTokens == 0 then
        self.phase = "done"
        self.stopReason = "length"
        return self:_result()
    end
    self.decoder:beginPrefill(self.promptTokens)
    self.phase = "prefill"
    return self:_result()
end

function Generator:step(budget)
    if self.phase == "idle" then error("PZONNX Generator has not been started") end
    if self.phase == "done" or self.phase == "cancelled" or self.phase == "failed" then
        return self:_result()
    end
    assert(type(budget) == "number" and budget > 0 and budget == math.floor(budget),
        "PZONNX Generator.step budget must be a positive integer")
    local ok, done, result = pcall(self.decoder.step, self.decoder, budget)
    if not ok then
        self.phase = "failed"
        self.stopReason = tostring(done)
        error(done)
    end
    self.work = self.work + (result and result.work or 0)
    if not done then
        return self:_result({ cursor = result and result.cursor })
    end
    local completed = self:_acceptLogits(result.logits)
    return self:_result({ cursor = result.cursor, sequenceLength = result.sequenceLength,
        completed = completed })
end

function Generator:run(prompt, budget, limit)
    self:begin(prompt)
    local steps = 0
    local maxSteps = limit or 1000000
    while not self:_result().done do
        steps = steps + 1
        if steps > maxSteps then error("PZONNX Generator exceeded bounded step limit") end
        self:step(budget or 1)
    end
    return self:_result({ schedulerSteps = steps })
end

function Generator:cancel()
    if self.phase ~= "prefill" and self.phase ~= "decode" then return false end
    self.decoder:cancel()
    self.phase = "cancelled"
    self.stopReason = "cancelled"
    return true
end

function Generator:reset()
    if self.decoder:isBusy() then self.decoder:cancel() end
    self.decoder:reset()
    self.phase = "idle"
    self.prompt = nil
    self.promptTokens = {}
    self.allTokens = {}
    self.generatedTokens = {}
    self.text = ""
    self.generatedText = ""
    self.lastSample = nil
    self.stopReason = nil
    self.work = 0
end

function Generator:isBusy()
    return self.phase == "prefill" or self.phase == "decode"
end

function Generator:status()
    return self:_result()
end

return Generator
