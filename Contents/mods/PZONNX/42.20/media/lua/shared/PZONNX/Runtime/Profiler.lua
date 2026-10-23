local Profiler = {}
Profiler.__index = Profiler

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function copyFields(fields)
    local result = {}
    for key, value in pairs(fields or {}) do result[key] = value end
    return result
end

local function nowMs(instance)
    local value = instance.clock()
    if not finite(value) then error("PZONNX profiler clock returned a non-finite value") end
    return value
end

function Profiler.new(options)
    options = options or {}
    local clock = options.clock or function()
        if getTimestampMs ~= nil then return getTimestampMs() end
        return 0
    end
    assert(type(clock) == "function", "PZONNX profiler clock must be a function")
    local maxEvents = options.maxEvents or 256
    assert(type(maxEvents) == "number" and maxEvents > 0 and maxEvents == math.floor(maxEvents),
        "PZONNX profiler maxEvents must be a positive integer")
    return setmetatable({
        enabled = options.enabled == true,
        clock = clock,
        maxEvents = maxEvents,
        events = {},
        aggregates = {},
        active = 0,
    }, Profiler)
end

function Profiler:setEnabled(enabled)
    self.enabled = enabled == true
end

function Profiler:isEnabled()
    return self.enabled
end

function Profiler:begin(name, fields)
    if not self.enabled then return nil end
    assert(type(name) == "string" and name ~= "", "PZONNX profiler event name is required")
    self.active = self.active + 1
    return {
        name = name,
        fields = copyFields(fields),
        start = nowMs(self),
    }
end

function Profiler:finish(token, fields)
    if token == nil then return nil end
    local elapsed = nowMs(self) - token.start
    if elapsed < 0 then elapsed = 0 end
    self.active = math.max(0, self.active - 1)
    local aggregate = self.aggregates[token.name]
    if aggregate == nil then
        aggregate = { name = token.name, count = 0, totalMs = 0, maxMs = 0, work = 0 }
        self.aggregates[token.name] = aggregate
    end
    aggregate.count = aggregate.count + 1
    aggregate.totalMs = aggregate.totalMs + elapsed
    if elapsed > aggregate.maxMs then aggregate.maxMs = elapsed end
    local merged = copyFields(token.fields)
    for key, value in pairs(fields or {}) do merged[key] = value end
    if type(merged.work) == "number" then aggregate.work = aggregate.work + merged.work end
    self.totalEvents = (self.totalEvents or 0) + 1
    if #self.events < self.maxEvents then
        table.insert(self.events, {
            name = token.name,
            elapsedMs = elapsed,
            fields = merged,
        })
    end
    return elapsed
end

function Profiler:record(name, fields)
    if not self.enabled then return nil end
    local token = self:begin(name, fields)
    return self:finish(token, fields)
end

function Profiler:wrap(name, callback, fields)
    assert(type(callback) == "function", "PZONNX profiler wrap requires a callback")
    local token = self:begin(name, fields)
    local ok, result = pcall(callback)
    self:finish(token, fields)
    if not ok then error(result) end
    return result
end

function Profiler:recordTensor(name, tensor)
    if not self.enabled then return end
    local fields = {
        storage = tensor and tensor.storageKind or "boxed",
        bytes = tensor and tensor.packed and #tensor.packed or nil,
        elements = tensor and tensor.elementCount and tensor:elementCount() or nil,
    }
    if tensor and tensor.quantized then fields.storage = "quantized" end
    self:record(name, fields)
end

function Profiler:snapshot()
    local aggregates = {}
    for name, aggregate in pairs(self.aggregates) do
        aggregates[name] = copyFields(aggregate)
    end
    local events = {}
    for _, event in ipairs(self.events) do
        table.insert(events, {
            name = event.name,
            elapsedMs = event.elapsedMs,
            fields = copyFields(event.fields),
        })
    end
    return {
        enabled = self.enabled,
        active = self.active,
        eventCount = #self.events,
        droppedEvents = self.totalEvents and self.totalEvents - #self.events or 0,
        aggregates = aggregates,
        events = events,
    }
end

function Profiler:reset()
    self.events = {}
    self.aggregates = {}
    self.active = 0
    self.totalEvents = 0
end

return Profiler
