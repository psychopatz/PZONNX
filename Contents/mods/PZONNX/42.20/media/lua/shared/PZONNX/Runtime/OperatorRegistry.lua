local Tensor = require "PZONNX/Tensor"

local Registry = {}
local specs = {}
local DEFAULT_MAX_OPSET = 18

local function key(domain, opType)
    return tostring(domain or "") .. ":" .. tostring(opType)
end

function Registry.register(domain, opType, specification)
    assert(type(opType) == "string" and opType ~= "", "PZONNX operator type is required")
    assert(type(specification) == "table" and type(specification.execute) == "function",
        "PZONNX operator specification requires execute")
    specification.domain = domain or ""
    specification.opType = opType
    specs[key(specification.domain, opType)] = specification
end

local function supportsOpset(specification, opsetVersion)
    if opsetVersion == nil then
        return true
    end
    local minimum = specification.minOpset or 1
    local maximum = specification.maxOpset or DEFAULT_MAX_OPSET
    return opsetVersion >= minimum and opsetVersion <= maximum
end

function Registry.get(domain, opType, opsetVersion)
    local specification = specs[key(domain, opType)]
    if specification ~= nil and not supportsOpset(specification, opsetVersion) then
        return nil
    end
    return specification
end

function Registry.describe(domain, opType, attributeCount, opsetVersion)
    local specification = specs[key(domain, opType)]
    if specification == nil then
        return "unsupported"
    end
    if not supportsOpset(specification, opsetVersion) then
        return "unsupported-opset"
    end
    if attributeCount ~= nil and attributeCount > 0 and not specification.acceptsAttributes then
        return "unsupported-attributes"
    end
    return "supported"
end

Registry.register("", "MatMul", {
    inputCount = 2,
    outputCount = 1,
    acceptsAttributes = false,
    begin = function(inputs)
        return Tensor.beginMatmul(inputs[1], inputs[2])
    end,
    step = function(_, _, state, budget)
        return Tensor.stepMatmul(state, budget)
    end,
    execute = function(inputs)
        return Tensor.matmul(inputs[1], inputs[2])
    end,
})

Registry.register("", "MatMulInteger", {
    inputCount = 4,
    outputCount = 1,
    acceptsAttributes = false,
    begin = function(inputs)
        return Tensor.beginMatmulInteger(inputs[1], inputs[2], inputs[3], inputs[4])
    end,
    step = function(_, _, state, budget)
        return Tensor.stepMatmul(state, budget)
    end,
    execute = function(inputs)
        return Tensor.matmulInteger(inputs[1], inputs[2], inputs[3], inputs[4])
    end,
})

Registry.register("", "Add", {
    inputCount = 2,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs)
        return Tensor.add(inputs[1], inputs[2])
    end,
})

Registry.register("", "Identity", {
    inputCount = 1,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return inputs[1] end,
})

Registry.register("", "Sub", {
    inputCount = 2,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.sub(inputs[1], inputs[2]) end,
})

Registry.register("", "Less", {
    inputCount = 2,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.less(inputs[1], inputs[2]) end,
})

Registry.register("", "Tanh", {
    inputCount = 1,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.tanh(inputs[1]) end,
})

Registry.register("", "Gemm", {
    inputCount = 3,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs, attributes)
        return Tensor.gemm(inputs[1], inputs[2], inputs[3], attributes)
    end,
})

Registry.register("", "Split", {
    inputCount = nil,
    outputCount = nil,
    acceptsAttributes = true,
    execute = function(inputs, attributes)
        local axis = 0
        local split = inputs[2]
        for _, attribute in ipairs(attributes or {}) do
            if attribute.name == "axis" and attribute.value ~= nil then axis = attribute.value end
            if attribute.name == "split" and #attribute.values > 0 then
                split = Tensor.new({ #attribute.values }, attribute.values, 7)
            end
        end
        return Tensor.split(inputs[1], split, axis, nil)
    end,
})

Registry.register("", "Squeeze", {
    inputCount = nil,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs, attributes)
        local axes = inputs[2]
        for _, attribute in ipairs(attributes or {}) do
            if attribute.name == "axes" and #attribute.values > 0 then
                axes = Tensor.new({ #attribute.values }, attribute.values, 7)
            end
        end
        return Tensor.squeeze(inputs[1], axes)
    end,
})

Registry.register("", "Softmax", {
    inputCount = 1,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs, attributes)
        local axis = 1
        for i = 1, #attributes do
            if attributes[i].name == "axis" then
                axis = attributes[i].value
            end
        end
        return Tensor.softmax(inputs[1], axis)
    end,
})

Registry.register("", "Gather", {
    inputCount = 2,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs, attributes)
        local axis = 0
        for i = 1, #attributes do
            if attributes[i].name == "axis" then
                axis = attributes[i].value
            end
        end
        return Tensor.gather(inputs[1], inputs[2], axis)
    end,
})

Registry.register("", "Constant", {
    inputCount = 0,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(_, attributes)
        for i = 1, #attributes do
            if attributes[i].name == "value" and attributes[i].tensor ~= nil then
                return Tensor.fromProtoTensor(attributes[i].tensor)
            end
        end
        error("PZONNX Constant requires a tensor value attribute")
    end,
})

Registry.register("", "Cast", {
    inputCount = 1,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs, attributes)
        for i = 1, #attributes do
            if attributes[i].name == "to" then
                return Tensor.cast(inputs[1], attributes[i].value)
            end
        end
        error("PZONNX Cast requires a 'to' attribute")
    end,
})

