local OperatorRegistry = require "PZONNX/Runtime/OperatorRegistry"
local Tensor = require "PZONNX/Tensor"

local InferenceJob = {}
InferenceJob.__index = InferenceJob

local function findValue(values, name)
    local value = values[name]
    if value == nil then
        error("PZONNX graph value is unavailable: " .. tostring(name))
    end
    return value
end

function InferenceJob.new(session, inputs)
    assert(session ~= nil and session.model ~= nil, "PZONNX InferenceJob requires a Session")
    assert(type(inputs) == "table", "PZONNX InferenceJob requires an input table")
    local values = {}
    for name, tensor in pairs(inputs) do
        if not Tensor.isTensor(tensor) then
            error("PZONNX Session input is not a Tensor: " .. tostring(name))
        end
        values[name] = tensor
    end
    return setmetatable({
        session = session,
        values = values,
        cursor = 1,
        state = "pending",
        outputs = nil,
        errorMessage = nil,
    }, InferenceJob)
end

function InferenceJob:_executeNode(node)
    local specification = OperatorRegistry.get(node.domain, node.opType)
    if specification == nil then
        error("PZONNX unsupported operator: " .. tostring(node.domain) .. ":" .. tostring(node.opType))
    end
    if node.attributeCount > 0 and not specification.acceptsAttributes then
        error("PZONNX unsupported node attributes: " .. tostring(node.opType))
    end
    if (specification.inputCount ~= nil and #node.inputs ~= specification.inputCount) or
        #node.outputs ~= specification.outputCount then
        error("PZONNX operator arity mismatch: " .. tostring(node.opType))
    end

    local inputTensors = {}
    for inputIndex = 1, #node.inputs do
        inputTensors[inputIndex] = self.session:_resolveValue(self.values, node.inputs[inputIndex])
    end
    local result = specification.execute(inputTensors, node.attributes)
    if specification.outputCount == 1 then
        self.values[node.outputs[1]] = result
    else
        for outputIndex = 1, specification.outputCount do
            self.values[node.outputs[outputIndex]] = result[outputIndex]
        end
    end
end

function InferenceJob:step(budget)
    assert(type(budget) == "number" and budget > 0 and budget == math.floor(budget),
        "PZONNX InferenceJob.step budget must be a positive integer")
    if self.state == "completed" or self.state == "cancelled" then
        return { done = true, state = self.state, work = 0, cursor = self.cursor, outputs = self.outputs }
    end
    if self.state == "failed" then
        error(self.errorMessage)
    end
    self.state = "running"

    local work = 0
    local nodes = self.session.model.graph.nodes
    while work < budget and self.cursor <= #nodes do
        local node = nodes[self.cursor]
        local ok, err = pcall(function() self:_executeNode(node) end)
        if not ok then
            self.state = "failed"
            self.errorMessage = tostring(err)
            self.values = nil
            error(err)
        end
        self.cursor = self.cursor + 1
        work = work + 1
    end

    if self.cursor > #nodes then
        self.outputs = {}
        for i = 1, #self.session.model.graph.outputs do
            local output = self.session.model.graph.outputs[i]
            self.outputs[output.name] = findValue(self.values, output.name)
        end
        self.state = "completed"
    end
    return {
        done = self.state == "completed",
        state = self.state,
        work = work,
        cursor = self.cursor,
        outputs = self.outputs,
    }
end

function InferenceJob:cancel()
    if self.state == "completed" or self.state == "failed" then
        return false
    end
    self.state = "cancelled"
    self.values = nil
    self.outputs = nil
    return true
end

function InferenceJob:isDone()
    return self.state == "completed" or self.state == "cancelled" or self.state == "failed"
end

function InferenceJob:status()
    return self.state
end

return InferenceJob
