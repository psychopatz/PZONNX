package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Pipeline = require "PZONNX/Runtime/Pipeline"

local generator = { busy = false }
function generator:begin(prompt)
    self.busy = true
    return { done = false, phase = "prefill", prompt = prompt }
end
function generator:step()
    self.busy = false
    return { done = true, generatedText = "hello survivor", stopReason = "length", work = 2 }
end
function generator:isBusy() return self.busy end
function generator:cancel() self.busy = false return true end
function generator:reset() self.busy = false end

local tts = { busy = false, text = nil }
function tts:begin(text)
    self.busy = true
    self.text = text
end
function tts:step()
    self.busy = false
    return true, { audio = { sampleRate = 16000, pcm = { 0.1, -0.1 } }, text = self.text }
end
function tts:cancel() self.busy = false return true end

local pipeline = Pipeline.new(generator, { tts = tts })
local started = pipeline:begin("say hello", { audio = true })
if started.phase ~= "generating" or not pipeline:isBusy() then
    error("P17 pipeline did not start the generation stage")
end
local generated = pipeline:step(1)
if generated.phase ~= "audio" or generated.text ~= "hello survivor" then
    error("P17 pipeline did not transition from text generation to TTS")
end
local finished = pipeline:step(1)
if not finished.done or finished.phase ~= "done" or finished.audio.sampleRate ~= 16000 or
        finished.audio.pcm[1] ~= 0.1 then
    error("P17 pipeline did not expose bounded audio output")
end

pipeline:begin("cancel me")
if not pipeline:cancel() or pipeline:status().phase ~= "cancelled" then
    error("P17 pipeline cancellation did not release generation")
end

local noAudio = Pipeline.new(generator)
noAudio:begin("text only")
local textResult = noAudio:step(1)
if not textResult.done or textResult.text ~= "hello survivor" or textResult.audio ~= nil then
    error("P17 text-only pipeline changed the generated text contract")
end

local missingTTS = Pipeline.new(generator)
missingTTS:begin("audio unavailable", { audio = true })
local ok = pcall(missingTTS.step, missingTTS, 1)
if ok or missingTTS:status().phase ~= "failed" then
    error("P17 missing TTS provider was not rejected explicitly")
end

print("PZONNX P17 pipeline tests passed")
