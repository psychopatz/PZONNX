package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Decoder = require "PZONNX/Runtime/Decoder"
local Tensor = require "PZONNX/Tensor"

local function dims(values)
    local result = {}
    for _, value in ipairs(values) do
        if type(value) == "table" then
            result[#result + 1] = { value = value[1], param = value[2] }
        else
            result[#result + 1] = { value = value, param = nil }
        end
    end
    return result
end

local profile = {
    inputIds = { name = "input_ids", dims = dims({1, {nil, "sequence_length"}}) },
    attentionMask = { name = "attention_mask", dims = dims({1, {nil, "sequence_length"}}) },
    positionIds = { name = "position_ids", dims = dims({1, {nil, "sequence_length"}}) },
    logits = { name = "logits" },
    cacheInputs = {{ name = "past_key", dims = dims({1, 1, {0, "past_sequence"}, 2}) }},
    cacheOutputs = {{ name = "present_key" }},
    contextLength = 8,
}

local seen = {}
local fakeSession = { model = { graph = {} } }
function fakeSession:newJob(inputs)
    table.insert(seen, inputs)
    local job = { calls = 0 }
    function job:step(budget)
        self.calls = self.calls + 1
        local tokenCount = inputs.input_ids.shape[2]
        local token = Tensor.valueAt(inputs.input_ids, tokenCount)
        local cache = Tensor.new({1, 1, 1, 2}, {token, token + 1}, 1)
        local logits = Tensor.new({1, 3}, {token, token + 0.5, token - 0.5}, 1)
        return {
            done = self.calls >= 2,
            cursor = self.calls,
            work = 1,
            outputs = self.calls >= 2 and { logits = logits, present_key = cache } or nil,
        }
    end
    function job:cancel()
        self.cancelled = true
        return true
    end
    return job
end

local decoder = Decoder.new(fakeSession, profile)
decoder:beginPrefill({1, 2})
local done = decoder:step(1)
if done then error("P12 decoder completed before resumable second step") end
done = decoder:step(1)
if not done then error("P12 decoder did not complete prefill") end
local prefill = decoder.lastResult
if prefill.sequenceLength ~= 2 or Tensor.valueAt(prefill.logits, 2) ~= 2.5 then
    error("P12 prefill did not preserve the final token logits")
end
if seen[1].past_key.shape[3] ~= 0 or seen[1].attention_mask.shape[2] ~= 2 then
    error("P12 prefill did not create an empty cache and full attention mask")
end

local decoded = decoder:decode(3, 1)
if decoded.sequenceLength ~= 3 or Tensor.valueAt(decoded.logits, 1) ~= 3 then
    error("P12 one-token decode did not advance the sequence")
end
if seen[2].past_key.shape[3] ~= 1 or seen[2].input_ids.shape[2] ~= 1 or
        Tensor.valueAt(seen[2].position_ids, 1) ~= 2 then
    error("P12 decode did not reuse KV state and position offset")
end
if seen[2].attention_mask.shape[2] ~= 3 then
    error("P12 decode attention mask did not include the cached sequence")
end

decoder:beginDecode(4)
if not decoder:cancel() or decoder:isBusy() then
    error("P12 decoder cancellation did not release the pending job")
end

print("PZONNX P12 decoder tests passed")
