package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Tensor = require "PZONNX/Tensor"

local sub = Tensor.sub(Tensor.new({ 2 }, { 5, 2 }), Tensor.new({ 2 }, { 1, 3 }))
if Tensor.valueAt(sub, 1) ~= 4 or Tensor.valueAt(sub, 2) ~= -1 then
    error("P15 Sub extension returned incorrect values")
end

local less = Tensor.less(Tensor.new({ 2 }, { 1, 3 }), Tensor.new({ 2 }, { 2, 2 }))
if Tensor.valueAt(less, 1) ~= 1 or Tensor.valueAt(less, 2) ~= 0 then
    error("P15 Less extension returned incorrect values")
end

local tanh = Tensor.tanh(Tensor.new({ 1 }, { 0 }))
if math.abs(Tensor.valueAt(tanh, 1)) > 1e-9 then error("P15 Tanh extension returned incorrect zero") end

local gemm = Tensor.gemm(Tensor.new({ 1, 2 }, { 2, 3 }),
    Tensor.new({ 2, 1 }, { 4, 5 }), Tensor.new({ 1, 1 }, { 1 }), {})
if Tensor.valueAt(gemm, 1) ~= 24 then error("P15 Gemm extension returned incorrect value") end

local split = Tensor.split(Tensor.new({ 1, 4 }, { 1, 2, 3, 4 }), nil, 1, 2)
if #split ~= 2 or Tensor.valueAt(split[1], 2) ~= 2 or Tensor.valueAt(split[2], 1) ~= 3 then
    error("P15 Split extension returned incorrect partitions")
end

local squeezed = Tensor.squeeze(Tensor.new({ 1, 2, 1 }, { 7, 8 }), nil)
if #squeezed.shape ~= 1 or squeezed.shape[1] ~= 2 or Tensor.valueAt(squeezed, 2) ~= 8 then
    error("P15 Squeeze extension returned incorrect shape")
end

print("PZONNX P15 operator extension tests passed")
