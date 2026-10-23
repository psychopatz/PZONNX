package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local InferenceJob = require "PZONNX/Runtime/InferenceJob"
local Session = require "PZONNX/Runtime/Session"
local Tensor = require "PZONNX/Tensor"

local model = {
    graph = {
        nodes = {
            {
                domain = "",
                opType = "MatMul",
                attributeCount = 0,
                inputs = { "input", "weight" },
                outputs = { "output" },
            },
        },
        outputs = { { name = "output" } },
        initializerIndex = {},
    },
}

local session = Session.new(model)
session.initializerTensors.weight = Tensor.new({ 4, 1 }, { 2.0, 3.0, 4.0, 5.0 })

local originalBudget = InferenceJob.KERNEL_WORK_BUDGET
InferenceJob.KERNEL_WORK_BUDGET = 2
local job = session:newJob({ input = Tensor.new({ 1, 4 }, { 1.0, 1.0, 1.0, 1.0 }) })
local first = job:step(1)
InferenceJob.KERNEL_WORK_BUDGET = originalBudget

if first.done or first.cursor ~= 1 or first.work ~= 1 then
    error("resumable MatMul did not yield inside the operator")
end

local second = job:step(1)
if not second.done or second.cursor ~= 2 or
    math.abs(second.outputs.output.data[1] - 14.0) > 1e-6 then
    error("resumable MatMul did not preserve the reference result")
end

print("PZONNX resumable MatMul tests passed")
