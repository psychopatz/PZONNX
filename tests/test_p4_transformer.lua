package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
local Tensor = require "PZONNX/Tensor"

local function assertClose(actual, expected, label)
    if math.abs(actual - expected) > 1e-6 then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local file = assert(io.open("Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p4_tiny_attention.onnx", "rb"))
local data = file:read("*all")
file:close()
local bytes = {}
for i = 1, #data do
    bytes[i] = string.byte(data, i)
end

local model = Model.parseBytes(bytes)
local expectedOperators = { "MatMul", "Softmax", "MatMul", "Add" }
for i = 1, #expectedOperators do
    if model.graph.nodes[i].opType ~= expectedOperators[i] then
        error("P4 operator inventory mismatch at " .. tostring(i))
    end
end
if model.graph.nodes[2].attributes[1].name ~= "axis" or model.graph.nodes[2].attributes[1].value ~= 1 then
    error("P4 Softmax axis attribute was not indexed")
end

local output = Session.new(model):run({
    hidden = Tensor.new({ 1, 2 }, { 1.0, -1.0 }),
}).logits
assertClose(output.data[1], 1.9807970523834229, "P4 first logit")
assertClose(output.data[2], 1.0192029476165771, "P4 second logit")
if #model.compatibility.unsupported ~= 0 then
    error("P4 compatibility report contains unsupported paths")
end

print("PZONNX P4 transformer-style coverage tests passed")
