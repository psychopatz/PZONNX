package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Model = require "PZONNX/ONNX/Model"
local OperatorRegistry = require "PZONNX/Runtime/OperatorRegistry"
local Session = require "PZONNX/Runtime/Session"
local Tensor = require "PZONNX/Tensor"

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertClose(actual, expected, label)
    if math.abs(actual - expected) > 1e-6 then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function readFixture()
    local file = assert(io.open("Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p3_broadcast.onnx", "rb"))
    local data = file:read("*all")
    file:close()
    local bytes = {}
    for i = 1, #data do
        bytes[i] = string.byte(data, i)
    end
    return bytes
end

assertEqual(OperatorRegistry.describe("", "Add", 0), "supported", "Add registry")
assertEqual(OperatorRegistry.describe("", "Unknown", 0), "unsupported", "unknown registry")

local model = Model.parseBytes(readFixture())
assertEqual(model.compatibility.operators[1].execution, "supported", "compatibility prediction")
assertEqual(#model.compatibility.unsupported, 0, "supported compatibility report")
local output = Session.new(model):run({
    input = Tensor.new({ 1, 2 }, { 3.0, 4.0 }),
}).output
assertEqual(output.shape[1], 1, "broadcast output rows")
assertEqual(output.shape[2], 2, "broadcast output columns")
assertClose(output.data[1], 3.5, "broadcast output first")
assertClose(output.data[2], 3.5, "broadcast output second")

do
    local ok, err = pcall(function()
        Tensor.add(Tensor.new({ 2 }, { 1, 2 }), Tensor.new({ 3 }, { 1, 2, 3 }))
    end)
    if ok or not string.find(tostring(err), "broadcast shape mismatch", 1, true) then
        error("incompatible broadcast was not rejected explicitly: " .. tostring(err))
    end
end

print("PZONNX P3 operator registry tests passed")
