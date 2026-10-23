package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
local Chat = require "PZONNX/Adapters/Chat"

local file = assert(io.open(
    "Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p5_tiny_lm.onnx", "rb"))
local data = file:read("*all")
file:close()
local bytes = {}
for index = 1, #data do bytes[index] = string.byte(data, index) end

local model = Model.parseBytes(bytes)
local inputs, profile = Chat.buildInputs(model, { 1 })
if profile.mode ~= "single-token" or inputs.token_ids == nil then
    error("PZONNX Chat did not build the single-token input profile")
end

local outputs = Session.new(model):run(inputs)
local result = Chat.nextToken(model, outputs)
if result.tokenId ~= 0 or math.abs(result.logit - 0.6) > 1e-6 then
    error("PZONNX Chat next-token mismatch expected=0/0.6 actual=" ..
        tostring(result.tokenId) .. "/" .. tostring(result.logit))
end

print("PZONNX Chat adapter tests passed")
