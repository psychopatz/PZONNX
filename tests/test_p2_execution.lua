package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
local Tensor = require "PZONNX/Tensor"

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertClose(actual, expected, tolerance, label)
    if math.abs(actual - expected) > tolerance then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function readFixture()
    local file = assert(io.open("Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p2_linear.onnx", "rb"))
    local data = file:read("*all")
    file:close()
    local bytes = {}
    for i = 1, #data do
        bytes[i] = string.byte(data, i)
    end
    return bytes
end

local model = Model.parseBytes(readFixture())
local session = Session.new(model)
local output = session:run({
    input = Tensor.new({ 1, 2 }, { 3.0, 4.0 }),
}).output

assertEqual(#output.shape, 2, "output rank")
assertEqual(output.shape[1], 1, "output rows")
assertEqual(output.shape[2], 1, "output columns")
assertClose(output.data[1], 2.5, 1e-6, "linear output")

do
    local ok, err = pcall(function()
        Tensor.matmul(Tensor.new({ 1, 3 }, { 1, 2, 3 }), Tensor.new({ 2, 1 }, { 1, 1 }))
    end)
    if ok or not string.find(tostring(err), "shape mismatch", 1, true) then
        error("MatMul shape mismatch was not rejected explicitly: " .. tostring(err))
    end
end

print("PZONNX P2 numerical execution tests passed")
