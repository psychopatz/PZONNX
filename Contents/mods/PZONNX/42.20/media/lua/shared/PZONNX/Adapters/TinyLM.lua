local Tensor = require "PZONNX/Tensor"

local TinyLM = {}
TinyLM.__index = TinyLM

function TinyLM.new(session, inputName, outputName)
    assert(session ~= nil, "PZONNX TinyLM requires a Session")
    assert(type(inputName) == "string" and inputName ~= "", "PZONNX TinyLM input name is required")
    assert(type(outputName) == "string" and outputName ~= "", "PZONNX TinyLM output name is required")
    return setmetatable({
        session = session,
        inputName = inputName,
        outputName = outputName,
    }, TinyLM)
end

function TinyLM:nextToken(tokenId)
    assert(type(tokenId) == "number" and tokenId == math.floor(tokenId),
        "PZONNX TinyLM token ID must be an integer")
    local input = Tensor.new({ 1 }, { tokenId }, 7)
    local logits = self.session:run({
        [self.inputName] = input,
    })[self.outputName]
    if #logits.shape ~= 2 or logits.shape[1] ~= 1 then
        error("PZONNX TinyLM expects logits shaped [1,vocab]")
    end

    local bestIndex = 1
    for index = 2, logits.shape[2] do
        if logits.data[index] > logits.data[bestIndex] then
            bestIndex = index
        end
    end
    return {
        tokenId = bestIndex - 1,
        logits = logits,
    }
end

return TinyLM
