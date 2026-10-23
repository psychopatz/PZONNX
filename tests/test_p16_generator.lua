package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Generator = require "PZONNX/Runtime/Generator"
local Sampler = require "PZONNX/Runtime/Sampler"

local tokenizer = {}
function tokenizer:encode(text)
    if text == "hello" then return { 1, 2 } end
    return { 1 }
end
function tokenizer:decode(ids)
    local names = { [1] = "hello", [2] = " ", [3] = "world", [0] = "<eos>" }
    local result = {}
    for _, id in ipairs(ids) do result[#result + 1] = names[id] or "?" end
    return table.concat(result)
end

local decoder = { sequence = 0, busy = false, nextLogits = nil }
function decoder:isBusy() return self.busy end
function decoder:reset() self.sequence = 0 self.busy = false end
function decoder:beginPrefill(tokens)
    self.sequence = #tokens
    self.busy = true
    self.nextLogits = { 0, 0, 0, 4 }
end
function decoder:beginDecode(token)
    self.sequence = self.sequence + 1
    self.busy = true
    self.nextLogits = { 0, 0, 0, 4 }
end
function decoder:step()
    self.busy = false
    return true, { logits = self.nextLogits, sequenceLength = self.sequence, work = 1, cursor = self.sequence }
end
function decoder:cancel() self.busy = false return true end

local generator = Generator.new(decoder, tokenizer, Sampler.new({ seed = 7 }), {
    maxNewTokens = 3,
    sampleOptions = { greedy = true, eosTokens = { 0 } },
})
local started = generator:begin("hello")
if started.phase ~= "prefill" or started.text ~= "hello " then error("P16 did not start generic prefill") end
local first = generator:step(1)
if first.tokenId ~= 3 or first.phase ~= "decode" then error("P16 did not sample the prefill logits") end
local second = generator:step(1)
if second.tokenId ~= 3 or second.phase ~= "decode" then error("P16 did not continue one-token decode") end
local third = generator:step(1)
if not third.done or third.stopReason ~= "length" or third.generatedText ~= "worldworldworld" then
    error("P16 did not stop at the configured generation length")
end

generator:begin("hello")
if not generator:cancel() or generator:status().phase ~= "cancelled" then
    error("P16 generator cancellation did not release the decoder")
end

local zero = Generator.new(decoder, tokenizer, Sampler.new(), { maxNewTokens = 0 })
if not zero:begin("hello").done or zero:status().stopReason ~= "length" then
    error("P16 zero-length generation did not stop explicitly")
end

print("PZONNX P16 generator tests passed")