Registry.register("", "Shape", {
    inputCount = 1,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs)
        return Tensor.shapeTensor(inputs[1])
    end,
})

Registry.register("", "ConstantOfShape", {
    inputCount = 1,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs, attributes)
        local fill = Tensor.new({1}, {0}, 1)
        for i = 1, #attributes do
            if attributes[i].name == "value" and attributes[i].tensor ~= nil then
                fill = Tensor.fromProtoTensor(attributes[i].tensor)
            end
        end
        return Tensor.constantOfShape(inputs[1], fill)
    end,
})

Registry.register("", "Unsqueeze", {
    inputCount = 2,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs)
        return Tensor.unsqueeze(inputs[1], inputs[2])
    end,
})

Registry.register("", "Flatten", {
    inputCount = 1,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs, attributes)
        local axis = 1
        for i = 1, #attributes do
            if attributes[i].name == "axis" then axis = attributes[i].value end
        end
        return Tensor.flatten(inputs[1], axis)
    end,
})

Registry.register("", "DequantizeLinear", {
    inputCount = 3,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs)
        return Tensor.dequantizeLinear(inputs[1], inputs[2], inputs[3])
    end,
})

Registry.register("", "Pow", {
    inputCount = 2,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.pow(inputs[1], inputs[2]) end,
})

Registry.register("", "Mul", {
    inputCount = 2,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.mul(inputs[1], inputs[2]) end,
})

Registry.register("", "Div", {
    inputCount = 2,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.div(inputs[1], inputs[2]) end,
})

Registry.register("", "Sqrt", {
    inputCount = 1,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.sqrt(inputs[1]) end,
})

Registry.register("", "Sin", {
    inputCount = 1,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.sin(inputs[1]) end,
})

Registry.register("", "Cos", {
    inputCount = 1,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.cos(inputs[1]) end,
})

Registry.register("", "Sigmoid", {
    inputCount = 1,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.sigmoid(inputs[1]) end,
})

Registry.register("", "Concat", {
    inputCount = nil,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs, attributes)
        local axis = 0
        for i = 1, #attributes do
            if attributes[i].name == "axis" then axis = attributes[i].value end
        end
        return Tensor.concat(inputs, axis)
    end,
})

Registry.register("", "ReduceMean", {
    inputCount = nil,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs, attributes)
        local keepDims = true
        local axes = inputs[2]
        for i = 1, #attributes do
            if attributes[i].name == "keepdims" then keepDims = attributes[i].value ~= 0 end
            if attributes[i].name == "axes" and #attributes[i].values > 0 then
                axes = Tensor.new({ #attributes[i].values }, attributes[i].values, 7)
            end
        end
        if axes == nil then axes = Tensor.new({ 0 }, {}, 7) end
        return Tensor.reduceMean(inputs[1], axes, keepDims)
    end,
})

Registry.register("", "Reshape", {
    inputCount = 2,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs, attributes)
        local allowZero = false
        for i = 1, #attributes do
            if attributes[i].name == "allowzero" then allowZero = attributes[i].value ~= 0 end
        end
        return Tensor.reshape(inputs[1], inputs[2], allowZero)
    end,
})

Registry.register("", "Range", {
    inputCount = 3,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.range(inputs[1], inputs[2], inputs[3]) end,
})

Registry.register("", "Equal", {
    inputCount = 2,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs) return Tensor.compare(inputs[1], inputs[2], function(a, b) return a == b end) end,
})

Registry.register("", "LessOrEqual", {
    inputCount = 2,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs) return Tensor.compare(inputs[1], inputs[2], function(a, b) return a <= b end) end,
})

Registry.register("", "And", {
    inputCount = 2,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.logicalAnd(inputs[1], inputs[2]) end,
})

Registry.register("", "Where", {
    inputCount = 3,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.where(inputs[1], inputs[2], inputs[3]) end,
})

Registry.register("", "IsNaN", {
    inputCount = 1,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.isNaN(inputs[1]) end,
})

Registry.register("", "Expand", {
    inputCount = 2,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.expand(inputs[1], inputs[2]) end,
})

Registry.register("", "DynamicQuantizeLinear", {
    inputCount = 1,
    outputCount = 3,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.dynamicQuantizeLinear(inputs[1]) end,
})

Registry.register("", "Transpose", {
    inputCount = 1,
    outputCount = 1,
    acceptsAttributes = true,
    execute = function(inputs, attributes)
        local permutation = nil
        for i = 1, #attributes do
            if attributes[i].name == "perm" then permutation = attributes[i].values end
        end
        return Tensor.transpose(inputs[1], permutation)
    end,
})

Registry.register("", "Slice", {
    inputCount = nil,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs)
        return Tensor.slice(inputs[1], inputs[2], inputs[3], inputs[4], inputs[5])
    end,
})

Registry.register("", "Neg", {
    inputCount = 1,
    outputCount = 1,
    acceptsAttributes = false,
    execute = function(inputs) return Tensor.neg(inputs[1]) end,
})

return Registry
