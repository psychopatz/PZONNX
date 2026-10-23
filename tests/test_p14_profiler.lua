package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Profiler = require "PZONNX/Runtime/Profiler"
local Tensor = require "PZONNX/Tensor"

local now = 100
local profiler = Profiler.new({ enabled = true, maxEvents = 2, clock = function() return now end })
local token = profiler:begin("kernel", { operator = "MatMul" })
now = now + 3
profiler:finish(token, { work = 4 })
profiler:record("scheduler", { work = 1 })
now = now + 2
profiler:recordTensor("tensor", Tensor.fromInt8PackedString(string.char(1, 255), {2}))
local snapshot = profiler:snapshot()
if snapshot.eventCount ~= 2 or snapshot.droppedEvents ~= 1 then
    error("P14 profiler event bound was not enforced")
end
if snapshot.aggregates.kernel == nil or snapshot.aggregates.kernel.work ~= 4 then
    error("P14 profiler aggregate did not retain work metadata")
end
if snapshot.aggregates.tensor == nil or snapshot.aggregates.tensor.count ~= 1 then
    error("P14 profiler did not record tensor storage event")
end
local storage = Tensor.storageReport(Tensor.fromFloat16PackedString(string.char(0, 60), {1}))
if storage.storage ~= "float16" or storage.bytes ~= 2 then
    error("P14 tensor storage report did not preserve packed bytes")
end

local disabled = Profiler.new({ enabled = false, clock = function() return now end })
disabled:record("ignored", { work = 1 })
if disabled:snapshot().eventCount ~= 0 then error("P14 disabled profiler did work") end

print("PZONNX P14 profiler tests passed")
