package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
local TinyTTS = require "PZONNX/Adapters/TinyTTS"

local file = assert(io.open("Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p7_tiny_tts.onnx", "rb"))
local data = file:read("*all")
file:close()
local bytes = {}
for i = 1, #data do
    bytes[i] = string.byte(data, i)
end

local model = Model.parseBytes(bytes)
local audio = TinyTTS.new(Session.new(model), "token_ids", "pcm"):synthesize({ 1 })
local expected = { 0.5, -0.15, 0.32, 0.3 }
if audio.sampleRate ~= 16000 or #audio.pcm ~= #expected then
    error("P7 bounded PCM shape/sample-rate mismatch")
end
for i = 1, #expected do
    if math.abs(audio.pcm[i] - expected[i]) > 1e-6 then
        error("P7 PCM mismatch at " .. tostring(i))
    end
end
print("PZONNX P7 numeric TTS tests passed")
