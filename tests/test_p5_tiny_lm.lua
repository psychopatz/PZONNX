package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
local TinyLM = require "PZONNX/Adapters/TinyLM"

local file = assert(io.open("Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p5_tiny_lm.onnx", "rb"))
local data = file:read("*all")
file:close()
local bytes = {}
for i = 1, #data do
    bytes[i] = string.byte(data, i)
end

local model = Model.parseBytes(bytes)
local result = TinyLM.new(Session.new(model), "token_ids", "logits"):nextToken(1)
local expected = { 0.6, 0.4, -0.1 }
for i = 1, #expected do
    if math.abs(result.logits.data[i] - expected[i]) > 1e-6 then
        error("P5 logits mismatch at " .. tostring(i) .. ": expected=" .. tostring(expected[i]) ..
            " actual=" .. tostring(result.logits.data[i]))
    end
end
if result.tokenId ~= 0 then
    error("P5 next token mismatch expected=0 actual=" .. tostring(result.tokenId))
end
if model.compatibility.operators[1].execution ~= "supported" then
    error("P5 Gather was not reported as registry-supported")
end

print("PZONNX P5 tiny-LM one-token tests passed")
