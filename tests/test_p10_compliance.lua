package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local BinaryReader = require "PZONNX/IO/BinaryReader"
local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
local Tensor = require "PZONNX/Tensor"

local function readBytes(path)
    local file = assert(io.open(path, "rb"))
    local data = file:read("*all")
    file:close()
    local bytes = {}
    for index = 1, #data do bytes[index] = string.byte(data, index) end
    return bytes
end

local function bytesToString(bytes)
    local chars = {}
    for index = 1, #bytes do chars[index] = string.char(bytes[index]) end
    return table.concat(chars)
end

local function assertNear(actual, expected, message)
    if math.abs(actual - expected) > 1e-5 then
        error(message .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
end

assertNear(Tensor.valueAt(Tensor.fromFloat16PackedString(string.char(0, 60), {1}), 1), 1.0,
    "FP16 decode")
assertNear(Tensor.valueAt(Tensor.fromBFloat16PackedString(string.char(192, 63), {1}), 1), 1.5,
    "BF16 decode")
if Tensor.valueAt(Tensor.fromInt32PackedString(string.char(255, 255, 255, 255), {1}), 1) ~= -1 then
    error("INT32 packed decode")
end
if Tensor.valueAt(Tensor.fromInt64PackedString(string.char(2, 0, 0, 0, 0, 0, 0, 0), {1}), 1) ~= 2 then
    error("INT64 packed decode")
end

local modelBytes = readBytes("Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p1_metadata.onnx")
local externalBytes = readBytes("Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p1_external_weights.bin")
local fakePackage = {
    id = "fixture/p1_metadata.onnx",
    modelPath = "fixture/p1_metadata.onnx",
}
function fakePackage:withModelReader(callback)
    return callback(BinaryReader.fromBytes(modelBytes))
end
function fakePackage:withExternalReader(location, callback)
    if location ~= "p1_external_weights.bin" then
        error("unexpected external-data location: " .. tostring(location))
    end
    return callback(BinaryReader.fromBytes(externalBytes))
end

local model = Model.loadPackage(fakePackage)
local external = model.graph.initializerIndex.external_weight
local externalPacked = Model.readInitializerPackedBytes(model, external)
if #externalPacked ~= #externalBytes then
    error("external initializer length was not read from its package file")
end
local inline = model.graph.initializerIndex.weight
if #Model.readInitializerPackedBytes(model, inline) ~= inline.rawData.length then
    error("inline initializer source reader regressed for package models")
end

local future = Model.parseBytes(modelBytes)
future.opsetImports[1].version = 99
local futureReport = Model.buildCompatibilityReport(future)
if futureReport.operators[1].execution ~= "unsupported-opset" or #futureReport.unsupported == 0 then
    error("opset-aware compatibility did not reject an unsupported future opset")
end
future.graph.initializers[1].dataType = 11
local datatypeReport = Model.buildCompatibilityReport(future)
if #datatypeReport.datatypeGaps == 0 then
    error("datatype compatibility did not preserve an unsupported initializer gap")
end

local optionalModel = {
    opsetImports = {{ domain = "", version = 13 }},
    graph = {
        nodes = {{
            domain = "",
            opType = "Slice",
            inputs = {"input", "starts", "ends", "", ""},
            outputs = {"output"},
            attributes = {},
            attributeCount = 0,
        }},
        initializerIndex = {},
        outputs = {{ name = "output" }},
    },
}
local optionalResult = Session.new(optionalModel):run({
    input = Tensor.new({3}, {10, 20, 30}),
    starts = Tensor.new({1}, {0}, 7),
    ends = Tensor.new({1}, {2}, 7),
})
if optionalResult.output.data[1] ~= 10 or optionalResult.output.data[2] ~= 20 then
    error("optional empty Slice inputs were not handled according to ONNX semantics")
end

print("PZONNX P10 compliance tests passed")
