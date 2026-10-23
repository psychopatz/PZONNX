local Pipeline = {}
Pipeline.__index = Pipeline

local function copy(values)
    local result = {}
    for key, value in pairs(values or {}) do result[key] = value end
    return result
end

function Pipeline.new(generator, options)
    assert(generator ~= nil and type(generator.begin) == "function" and
        type(generator.step) == "function", "PZONNX Pipeline requires a Generator")
    options = options or {}
    return setmetatable({
        generator = generator,
        tts = options.tts,
        options = options,
        phase = "idle",
        text = "",
        audio = nil,
        stopReason = nil,
        errorMessage = nil,
        wantAudio = false,
        work = 0,
    }, Pipeline)
end

function Pipeline:_result(extra)
    local result = {
        done = self.phase == "done" or self.phase == "cancelled" or self.phase == "failed",
        phase = self.phase,
        text = self.text,
        audio = self.audio,
        stopReason = self.stopReason,
        errorMessage = self.errorMessage,
        work = self.work,
    }
    for key, value in pairs(extra or {}) do result[key] = value end
    return result
end

function Pipeline:_beginAudio(options)
    if self.tts == nil or type(self.tts.begin) ~= "function" or
        type(self.tts.step) ~= "function" then
        error("PZONNX Pipeline audio was requested but no bounded TTS provider is attached")
    end
    local result = self.tts:begin(self.text, copy(options or {}))
    self.phase = "audio"
    if type(result) == "table" and result.done then
        self.audio = result.audio
        self.phase = "done"
    end
end

function Pipeline:begin(prompt, options)
    if self:isBusy() then error("PZONNX Pipeline cannot begin while work is running") end
    options = options or {}
    self.audio = nil
    self.text = ""
    self.stopReason = nil
    self.errorMessage = nil
    self.work = 0
    self.wantAudio = options.audio == true
    self.audioOptions = copy(options.audioOptions)
    local result = self.generator:begin(prompt, options)
    self.phase = "generating"
    if result.done then
        self.text = result.generatedText or result.text or ""
        self.stopReason = result.stopReason
        if self.wantAudio then self:_beginAudio(self.audioOptions) else self.phase = "done" end
    end
    return self:_result({ generator = result })
end

function Pipeline:step(budget)
    if self.phase == "idle" then error("PZONNX Pipeline has not been started") end
    if self.phase == "done" or self.phase == "cancelled" or self.phase == "failed" then
        return self:_result()
    end
    local ok, result = pcall(function()
        if self.phase == "generating" then
            local generation = self.generator:step(budget)
            self.work = self.work + (generation.work or 0)
            if generation.done then
                self.text = generation.generatedText or generation.text or ""
                self.stopReason = generation.stopReason
                if self.wantAudio then
                    self:_beginAudio(self.audioOptions)
                else
                    self.phase = "done"
                end
            end
            return { generator = generation }
        end

        local done, audioResult = self.tts:step(budget)
        if done then
            self.audio = audioResult and (audioResult.audio or audioResult) or nil
            self.phase = "done"
        end
        return { tts = audioResult }
    end)
    if not ok then
        self.phase = "failed"
        self.errorMessage = tostring(result)
        error(result)
    end
    return self:_result(result)
end

function Pipeline:run(prompt, budget, options, limit)
    self:begin(prompt, options)
    local steps = 0
    local maxSteps = limit or 1000000
    while not self:_result().done do
        steps = steps + 1
        if steps > maxSteps then error("PZONNX Pipeline exceeded bounded step limit") end
        self:step(budget or 1)
    end
    return self:_result({ schedulerSteps = steps })
end

function Pipeline:cancel()
    if self.phase == "generating" then
        self.generator:cancel()
    elseif self.phase == "audio" and self.tts.cancel ~= nil then
        self.tts:cancel()
    else
        return false
    end
    self.phase = "cancelled"
    self.stopReason = "cancelled"
    return true
end

function Pipeline:reset()
    if self.phase == "generating" then self.generator:cancel() end
    if self.phase == "audio" and self.tts ~= nil and self.tts.cancel ~= nil then self.tts:cancel() end
    self.generator:reset()
    self.phase = "idle"
    self.text = ""
    self.audio = nil
    self.stopReason = nil
    self.errorMessage = nil
    self.wantAudio = false
    self.work = 0
end

function Pipeline:isBusy()
    return self.phase == "generating" or self.phase == "audio"
end

function Pipeline:status()
    return self:_result()
end

return Pipeline
