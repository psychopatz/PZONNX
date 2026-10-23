package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
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

local model = Model.parseBytes(readFixture())
local input = Tensor.new({ 1, 2 }, { 3.0, 4.0 })

do
    local job = Session.new(model):newJob({ input = input })
    local first = job:step(1)
    if first.done or first.work ~= 1 or first.cursor ~= 2 then
        error("P6 first bounded step did not stop after one node")
    end
    local second = job:step(1)
    if not second.done or second.state ~= "completed" or math.abs(second.outputs.output.data[1] - 2.5) > 1e-6 then
        error("P6 resumed job did not produce the reference output")
    end
end

do
    local job = Session.new(model):newJob({ input = input })
    job:step(1)
    if not job:cancel() or job:status() ~= "cancelled" then
        error("P6 cancellation did not cleanly transition to cancelled")
    end
    if not job:step(1).done then
        error("P6 cancelled job was not terminal")
    end
end

do
    local session = Session.new(model, { quantizedWeightScale = 0.02 })
    local output = session:run({ input = input }).output
    if math.abs(output.data[1] - 2.5) > 1e-6 then
        error("P6 quantized output exceeded tolerance: " .. tostring(output.data[1]))
    end
    local floatBytes = Tensor.storageBytes(Tensor.new({ 2, 1 }, { 2.0, -1.0 }))
    local quantized = session.initializerTensors.weight
    if not quantized.quantized or Tensor.storageBytes(quantized) >= floatBytes then
        error("P6 quantized initializer did not reduce storage")
    end
end

print("PZONNX P6 resumable/quantized tests passed")
