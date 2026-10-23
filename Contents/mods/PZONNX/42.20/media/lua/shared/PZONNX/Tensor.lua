local BinaryReader = require "PZONNX/IO/BinaryReader"

local Tensor = {}
Tensor.__index = Tensor

local function validateShape(shape)
    assert(type(shape) == "table", "PZONNX Tensor shape must be a table")
    local count = 1
    for i = 1, #shape do
        local dimension = shape[i]
        assert(type(dimension) == "number" and dimension >= 0 and dimension == math.floor(dimension),
            "PZONNX Tensor dimensions must be non-negative integers")
        count = count * dimension
    end
    return count
end

function Tensor.new(shape, values, dataType)
    local count = validateShape(shape)
    assert(type(values) == "table", "PZONNX Tensor values must be a table")
    assert(#values == count,
        "PZONNX Tensor value count mismatch expected=" .. tostring(count) .. " actual=" .. tostring(#values))
    for i = 1, #values do
        assert(type(values[i]) == "number", "PZONNX Tensor values must be numeric")
    end

    return setmetatable({
        shape = shape,
        data = values,
        dataType = dataType or 1,
        count = count,
    }, Tensor)
end

local function packedByte(packed, index)
    return string.byte(packed, index)
end

local function packedFloat32(packed, index)
    local offset = (index - 1) * 4 + 1
    local bits = packedByte(packed, offset) + packedByte(packed, offset + 1) * 256 +
        packedByte(packed, offset + 2) * 65536 + packedByte(packed, offset + 3) * 16777216
    local sign = 1
    if bits >= 2147483648 then sign = -1; bits = bits - 2147483648 end
    local exponent = math.floor(bits / 8388608)
    local mantissa = bits % 8388608
    if exponent == 255 then
        if mantissa == 0 then return sign * math.huge end
        return 0 / 0
    end
    if exponent == 0 then
        if mantissa == 0 then return sign * 0 end
        return sign * (mantissa / 8388608) * (2 ^ -126)
    end
    return sign * (1 + mantissa / 8388608) * (2 ^ (exponent - 127))
end

local function fromPacked(shape, packed, dataType, storageKind, bytesPerElement)
    local count = validateShape(shape)
    assert(#packed == count * bytesPerElement,
        "PZONNX packed tensor length mismatch expected=" .. tostring(count * bytesPerElement) ..
        " actual=" .. tostring(#packed))
    return setmetatable({
        shape = shape,
        packed = packed,
        storageKind = storageKind,
        dataType = dataType,
        count = count,
    }, Tensor)
end

function Tensor.fromFloat32PackedString(packed, shape)
    return fromPacked(shape, packed, 1, "float32", 4)
end

function Tensor.fromUInt8PackedString(packed, shape)
    return fromPacked(shape, packed, 2, "uint8", 1)
end

function Tensor.fromInt8PackedString(packed, shape)
    return fromPacked(shape, packed, 3, "int8", 1)
end

function Tensor.fromProtoTensor(proto)
    assert(type(proto) == "table", "PZONNX Tensor.fromProtoTensor requires tensor metadata")
    local shape = {}
    if #proto.dims > 0 then
        for i = 1, #proto.dims do
            shape[i] = proto.dims[i]
        end
    end

    if proto.rawDataBytes ~= nil then
        if proto.dataType == 1 then
            return Tensor.fromFloat32Bytes(proto.rawDataBytes, shape)
        end
        if proto.dataType == 7 then
            local count = 1
            for i = 1, #shape do count = count * shape[i] end
            if #proto.rawDataBytes ~= count * 8 then
                error("PZONNX captured int64 constant length mismatch")
            end
            local reader = BinaryReader.fromBytes(proto.rawDataBytes)
            local values = {}
            for i = 1, count do values[i] = reader:readInt64LE() end
            return Tensor.new(shape, values, 7)
        end
        if proto.dataType == 9 then
            local count = 1
            for i = 1, #shape do count = count * shape[i] end
            if #proto.rawDataBytes ~= count then
                error("PZONNX captured bool constant length mismatch")
            end
            local values = {}
            for i = 1, count do values[i] = proto.rawDataBytes[i] ~= 0 and 1 or 0 end
            return Tensor.new(shape, values, 9)
        end
        error("PZONNX captured raw tensor data_type is unsupported: " .. tostring(proto.dataType))
    end
    if proto.values == nil then
        error("PZONNX captured tensor has no values")
    end
    if proto.dataType == 1 or proto.dataType == 2 or proto.dataType == 3 or
        proto.dataType == 6 or proto.dataType == 7 or proto.dataType == 9 then
        return Tensor.new(shape, proto.values, proto.dataType)
    end
    error("PZONNX captured tensor data_type is unsupported: " .. tostring(proto.dataType))
end

function Tensor.cast(value, dataType)
    assert(Tensor.isTensor(value), "PZONNX Cast requires a tensor")
    assert(dataType == 1 or dataType == 6 or dataType == 7 or dataType == 9,
        "PZONNX Cast target data_type is unsupported: " .. tostring(dataType))
    local values = {}
    for i = 1, value:elementCount() do
        local source = Tensor.valueAt(value, i)
        if dataType == 9 then
            values[i] = source ~= 0 and 1 or 0
        elseif dataType == 1 then
            values[i] = source + 0.0
        else
            if source ~= math.floor(source) then
                error("PZONNX Cast cannot safely convert non-integer value at index " .. tostring(i))
            end
            values[i] = source
        end
    end
    return Tensor.new(value.shape, values, dataType)
end

function Tensor.shapeTensor(value)
    assert(Tensor.isTensor(value), "PZONNX Shape requires a tensor")
    local values = {}
    for i = 1, #value.shape do values[i] = value.shape[i] end
    return Tensor.new({ #value.shape }, values, 7)
end

function Tensor.unsqueeze(value, axes)
    assert(Tensor.isTensor(value) and Tensor.isTensor(axes), "PZONNX Unsqueeze requires tensors")
    local inputRank = #value.shape
    local axisValues = {}
    for i = 1, axes:elementCount() do
        local axis = Tensor.valueAt(axes, i)
        if axis < 0 then axis = axis + inputRank + axes:elementCount() + 1 end
        axis = axis + 1
        if axis < 1 or axis > inputRank + axes:elementCount() or axisValues[axis] then
            error("PZONNX Unsqueeze axis is invalid: " .. tostring(axis - 1))
        end
        axisValues[axis] = true
    end

    local outputRank = inputRank + axes:elementCount()
    local outputShape = {}
    local inputDimension = 1
    for outputDimension = 1, outputRank do
        if axisValues[outputDimension] then
            outputShape[outputDimension] = 1
        else
            outputShape[outputDimension] = value.shape[inputDimension]
            inputDimension = inputDimension + 1
        end
    end

    local count = validateShape(outputShape)
    local values = {}
    for outputIndex = 1, count do
        local remainder = outputIndex - 1
        local inputIndex = 1
        local inputStride = 1
        local inputDimension = inputRank
        local coordinates = {}
        for dimension = outputRank, 1, -1 do
            coordinates[dimension] = remainder % outputShape[dimension]
            remainder = math.floor(remainder / outputShape[dimension])
        end
        for outputDimension = outputRank, 1, -1 do
            if not axisValues[outputDimension] then
                inputIndex = inputIndex + coordinates[outputDimension] * inputStride
                inputStride = inputStride * value.shape[inputDimension]
                inputDimension = inputDimension - 1
            end
        end
        values[outputIndex] = Tensor.valueAt(value, inputIndex)
    end
    return Tensor.new(outputShape, values, value.dataType)
end

function Tensor.constantOfShape(shapeTensor, fillTensor)
    assert(Tensor.isTensor(shapeTensor) and Tensor.isTensor(fillTensor),
        "PZONNX ConstantOfShape requires tensors")
    local shape = {}
    for i = 1, shapeTensor:elementCount() do
        local dimension = Tensor.valueAt(shapeTensor, i)
        if dimension < 0 or dimension ~= math.floor(dimension) then
            error("PZONNX ConstantOfShape requires non-negative integer dimensions")
        end
        shape[i] = dimension
    end
    local count = validateShape(shape)
    local fill = Tensor.valueAt(fillTensor, 1)
    local values = {}
    for i = 1, count do values[i] = fill end
    return Tensor.new(shape, values, fillTensor.dataType)
end

function Tensor.flatten(value, axis)
    assert(Tensor.isTensor(value), "PZONNX Flatten requires a tensor")
    axis = axis or 1
    if axis < 0 then axis = axis + #value.shape end
    if axis < 0 or axis > #value.shape then error("PZONNX Flatten axis is invalid") end
    local left = 1
    for i = 1, axis do left = left * (value.shape[i] or 1) end
    local right = 1
    for i = axis + 1, #value.shape do right = right * value.shape[i] end
    local values = {}
    for i = 1, value:elementCount() do values[i] = Tensor.valueAt(value, i) end
    return Tensor.new({ left, right }, values, value.dataType)
end

function Tensor.isTensor(value)
    return type(value) == "table" and getmetatable(value) == Tensor
end

function Tensor.valueAt(value, index)
    if value.packed ~= nil then
        if value.storageKind == "float32" then return packedFloat32(value.packed, index) end
        local byte = packedByte(value.packed, index)
        if byte == nil then
            error("PZONNX packed tensor index out of bounds index=" .. tostring(index) ..
                " bytes=" .. tostring(#value.packed))
        end
        if value.storageKind == "int8" and byte >= 128 then return byte - 256 end
        return byte
    end
    if value.quantized then
        return value.data[index] * value.scale
    end
    return value.data[index]
end

function Tensor.storageBytes(value)
    if value.packed ~= nil then return #value.packed end
    if value.quantized then
        return #value.data
    end
    return #value.data * 4
end

function Tensor.quantizeInt8(value, scale)
    assert(Tensor.isTensor(value), "PZONNX quantization requires a tensor")
    assert(type(scale) == "number" and scale > 0, "PZONNX int8 scale must be positive")
    local values = {}
    for i = 1, #value.data do
        local source = Tensor.valueAt(value, i)
        local scaled = source / scale
        local rounded = scaled >= 0 and math.floor(scaled + 0.5) or math.ceil(scaled - 0.5)
        if rounded < -128 or rounded > 127 then
            error("PZONNX int8 quantization range exceeded at index " .. tostring(i))
        end
        values[i] = rounded
    end
    return setmetatable({
        shape = value.shape,
        data = values,
        dataType = 3,
        quantized = true,
        scale = scale,
    }, Tensor)
end

function Tensor.fromFloat32Bytes(bytes, shape)
    local count = validateShape(shape)
    assert(#bytes == count * 4,
        "PZONNX float32 raw data length mismatch expected=" .. tostring(count * 4) ..
        " actual=" .. tostring(#bytes))
    local reader = BinaryReader.fromBytes(bytes)
    local values = {}
    for i = 1, count do
        values[i] = reader:readFloat32LE()
    end
    return Tensor.new(shape, values)
end

function Tensor:elementCount()
    return self.count or #self.data
end

function Tensor:equalsShape(other)
    if #self.shape ~= #other.shape then
        return false
    end
    for i = 1, #self.shape do
        if self.shape[i] ~= other.shape[i] then
            return false
        end
    end
    return true
end

function Tensor.broadcastShape(leftShape, rightShape)
    local rank = math.max(#leftShape, #rightShape)
    local shape = {}
    for outputDimension = 1, rank do
        local leftIndex = outputDimension - (rank - #leftShape)
        local rightIndex = outputDimension - (rank - #rightShape)
        local leftDimension = leftIndex >= 1 and leftShape[leftIndex] or 1
        local rightDimension = rightIndex >= 1 and rightShape[rightIndex] or 1
        if leftDimension ~= rightDimension and leftDimension ~= 1 and rightDimension ~= 1 then
            error("PZONNX broadcast shape mismatch at dimension " .. tostring(outputDimension))
        end
        shape[outputDimension] = math.max(leftDimension, rightDimension)
    end
    return shape
end

local function broadcastIndex(value, coordinates, outputRank)
    local index = 1
    local stride = 1
    for dimension = #value.shape, 1, -1 do
        local outputDimension = dimension + outputRank - #value.shape
        local coordinate = coordinates[outputDimension] or 0
        if value.shape[dimension] == 1 then coordinate = 0 end
        index = index + coordinate * stride
        stride = stride * value.shape[dimension]
    end
    return index
end

function Tensor.binary(left, right, operation, dataType)
    assert(Tensor.isTensor(left) and Tensor.isTensor(right), "PZONNX binary operation requires tensors")
    local outputShape = Tensor.broadcastShape(left.shape, right.shape)
    local outputRank = #outputShape
    local count = validateShape(outputShape)
    local values = {}
    for outputIndex = 1, count do
        local remainder = outputIndex - 1
        local coordinates = {}
        for dimension = outputRank, 1, -1 do
            coordinates[dimension] = remainder % outputShape[dimension]
            remainder = math.floor(remainder / outputShape[dimension])
        end
        values[outputIndex] = operation(
            Tensor.valueAt(left, broadcastIndex(left, coordinates, outputRank)),
            Tensor.valueAt(right, broadcastIndex(right, coordinates, outputRank)))
    end
    return Tensor.new(outputShape, values, dataType or left.dataType)
end

function Tensor.unary(value, operation)
    assert(Tensor.isTensor(value), "PZONNX unary operation requires a tensor")
    local values = {}
    for i = 1, value:elementCount() do values[i] = operation(Tensor.valueAt(value, i)) end
    return Tensor.new(value.shape, values, value.dataType)
end

function Tensor.dequantizeLinear(value, scale, zeroPoint)
    assert(Tensor.isTensor(value) and Tensor.isTensor(scale) and Tensor.isTensor(zeroPoint),
        "PZONNX DequantizeLinear requires tensors")
    local outputShape = Tensor.broadcastShape(value.shape, scale.shape)
    outputShape = Tensor.broadcastShape(outputShape, zeroPoint.shape)
    local outputRank = #outputShape
    local count = validateShape(outputShape)
    local values = {}
    for outputIndex = 1, count do
        local remainder = outputIndex - 1
        local coordinates = {}
        for dimension = outputRank, 1, -1 do
            coordinates[dimension] = remainder % outputShape[dimension]
            remainder = math.floor(remainder / outputShape[dimension])
        end
        local valueIndex = broadcastIndex(value, coordinates, outputRank)
        local scaleIndex = broadcastIndex(scale, coordinates, outputRank)
        local zeroIndex = broadcastIndex(zeroPoint, coordinates, outputRank)
        values[outputIndex] = (Tensor.valueAt(value, valueIndex) - Tensor.valueAt(zeroPoint, zeroIndex)) *
            Tensor.valueAt(scale, scaleIndex)
    end
    return Tensor.new(outputShape, values, 1)
end

function Tensor.matmul(left, right)
    assert(Tensor.isTensor(left) and Tensor.isTensor(right), "PZONNX MatMul requires tensors")
    if #left.shape ~= 2 or #right.shape ~= 2 then
        error("PZONNX MatMul currently supports only rank-2 tensors")
    end
    local rows = left.shape[1]
    local shared = left.shape[2]
    local rightShared = right.shape[1]
    local columns = right.shape[2]
    if shared ~= rightShared then
        error("PZONNX MatMul shape mismatch left_shared=" .. tostring(shared) ..
            " right_rows=" .. tostring(rightShared))
    end

    local values = {}
    for row = 1, rows do
        for column = 1, columns do
            local sum = 0.0
            for sharedIndex = 1, shared do
                local leftIndex = (row - 1) * shared + sharedIndex
                local rightIndex = (sharedIndex - 1) * columns + column
                sum = sum + Tensor.valueAt(left, leftIndex) * Tensor.valueAt(right, rightIndex)
            end
            values[(row - 1) * columns + column] = sum
        end
    end
    return Tensor.new({ rows, columns }, values)
end

function Tensor.add(left, right)
    assert(Tensor.isTensor(left) and Tensor.isTensor(right), "PZONNX Add requires tensors")
    local outputShape = Tensor.broadcastShape(left.shape, right.shape)
    local outputCount = validateShape(outputShape)
    local outputRank = #outputShape
    local leftRank = #left.shape
    local rightRank = #right.shape
    local values = {}
    for outputIndex = 1, outputCount do
        local remainder = outputIndex - 1
        local coordinates = {}
        for dimension = outputRank, 1, -1 do
            coordinates[dimension] = remainder % outputShape[dimension]
            remainder = math.floor(remainder / outputShape[dimension])
        end

        local leftIndex = 1
        local leftStride = 1
        for dimension = leftRank, 1, -1 do
            local outputDimension = dimension + outputRank - leftRank
            local coordinate = coordinates[outputDimension]
            if left.shape[dimension] == 1 then
                coordinate = 0
            end
            leftIndex = leftIndex + coordinate * leftStride
            leftStride = leftStride * left.shape[dimension]
        end

        local rightIndex = 1
        local rightStride = 1
        for dimension = rightRank, 1, -1 do
            local outputDimension = dimension + outputRank - rightRank
            local coordinate = coordinates[outputDimension]
            if right.shape[dimension] == 1 then
                coordinate = 0
            end
            rightIndex = rightIndex + coordinate * rightStride
            rightStride = rightStride * right.shape[dimension]
        end
        values[outputIndex] = Tensor.valueAt(left, leftIndex) + Tensor.valueAt(right, rightIndex)
    end
    return Tensor.new(outputShape, values, left.dataType == 7 and right.dataType == 7 and 7 or 1)
end

function Tensor.pow(left, right)
    return Tensor.binary(left, right, function(a, b) return a ^ b end)
end

function Tensor.mul(left, right)
    return Tensor.binary(left, right, function(a, b) return a * b end)
end

function Tensor.div(left, right)
    return Tensor.binary(left, right, function(a, b) return a / b end)
end

function Tensor.sqrt(value) return Tensor.unary(value, math.sqrt) end
function Tensor.sin(value) return Tensor.unary(value, math.sin) end
function Tensor.cos(value) return Tensor.unary(value, math.cos) end
function Tensor.sigmoid(value)
    return Tensor.unary(value, function(x) return 1 / (1 + math.exp(-x)) end)
end

function Tensor.concat(inputs, axis)
    assert(type(inputs) == "table" and #inputs > 0, "PZONNX Concat requires inputs")
    local rank = #inputs[1].shape
    if axis < 0 then axis = axis + rank end
    if axis < 0 or axis >= rank then error("PZONNX Concat axis is invalid") end
    local outputShape = {}
    for dimension = 1, rank do
        local size = inputs[1].shape[dimension]
        if dimension == axis + 1 then
            size = 0
            for i = 1, #inputs do size = size + inputs[i].shape[dimension] end
        else
            for i = 2, #inputs do
                if inputs[i].shape[dimension] ~= size then error("PZONNX Concat shape mismatch") end
            end
        end
        outputShape[dimension] = size
    end
    local before = 1
    for dimension = 1, axis do before = before * inputs[1].shape[dimension] end
    local inner = 1
    for dimension = axis + 2, rank do inner = inner * inputs[1].shape[dimension] end
    local values = {}
    local outputIndex = 1
    for block = 0, before - 1 do
        for i = 1, #inputs do
            local blockSize = inputs[i].shape[axis + 1] * inner
            local sourceStart = block * blockSize + 1
            for offset = 0, blockSize - 1 do
                values[outputIndex] = Tensor.valueAt(inputs[i], sourceStart + offset)
                outputIndex = outputIndex + 1
            end
        end
    end
    return Tensor.new(outputShape, values, inputs[1].dataType)
end

function Tensor.reduceMean(value, axes, keepDims)
    assert(Tensor.isTensor(value) and Tensor.isTensor(axes), "PZONNX ReduceMean requires tensors")
    local rank = #value.shape
    local reduced = {}
    for i = 1, axes:elementCount() do
        local axis = Tensor.valueAt(axes, i)
        if axis < 0 then axis = axis + rank end
        if axis < 0 or axis >= rank then error("PZONNX ReduceMean axis is invalid") end
        reduced[axis + 1] = true
    end
    if axes:elementCount() == 0 then
        for dimension = 1, rank do reduced[dimension] = true end
    end

    local outputShape = {}
    for dimension = 1, rank do
        if reduced[dimension] then
            if keepDims then outputShape[#outputShape + 1] = 1 end
        else
            outputShape[#outputShape + 1] = value.shape[dimension]
        end
    end
    local outputCount = validateShape(outputShape)
    local sums = {}
    local counts = {}
    for i = 1, outputCount do sums[i] = 0; counts[i] = 0 end
    local function flatIndex(coordinates, shape)
        local index = 1
        local stride = 1
        for dimension = #shape, 1, -1 do
            index = index + coordinates[dimension] * stride
            stride = stride * shape[dimension]
        end
        return index
    end
    for inputIndex = 1, value:elementCount() do
        local remainder = inputIndex - 1
        local coordinates = {}
        for dimension = rank, 1, -1 do
            coordinates[dimension] = remainder % value.shape[dimension]
            remainder = math.floor(remainder / value.shape[dimension])
        end
        local outputCoordinates = {}
        for dimension = 1, rank do
            if reduced[dimension] then
                if keepDims then outputCoordinates[#outputCoordinates + 1] = 0 end
            else
                outputCoordinates[#outputCoordinates + 1] = coordinates[dimension]
            end
        end
        local outputIndex = flatIndex(outputCoordinates, outputShape)
        sums[outputIndex] = sums[outputIndex] + Tensor.valueAt(value, inputIndex)
        counts[outputIndex] = counts[outputIndex] + 1
    end
    local output = {}
    for i = 1, outputCount do output[i] = sums[i] / counts[i] end
    return Tensor.new(outputShape, output, 1)
end

function Tensor.reshape(value, shapeTensor, allowZero)
    assert(Tensor.isTensor(value) and Tensor.isTensor(shapeTensor), "PZONNX Reshape requires tensors")
    local shape = {}
    local inferred = nil
    local known = 1
    for i = 1, shapeTensor:elementCount() do
        local dimension = Tensor.valueAt(shapeTensor, i)
        if dimension == 0 and not allowZero then
            dimension = value.shape[i]
        elseif dimension == -1 then
            if inferred ~= nil then error("PZONNX Reshape has multiple inferred dimensions") end
            inferred = i
            dimension = 1
        elseif dimension < 0 then
            error("PZONNX Reshape has an invalid dimension")
        end
        shape[i] = dimension
        known = known * dimension
    end
    local count = value:elementCount()
    if inferred ~= nil then
        if known == 0 or count % known ~= 0 then error("PZONNX Reshape cannot infer dimension") end
        shape[inferred] = count / known
    end
    local reshapedCount = validateShape(shape)
    if reshapedCount ~= count then
        error("PZONNX Reshape element count mismatch expected=" .. tostring(count) ..
            " actual=" .. tostring(reshapedCount))
    end
    local values = {}
    for i = 1, count do values[i] = Tensor.valueAt(value, i) end
    return Tensor.new(shape, values, value.dataType)
end

function Tensor.range(startTensor, limitTensor, deltaTensor)
    local start = Tensor.valueAt(startTensor, 1)
    local limit = Tensor.valueAt(limitTensor, 1)
    local delta = Tensor.valueAt(deltaTensor, 1)
    if delta == 0 then error("PZONNX Range delta cannot be zero") end
    local values = {}
    local value = start
    while (delta > 0 and value < limit) or (delta < 0 and value > limit) do
        values[#values + 1] = value
        value = value + delta
        if #values > 1000000 then error("PZONNX Range exceeded bounded output size") end
    end
    return Tensor.new({ #values }, values, startTensor.dataType)
end

function Tensor.compare(left, right, operation)
    return Tensor.binary(left, right, function(a, b) return operation(a, b) and 1 or 0 end, 9)
end

function Tensor.logicalAnd(left, right)
    return Tensor.binary(left, right, function(a, b) return (a ~= 0 and b ~= 0) and 1 or 0 end, 9)
end

function Tensor.where(condition, left, right)
    local outputShape = Tensor.broadcastShape(condition.shape, left.shape)
    outputShape = Tensor.broadcastShape(outputShape, right.shape)
    local outputRank = #outputShape
    local count = validateShape(outputShape)
    local values = {}
    for outputIndex = 1, count do
        local remainder = outputIndex - 1
        local coordinates = {}
        for dimension = outputRank, 1, -1 do
            coordinates[dimension] = remainder % outputShape[dimension]
            remainder = math.floor(remainder / outputShape[dimension])
        end
        local conditionValue = Tensor.valueAt(condition, broadcastIndex(condition, coordinates, outputRank))
        local source = conditionValue ~= 0 and left or right
        values[outputIndex] = Tensor.valueAt(source, broadcastIndex(source, coordinates, outputRank))
    end
    return Tensor.new(outputShape, values, left.dataType)
end

function Tensor.isNaN(value)
    return Tensor.unary(value, function(x) return x ~= x and 1 or 0 end)
end

function Tensor.neg(value)
    return Tensor.unary(value, function(x) return -x end)
end

local function matmulFlatIndex(coordinates, shape)
    local index = 1
    local stride = 1
    for dimension = #shape, 1, -1 do
        index = index + coordinates[dimension] * stride
        stride = stride * shape[dimension]
    end
    return index
end

local function matmulUnravel(index, shape)
    local coordinates = {}
    local remainder = index - 1
    for dimension = #shape, 1, -1 do
        coordinates[dimension] = remainder % shape[dimension]
        remainder = math.floor(remainder / shape[dimension])
    end
    return coordinates
end

local function matmulGeneric(left, right, integerMode, leftZeroPoint, rightZeroPoint)
    local leftRank = #left.shape
    local rightRank = #right.shape
    if leftRank < 1 or rightRank < 1 then error("PZONNX MatMul requires rank >= 1 tensors") end
    local leftK = left.shape[leftRank]
    local leftM = leftRank == 1 and 1 or left.shape[leftRank - 1]
    local rightK = rightRank == 1 and right.shape[1] or right.shape[rightRank - 1]
    local rightN = rightRank == 1 and 1 or right.shape[rightRank]
    if leftK ~= rightK then error("PZONNX MatMul shared dimension mismatch") end

    local leftBatch = {}
    for i = 1, leftRank - 2 do leftBatch[#leftBatch + 1] = left.shape[i] end
    if leftRank == 1 then leftBatch = {} end
    local rightBatch = {}
    for i = 1, rightRank - 2 do rightBatch[#rightBatch + 1] = right.shape[i] end
    if rightRank == 1 then rightBatch = {} end
    local batchShape = Tensor.broadcastShape(leftBatch, rightBatch)
    local batchRank = #batchShape
    local matrixShape = {}
    for i = 1, batchRank do matrixShape[i] = batchShape[i] end
    matrixShape[#matrixShape + 1] = leftM
    matrixShape[#matrixShape + 1] = rightN
    local count = validateShape(matrixShape)
    local values = {}
    for outputIndex = 1, count do
        local coordinates = matmulUnravel(outputIndex, matrixShape)
        local row = coordinates[batchRank + 1]
        local column = coordinates[batchRank + 2]
        local sum = 0
        for shared = 1, leftK do
            local leftCoordinates = {}
            for dimension = 1, #leftBatch do
                local outputDimension = dimension + batchRank - #leftBatch
                local coordinate = coordinates[outputDimension]
                if leftBatch[dimension] == 1 then coordinate = 0 end
                leftCoordinates[dimension] = coordinate
            end
            if leftRank == 1 then
                leftCoordinates[1] = shared - 1
            else
                leftCoordinates[#leftCoordinates + 1] = row
                leftCoordinates[#leftCoordinates + 1] = shared - 1
            end

            local rightCoordinates = {}
            for dimension = 1, #rightBatch do
                local outputDimension = dimension + batchRank - #rightBatch
                local coordinate = coordinates[outputDimension]
                if rightBatch[dimension] == 1 then coordinate = 0 end
                rightCoordinates[dimension] = coordinate
            end
            if rightRank == 1 then
                rightCoordinates[1] = shared - 1
            else
                rightCoordinates[#rightCoordinates + 1] = shared - 1
                rightCoordinates[#rightCoordinates + 1] = column
            end

            local leftValue = Tensor.valueAt(left, matmulFlatIndex(leftCoordinates, left.shape))
            local rightValue = Tensor.valueAt(right, matmulFlatIndex(rightCoordinates, right.shape))
            if integerMode then
                local leftZero = Tensor.valueAt(leftZeroPoint, 1)
                local rightZero = Tensor.valueAt(rightZeroPoint, rightZeroPoint:elementCount() == 1 and 1 or column)
                sum = sum + (leftValue - leftZero) * (rightValue - rightZero)
            else
                sum = sum + leftValue * rightValue
            end
        end
        values[outputIndex] = sum
    end
    if leftRank == 1 then table.remove(matrixShape, batchRank + 1) end
    if rightRank == 1 then table.remove(matrixShape, #matrixShape) end
    return Tensor.new(matrixShape, values, integerMode and 6 or 1)
end

function Tensor.matmul(left, right)
    assert(Tensor.isTensor(left) and Tensor.isTensor(right), "PZONNX MatMul requires tensors")
    return matmulGeneric(left, right, false)
end

function Tensor.matmulInteger(left, right, leftZeroPoint, rightZeroPoint)
    assert(Tensor.isTensor(left) and Tensor.isTensor(right) and Tensor.isTensor(leftZeroPoint) and
        Tensor.isTensor(rightZeroPoint), "PZONNX MatMulInteger requires tensors")
    return matmulGeneric(left, right, true, leftZeroPoint, rightZeroPoint)
end

function Tensor.expand(value, shapeTensor)
    local shape = {}
    for i = 1, shapeTensor:elementCount() do
        local dimension = Tensor.valueAt(shapeTensor, i)
        if dimension < 0 or dimension ~= math.floor(dimension) then error("PZONNX Expand shape is invalid") end
        shape[i] = dimension
    end
    local outputShape = Tensor.broadcastShape(value.shape, shape)
    local outputRank = #outputShape
    local count = validateShape(outputShape)
    local values = {}
    for outputIndex = 1, count do
        local remainder = outputIndex - 1
        local coordinates = {}
        for dimension = outputRank, 1, -1 do
            coordinates[dimension] = remainder % outputShape[dimension]
            remainder = math.floor(remainder / outputShape[dimension])
        end
        values[outputIndex] = Tensor.valueAt(value, broadcastIndex(value, coordinates, outputRank))
    end
    return Tensor.new(outputShape, values, value.dataType)
end

function Tensor.dynamicQuantizeLinear(value)
    local minimum = 0
    local maximum = 0
    for i = 1, value:elementCount() do
        local current = Tensor.valueAt(value, i)
        if current < minimum then minimum = current end
        if current > maximum then maximum = current end
    end
    local scale = (maximum - minimum) / 255
    if scale == 0 then scale = 1 end
    local zeroPoint = math.floor(0.5 + (-minimum / scale))
    if zeroPoint < 0 then zeroPoint = 0 elseif zeroPoint > 255 then zeroPoint = 255 end
    local values = {}
    for i = 1, value:elementCount() do
        local quantized = math.floor(0.5 + Tensor.valueAt(value, i) / scale + zeroPoint)
        if quantized < 0 then quantized = 0 elseif quantized > 255 then quantized = 255 end
        values[i] = quantized
    end
    return {
        Tensor.new(value.shape, values, 2),
        Tensor.new({}, { scale }, 1),
        Tensor.new({}, { zeroPoint }, 2),
    }
end

function Tensor.transpose(value, permutation)
    assert(Tensor.isTensor(value), "PZONNX Transpose requires a tensor")
    local rank = #value.shape
    if permutation == nil or #permutation == 0 then
        permutation = {}
        for i = rank, 1, -1 do permutation[#permutation + 1] = i - 1 end
    end
    if #permutation ~= rank then error("PZONNX Transpose permutation rank mismatch") end
    local outputShape = {}
    local seen = {}
    for i = 1, rank do
        local axis = permutation[i]
        if axis < 0 then axis = axis + rank end
        if axis < 0 or axis >= rank or seen[axis + 1] then error("PZONNX Transpose permutation is invalid") end
        seen[axis + 1] = true
        outputShape[i] = value.shape[axis + 1]
        permutation[i] = axis
    end
    local count = validateShape(outputShape)
    local values = {}
    for outputIndex = 1, count do
        local remainder = outputIndex - 1
        local outputCoordinates = {}
        for dimension = rank, 1, -1 do
            outputCoordinates[dimension] = remainder % outputShape[dimension]
            remainder = math.floor(remainder / outputShape[dimension])
        end
        local inputCoordinates = {}
        for dimension = 1, rank do inputCoordinates[permutation[dimension] + 1] = outputCoordinates[dimension] end
        local inputIndex = 1
        local stride = 1
        for dimension = rank, 1, -1 do
            inputIndex = inputIndex + inputCoordinates[dimension] * stride
            stride = stride * value.shape[dimension]
        end
        values[outputIndex] = Tensor.valueAt(value, inputIndex)
    end
    return Tensor.new(outputShape, values, value.dataType)
end

function Tensor.slice(value, startsTensor, endsTensor, axesTensor, stepsTensor)
    local rank = #value.shape
    local starts = {}
    local ends = {}
    local axes = {}
    local steps = {}
    for i = 1, startsTensor:elementCount() do starts[i] = Tensor.valueAt(startsTensor, i) end
    for i = 1, endsTensor:elementCount() do ends[i] = Tensor.valueAt(endsTensor, i) end
    if axesTensor ~= nil then
        for i = 1, axesTensor:elementCount() do axes[i] = Tensor.valueAt(axesTensor, i) end
    else
        for i = 1, #starts do axes[i] = i - 1 end
    end
    if stepsTensor ~= nil then
        for i = 1, stepsTensor:elementCount() do steps[i] = Tensor.valueAt(stepsTensor, i) end
    else
        for i = 1, #starts do steps[i] = 1 end
    end
    if #starts ~= #ends or #starts ~= #axes or #starts ~= #steps then error("PZONNX Slice parameter count mismatch") end

    local selections = {}
    for dimension = 1, rank do
        selections[dimension] = {}
        for i = 0, value.shape[dimension] - 1 do selections[dimension][#selections[dimension] + 1] = i end
    end
    for i = 1, #starts do
        local axis = axes[i]
        if axis < 0 then axis = axis + rank end
        if axis < 0 or axis >= rank then error("PZONNX Slice axis is invalid") end
        local step = steps[i]
        if step == 0 then error("PZONNX Slice step cannot be zero") end
        local dimension = value.shape[axis + 1]
        local start = starts[i]
        local finish = ends[i]
        local selected = {}
        if step > 0 then
            if start == math.huge then start = dimension elseif start < 0 then start = start + dimension end
            if finish == math.huge then finish = dimension elseif finish < 0 then finish = finish + dimension end
            start = math.max(0, math.min(dimension, start))
            finish = math.max(0, math.min(dimension, finish))
            for index = start, finish - 1, step do selected[#selected + 1] = index end
        else
            if start == -math.huge then start = dimension - 1 elseif start < 0 then start = start + dimension end
            if finish == -math.huge then finish = -1 elseif finish < 0 then finish = finish + dimension end
            start = math.max(-1, math.min(dimension - 1, start))
            finish = math.max(-1, math.min(dimension - 1, finish))
            for index = start, finish + 1, step do selected[#selected + 1] = index end
        end
        selections[axis + 1] = selected
    end

    local outputShape = {}
    for dimension = 1, rank do outputShape[dimension] = #selections[dimension] end
    local count = validateShape(outputShape)
    local values = {}
    for outputIndex = 1, count do
        local remainder = outputIndex - 1
        local inputIndex = 1
        local inputStride = 1
        for dimension = rank, 1, -1 do
            local coordinate = remainder % outputShape[dimension]
            remainder = math.floor(remainder / outputShape[dimension])
            inputIndex = inputIndex + selections[dimension][coordinate + 1] * inputStride
            inputStride = inputStride * value.shape[dimension]
        end
        values[outputIndex] = Tensor.valueAt(value, inputIndex)
    end
    return Tensor.new(outputShape, values, value.dataType)
end

function Tensor.softmax(value, axis)
    assert(Tensor.isTensor(value), "PZONNX Softmax requires a tensor")
    if #value.shape ~= 2 or (axis ~= 1 and axis ~= -1) then
        error("PZONNX Softmax currently supports only rank-2 axis=1 tensors")
    end

    local rows = value.shape[1]
    local columns = value.shape[2]
    local output = {}
    for row = 1, rows do
        local maximum = -math.huge
        for column = 1, columns do
            local index = (row - 1) * columns + column
            if Tensor.valueAt(value, index) > maximum then
                maximum = Tensor.valueAt(value, index)
            end
        end
        local denominator = 0.0
        for column = 1, columns do
            local index = (row - 1) * columns + column
            local exponent = math.exp(Tensor.valueAt(value, index) - maximum)
            output[index] = exponent
            denominator = denominator + exponent
        end
        for column = 1, columns do
            local index = (row - 1) * columns + column
            output[index] = output[index] / denominator
        end
    end
    return Tensor.new(value.shape, output)
end

function Tensor.gather(data, indices, axis)
    assert(Tensor.isTensor(data) and Tensor.isTensor(indices), "PZONNX Gather requires tensors")
    if indices.dataType ~= 7 then
        error("PZONNX Gather currently requires int64 indices")
    end
    local dataRank = #data.shape
    if axis < 0 then axis = axis + dataRank end
    if axis < 0 or axis >= dataRank then error("PZONNX Gather axis is invalid") end

    local outputShape = {}
    for dimension = 1, axis do outputShape[#outputShape + 1] = data.shape[dimension] end
    for dimension = 1, #indices.shape do outputShape[#outputShape + 1] = indices.shape[dimension] end
    for dimension = axis + 2, dataRank do outputShape[#outputShape + 1] = data.shape[dimension] end

    local outputCount = validateShape(outputShape)
    local function flatIndex(coordinates, shape)
        local index = 1
        local stride = 1
        for dimension = #shape, 1, -1 do
            index = index + coordinates[dimension] * stride
            stride = stride * shape[dimension]
        end
        return index
    end

    local function unravel(index, shape)
        local coordinates = {}
        local remainder = index - 1
        for dimension = #shape, 1, -1 do
            coordinates[dimension] = remainder % shape[dimension]
            remainder = math.floor(remainder / shape[dimension])
        end
        return coordinates
    end

    local dataBefore = axis
    local dataAfter = dataRank - axis - 1
    local values = {}
    for outputIndex = 1, outputCount do
        local outputCoordinates = unravel(outputIndex, outputShape)
        local dataCoordinates = {}
        for dimension = 1, dataBefore do
            dataCoordinates[dimension] = outputCoordinates[dimension]
        end
        local indexCoordinates = {}
        for dimension = 1, #indices.shape do
            indexCoordinates[dimension] = outputCoordinates[dataBefore + dimension]
        end
        local selected = Tensor.valueAt(indices, flatIndex(indexCoordinates, indices.shape))
        if type(selected) ~= "number" or selected ~= math.floor(selected) then error("PZONNX Gather index must be an integer") end
        if selected < 0 or selected >= data.shape[axis + 1] then
            error("PZONNX Gather index out of bounds: " .. tostring(selected))
        end
        dataCoordinates[axis + 1] = selected
        for dimension = 1, dataAfter do
            dataCoordinates[axis + 1 + dimension] = outputCoordinates[dataBefore + #indices.shape + dimension]
        end
        values[outputIndex] = Tensor.valueAt(data, flatIndex(dataCoordinates, data.shape))
    end
    return Tensor.new(outputShape, values, data.dataType == 2 and 2 or 1)
end

function Tensor.softmax(value, axis)
    assert(Tensor.isTensor(value), "PZONNX Softmax requires a tensor")
    local rank = #value.shape
    if axis < 0 then axis = axis + rank end
    if axis < 0 or axis >= rank then error("PZONNX Softmax axis is invalid") end
    local before = 1
    for dimension = 1, axis do before = before * value.shape[dimension] end
    local width = value.shape[axis + 1]
    local after = 1
    for dimension = axis + 2, rank do after = after * value.shape[dimension] end
    local output = {}
    for outer = 0, before - 1 do
        for inner = 0, after - 1 do
            local maximum = -math.huge
            for coordinate = 0, width - 1 do
                local index = outer * width * after + coordinate * after + inner + 1
                local current = Tensor.valueAt(value, index)
                if current > maximum then maximum = current end
            end
            local denominator = 0
            for coordinate = 0, width - 1 do
                local index = outer * width * after + coordinate * after + inner + 1
                output[index] = math.exp(Tensor.valueAt(value, index) - maximum)
                denominator = denominator + output[index]
            end
            for coordinate = 0, width - 1 do
                local index = outer * width * after + coordinate * after + inner + 1
                output[index] = output[index] / denominator
            end
        end
    end
    return Tensor.new(value.shape, output, 1)
end

return Tensor
