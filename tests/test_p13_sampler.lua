package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Sampler = require "PZONNX/Runtime/Sampler"
local Tensor = require "PZONNX/Tensor"

local greedy = Sampler.new({ seed = 7 }):sample({ 0, 1, 2 }, {}, { greedy = true })
if greedy.tokenId ~= 2 or greedy.mode ~= "greedy" then
    error("P13 greedy sampling selected the wrong token")
end

local topK = Sampler.new({ seed = 7 }):sample({ 0, 1, 2 }, {}, { topK = 1 })
if topK.tokenId ~= 2 then error("P13 top-k filtering changed the best candidate") end

local penalty = Sampler.new({ seed = 7 }):sample({ 2, 1 }, { 0 }, { greedy = true, repetitionPenalty = 3 })
if penalty.tokenId ~= 1 then error("P13 repetition penalty did not affect a seen token") end

local tensor = Tensor.new({1, 1, 3}, {0, 1, 2})
local tensorSample = Sampler.new({ seed = 7 }):sample(tensor, {}, { greedy = true })
if tensorSample.tokenId ~= 2 then error("P13 tensor logits extraction selected the wrong row") end

local first = Sampler.new({ seed = 42 }):sample({ 0, 0, 0 }, {}, { temperature = 1 })
local secondSampler = Sampler.new({ seed = 42 })
local second = secondSampler:sample({ 0, 0, 0 }, {}, { temperature = 1 })
if first.tokenId ~= second.tokenId or first.probability ~= second.probability then
    error("P13 seeded sampling was not deterministic")
end

local stopped, reason = secondSampler:shouldStop(2, 1, { eosTokens = {2} })
if not stopped or reason ~= "eos" then error("P13 EOS stopping was not reported") end
stopped, reason = secondSampler:shouldStop(4, 3, { maxNewTokens = 3 })
if not stopped or reason ~= "length" then error("P13 length stopping was not reported") end

local function mustFail(callback, message)
    if pcall(callback) then error(message) end
end
mustFail(function() Sampler.new():sample({0 / 0, 1}, {}) end, "P13 accepted NaN logits")
mustFail(function() Sampler.new():sample({0, 1}, {}, { topP = 0 }) end, "P13 accepted invalid top-p")
mustFail(function() Sampler.new():sample({0, 1}, {}, { temperature = -1 }) end,
    "P13 accepted invalid temperature")

print("PZONNX P13 sampler tests passed")
