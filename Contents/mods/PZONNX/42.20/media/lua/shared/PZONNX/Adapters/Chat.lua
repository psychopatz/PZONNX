local Tensor = require "PZONNX/Tensor"

local Chat = {}

local function valueInfo(model, name)
    for index = 1, #model.graph.inputs do
        local value = model.graph.inputs[index]
        if value.name == name then return value end
    end
    return nil
end

local function dimensionValue(dimension)
    if dimension == nil then return nil end
    return dimension.value
end

local function shapeOf(value)
    local shape = value and value.type and value.type.tensor
        and value.type.tensor.shape
    return shape and shape.dims or {}
end

local function filled(count, value)
    local values = {}
    for index = 1, count do values[index] = value end
    return values
end

local function integerTokens(tokenIds)
    assert(type(tokenIds) == "table" and #tokenIds > 0,
        "PZONNX Chat requires at least one token ID")
    local result = {}
    for index = 1, #tokenIds do
        local token = tonumber(tokenIds[index])
        assert(token ~= nil and token == math.floor(token),
            "PZONNX Chat token IDs must be integers")
        result[index] = token
    end
    return result
end

local function buildDecoderInputs(model, tokenIds)
    local sequenceLength = #tokenIds
    local inputs = {}
    local inputIDs = valueInfo(model, "input_ids")
    local attentionMask = valueInfo(model, "attention_mask")
    local positionIDs = valueInfo(model, "position_ids")

    inputs[inputIDs.name] = Tensor.new({ 1, sequenceLength }, tokenIds, 7)
    if attentionMask ~= nil then
        inputs[attentionMask.name] = Tensor.new({ 1, sequenceLength },
            filled(sequenceLength, 1), 7)
    end
    if positionIDs ~= nil then
        local positions = {}
        for index = 1, sequenceLength do positions[index] = index - 1 end
        inputs[positionIDs.name] = Tensor.new({ 1, sequenceLength }, positions, 7)
    end

    local cacheCount = 0
    for index = 1, #model.graph.inputs do
        local input = model.graph.inputs[index]
        local name = input.name
        if string.find(name, "past_key_values", 1, true) then
            local dimensions = shapeOf(input)
            if #dimensions ~= 4 then
                error("PZONNX Chat cache input rank is unsupported: " .. name)
            end
            local width = dimensionValue(dimensions[4])
            if width == nil or width <= 0 then
                error("PZONNX Chat cache width is not static: " .. name)
            end
            inputs[name] = Tensor.new({ 1, 1, 0, width }, {}, 1)
            cacheCount = cacheCount + 1
        end
    end

    if attentionMask == nil or positionIDs == nil or cacheCount == 0 then
        error("PZONNX Chat decoder inputs are incomplete")
    end

    return inputs, {
        mode = "decoder-cache",
        sequenceLength = sequenceLength,
        cacheCount = cacheCount,
    }
end

local function buildSingleInput(model, tokenIds)
    if #model.graph.inputs ~= 1 then
        error("PZONNX Chat model input layout is unsupported")
    end
    if #tokenIds ~= 1 then
        error("PZONNX Chat single-input models accept one token ID")
    end
    local input = model.graph.inputs[1]
    return {
        [input.name] = Tensor.new({ 1 }, { tokenIds[1] }, 7),
    }, {
        mode = "single-token",
        sequenceLength = 1,
        cacheCount = 0,
    }
end

function Chat.buildInputs(model, tokenIds)
    assert(type(model) == "table" and model.graph ~= nil,
        "PZONNX Chat requires a parsed model")
    tokenIds = integerTokens(tokenIds)
    if valueInfo(model, "input_ids") ~= nil then
        return buildDecoderInputs(model, tokenIds)
    end
    return buildSingleInput(model, tokenIds)
end

local function logitsOutput(model)
    for index = 1, #model.graph.outputs do
        local output = model.graph.outputs[index]
        if output.name == "logits" then return output.name end
    end
    for index = 1, #model.graph.outputs do
        local output = model.graph.outputs[index]
        if string.find(output.name, "logits", 1, true) then return output.name end
    end
    error("PZONNX Chat model has no logits output")
end

function Chat.nextToken(model, outputs)
    assert(type(outputs) == "table", "PZONNX Chat requires model outputs")
    local outputName = logitsOutput(model)
    local logits = outputs[outputName]
    if not Tensor.isTensor(logits) then
        error("PZONNX Chat logits output is not a Tensor")
    end

    local rank = #logits.shape
    local startIndex
    local vocabulary
    if rank == 2 and logits.shape[1] == 1 then
        startIndex = 1
        vocabulary = logits.shape[2]
    elseif rank == 3 and logits.shape[1] == 1 then
        local sequenceLength = logits.shape[2]
        vocabulary = logits.shape[3]
        startIndex = (sequenceLength - 1) * vocabulary + 1
    else
        error("PZONNX Chat logits shape is unsupported")
    end

    local bestIndex = 0
    local bestValue = -math.huge
    for offset = 0, vocabulary - 1 do
        local value = Tensor.valueAt(logits, startIndex + offset)
        if value > bestValue then
            bestValue = value
            bestIndex = offset
        end
    end
    return {
        tokenId = bestIndex,
        logit = bestValue,
        logits = logits,
        outputName = outputName,
    }
end

return Chat
