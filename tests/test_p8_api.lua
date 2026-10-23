package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local PZONNX = require "PZONNX/PZONNX"
local Model = require "PZONNX/ONNX/Model"
local Tensor = require "PZONNX/Tensor"

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

local capabilities = PZONNX.getCapabilities()
if not capabilities.graphExecutor or not capabilities.inferenceJob or not capabilities.fallbackBoundary then
    error("P8 public capabilities are incomplete")
end

local model = Model.parseBytes(readFixture())
local report = PZONNX.inspectModel(model)
if #report.operators ~= 2 or report.operators[1].execution ~= "supported" then
    error("P8 model inspection API returned an incomplete report")
end

local session = PZONNX.newSession(model)
local job = PZONNX.createInferenceJob(session, {
    input = Tensor.new({ 1, 2 }, { 3.0, 4.0 }),
})
job:step(1)
local result = job:step(1)
if not result.done or math.abs(result.outputs.output.data[1] - 2.5) > 1e-6 then
    error("P8 public job API did not preserve P2 output")
end

local messages = {}
local degraded = PZONNX.newFallbackAdapter(
    function() error("unsupported test path") end,
    function(primaryError, value) return "fallback:" .. primaryError .. ":" .. tostring(value) end,
    function(message) table.insert(messages, message) end
):run("input")
if degraded.source ~= "fallback" or #messages ~= 1 then
    error("P8 fallback boundary did not degrade cleanly")
end

local successful = PZONNX.newFallbackAdapter(
    function(value) return "primary:" .. tostring(value) end,
    function() return "unexpected" end
):run("input")
if successful.source ~= "pzonxx" or successful.value ~= "primary:input" then
    error("P8 primary adapter path was not preserved")
end

local status = PZONNX.getRuntimeStatus()
if status.nativeGates.P0A ~= "OPEN/UNVERIFIED" or status.nativeGates.P7 ~= "OPEN/UNVERIFIED" then
    error("P8 runtime status hid open native gates")
end

print("PZONNX P8 public API/fallback tests passed")
