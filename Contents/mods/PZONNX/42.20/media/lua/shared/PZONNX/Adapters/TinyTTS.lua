local Tensor = require "PZONNX/Tensor"

local TinyTTS = {}
TinyTTS.__index = TinyTTS

function TinyTTS.new(session, inputName, outputName)
    assert(session ~= nil, "PZONNX TinyTTS requires a Session")
    return setmetatable({
        session = session,
        inputName = inputName,
        outputName = outputName,
    }, TinyTTS)
end

function TinyTTS:synthesize(tokenIds)
    assert(type(tokenIds) == "table" and #tokenIds == 1,
        "PZONNX TinyTTS bounded proof accepts exactly one precomputed token ID")
    local input = Tensor.new({ 1 }, { tokenIds[1] }, 7)
    local output = self.session:run({ [self.inputName] = input })[self.outputName]
    if #output.shape ~= 2 or output.shape[1] ~= 1 then
        error("PZONNX TinyTTS expects PCM shaped [1,samples]")
    end
    local pcm = {}
    for i = 1, #output.data do
        pcm[i] = output.data[i]
    end
    return {
        sampleRate = 16000,
        pcm = pcm,
    }
end

return TinyTTS
