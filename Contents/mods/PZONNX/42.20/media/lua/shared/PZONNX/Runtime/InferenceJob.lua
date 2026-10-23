local OperatorRegistry = require "PZONNX/Runtime/OperatorRegistry"
local Tensor = require "PZONNX/Tensor"

local InferenceJob = {}
InferenceJob.__index = InferenceJob
InferenceJob.KERNEL_WORK_BUDGET = 4096

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
        activeNode = nil,
    }, InferenceJob)
end

function InferenceJob:_prepareNode(node)
    local opsetVersion = nil
    for _, opset in ipairs(self.session.model.opsetImports or {}) do
        if opset.domain == node.domain then
            opsetVersion = opset.version
            break
        end
    end
    local specification = OperatorRegistry.get(node.domain, node.opType, opsetVersion)
    if specification == nil then
        error("PZONNX unsupported operator/opset: " .. tostring(node.domain) .. ":" ..
            tostring(node.opType) .. " opset=" .. tostring(opsetVersion))
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
        local inputName = node.inputs[inputIndex]
        if inputName == "" then
            inputTensors[inputIndex] = nil
        else
            inputTensors[inputIndex] = self.session:_resolveValue(self.values, inputName)
        end
    end
    return specification, inputTensors
end

function InferenceJob:_storeNodeResult(node, specification, result)
    if specification.outputCount == 1 then
        self.values[node.outputs[1]] = result
    else
        for outputIndex = 1, specification.outputCount do
            self.values[node.outputs[outputIndex]] = result[outputIndex]
        end
    end
end

function InferenceJob:_executeNode(node, specification, inputTensors)
    local result = specification.execute(inputTensors, node.attributes)
    self:_storeNodeResult(node, specification, result)
end

function InferenceJob:step(budget)
    assert(type(budget) == "number" and budget > 0 and budget == math.floor(budget),
        "PZONNX InferenceJob.step budget must be a positive integer")
    local profilerToken = self.session.profiler and self.session.profiler:begin("inference.step", {
        cursor = self.cursor,
    })
    if self.state == "completed" or self.state == "cancelled" then
        if profilerToken ~= nil then
            self.session.profiler:finish(profilerToken, { work = 0, state = self.state })
        end
        return { done = true, state = self.state, work = 0, cursor = self.cursor, outputs = self.outputs }
    end
    if self.state == "failed" then
        error(self.errorMessage)
    end
    self.state = "running"

    local work = 0
    local nodes = self.session.model.graph.nodes
    while work < budget and (self.cursor <= #nodes or self.activeNode ~= nil) do
        if self.activeNode == nil then
            local node = nodes[self.cursor]
            local prepareOK, specification, inputTensors = pcall(function()
                return self:_prepareNode(node)
            end)
            if not prepareOK then
                self.state = "failed"
                self.errorMessage = tostring(specification)
                self.values = nil
                error(specification)
            end

            if specification.begin ~= nil and specification.step ~= nil then
                local beginOK, state = pcall(function()
                    return specification.begin(inputTensors, node.attributes)
                end)
                if not beginOK then
                    self.state = "failed"
                    self.errorMessage = tostring(state)
                    self.values = nil
                    error(state)
                end
                self.activeNode = {
                    node = node,
                    specification = specification,
                    inputTensors = inputTensors,
                    state = state,
                }
            else
                local executeOK, err = pcall(function()
                    self:_executeNode(node, specification, inputTensors)
                end)
                if not executeOK then
                    self.state = "failed"
                    self.errorMessage = tostring(err)
                    self.values = nil
                    error(err)
                end
                self.cursor = self.cursor + 1
                work = work + 1
                if self.session.profiler ~= nil then
                    self.session.profiler:record("operator." .. tostring(node.opType), { work = 1 })
                end
            end
        end

        if self.activeNode ~= nil and work < budget then
            local active = self.activeNode
            local stepOK, result, kernelWork, done = pcall(function()
                return active.specification.step(active.inputTensors,
                    active.node.attributes, active.state, InferenceJob.KERNEL_WORK_BUDGET)
            end)
            if not stepOK then
                self.state = "failed"
                self.errorMessage = tostring(result)
                self.values = nil
                self.activeNode = nil
                error(result)
            end
            if type(kernelWork) ~= "number" or kernelWork < 0 or
                kernelWork ~= math.floor(kernelWork) then
                self.state = "failed"
                self.errorMessage = "PZONNX resumable operator returned invalid work"
                self.values = nil
                self.activeNode = nil
                error(self.errorMessage)
            end
            if kernelWork == 0 and not done then
                self.state = "failed"
                self.errorMessage = "PZONNX resumable operator made no progress"
                self.values = nil
                self.activeNode = nil
                error(self.errorMessage)
            end
            work = work + 1
            if done then
                self:_storeNodeResult(active.node, active.specification, result)
                self.activeNode = nil
                self.cursor = self.cursor + 1
                if self.session.profiler ~= nil then
                    self.session.profiler:record("operator." .. tostring(active.node.opType), { work = kernelWork })
                end
            else
                break
            end
        end
    end

    if self.cursor > #nodes then
        self.outputs = {}
        for i = 1, #self.session.model.graph.outputs do
            local output = self.session.model.graph.outputs[i]
            self.outputs[output.name] = findValue(self.values, output.name)
        end
        self.state = "completed"
    end
    if profilerToken ~= nil then
        self.session.profiler:finish(profilerToken, {
            work = work,
            cursor = self.cursor,
            state = self.state,
        })
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
    self.activeNode = nil
    return true
end

function InferenceJob:isDone()
    return self.state == "completed" or self.state == "cancelled" or self.state == "failed"
end

function InferenceJob:status()
    return self.state
end

return InferenceJob
