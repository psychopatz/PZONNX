local Model = require "PZONNX/ONNX/Model"
local Tensor = require "PZONNX/Tensor"
local InferenceJob = require "PZONNX/Runtime/InferenceJob"

local Session = {}
Session.__index = Session

function Session.new(model, options)
    assert(type(model) == "table" and model.graph ~= nil, "PZONNX Session requires a parsed model")
    options = options or {}
    return setmetatable({
        model = model,
        initializerTensors = {},
        quantizedWeightScale = options.quantizedWeightScale,
    }, Session)
end

function Session:_initializer(name)
    local cached = self.initializerTensors[name]
    if cached ~= nil then
        return cached
    end

    local initializer = self.model.graph.initializerIndex[name]
    if initializer == nil then
        error("PZONNX initializer is not indexed: " .. tostring(name))
    end
    local tensor
    if initializer.rawData == nil then
        tensor = Tensor.fromProtoTensor(initializer)
    else
        local packed = Model.readInitializerPackedBytes(self.model, initializer)
        if initializer.dataType == 1 then
            tensor = Tensor.fromFloat32PackedString(packed, initializer.dims)
        elseif initializer.dataType == 2 then
            tensor = Tensor.fromUInt8PackedString(packed, initializer.dims)
        elseif initializer.dataType == 3 then
            tensor = Tensor.fromInt8PackedString(packed, initializer.dims)
        else
            error("PZONNX initializer data_type is unsupported: " .. tostring(initializer.name) ..
                " data_type=" .. tostring(initializer.dataType))
        end
    end
    if self.quantizedWeightScale ~= nil then
        tensor = Tensor.quantizeInt8(tensor, self.quantizedWeightScale)
    end
    self.initializerTensors[name] = tensor
    return tensor
end

function Session:_resolveValue(values, name)
    local existing = values[name]
    if existing ~= nil then
        return existing
    end
    return self:_initializer(name)
end

function Session:newJob(inputs)
    return InferenceJob.new(self, inputs)
end

function Session:run(inputs)
    local job = self:newJob(inputs)
    local result = job:step(math.max(1, #self.model.graph.nodes))
    if not result.done then
        error("PZONNX Session.run did not complete its bounded job")
    end
    return result.outputs
end

return Session
