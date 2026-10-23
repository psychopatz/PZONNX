local Log = require "PZONNX/Diagnostics/Log"
local P0Probe = require "PZONNX/Diagnostics/P0Probe"
local P0BProbe = require "PZONNX/Diagnostics/P0BProbe"
local P1Probe = require "PZONNX/Diagnostics/P1Probe"
local P2Probe = require "PZONNX/Diagnostics/P2Probe"
local P3Probe = require "PZONNX/Diagnostics/P3Probe"
local P4Probe = require "PZONNX/Diagnostics/P4Probe"
local P5Probe = require "PZONNX/Diagnostics/P5Probe"
local P6Probe = require "PZONNX/Diagnostics/P6Probe"
local P7Probe = require "PZONNX/Diagnostics/P7Probe"
local P8Probe = require "PZONNX/Diagnostics/P8Probe"
local TinyTTS = require "PZONNX/Adapters/TinyTTS"
local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
local Tensor = require "PZONNX/Tensor"
local OperatorRegistry = require "PZONNX/Runtime/OperatorRegistry"
local TinyLM = require "PZONNX/Adapters/TinyLM"
local InferenceJob = require "PZONNX/Runtime/InferenceJob"
local Fallback = require "PZONNX/Adapters/Fallback"

local PZONNX = {
    VERSION = "0.0.1",
    PHASE = "P8",
    Log = Log,
}

function PZONNX.getCapabilities()
    return {
        binaryReader = true,
        packagedGameFileAdapter = true,
        protobufWire = true,
        p0Probe = true,
        p0bProbe = true,
        p1Probe = true,
        onnxModelParser = true,
        tensorRuntime = true,
        graphExecutor = true,
        tensor = true,
        matmul = true,
        add = true,
        operatorRegistry = true,
        p3Probe = true,
        softmax = true,
        p4Probe = true,
        gather = true,
        tinyLMOneToken = true,
        p5Probe = true,
        inferenceJob = true,
        int8Weights = true,
        p6Probe = true,
        ttsNumeric = true,
        p7Probe = true,
        fallbackBoundary = true,
        p8Probe = true,
        p2Probe = true,
        llm = false,
        tts = false,
    }
end

function PZONNX.runP0Probe()
    return P0Probe.run()
end

function PZONNX.runP0BProbe()
    return P0BProbe.run()
end

function PZONNX.runP1Probe()
    return P1Probe.run()
end

function PZONNX.runP2Probe()
    return P2Probe.run()
end

function PZONNX.runP3Probe()
    return P3Probe.run()
end

function PZONNX.runP4Probe()
    return P4Probe.run()
end

function PZONNX.runP5Probe()
    return P5Probe.run()
end

function PZONNX.runP6Probe()
    return P6Probe.run()
end

function PZONNX.runP7Probe()
    return P7Probe.run()
end

function PZONNX.runP8Probe()
    return P8Probe.run()
end

function PZONNX.loadModel(relativePath)
    return Model.loadFile(relativePath)
end

function PZONNX.newSession(model, options)
    return Session.new(model, options)
end

function PZONNX.inspectModel(model)
    assert(type(model) == "table" and model.compatibility ~= nil,
        "PZONNX.inspectModel requires a parsed model")
    return model.compatibility
end

function PZONNX.createInferenceJob(session, inputs)
    assert(session ~= nil and type(session.newJob) == "function",
        "PZONNX.createInferenceJob requires a Session")
    return session:newJob(inputs)
end

function PZONNX.newFallbackAdapter(primary, fallback, logger)
    return Fallback.new(primary, fallback, logger)
end

function PZONNX.getRuntimeStatus()
    return {
        version = PZONNX.VERSION,
        phase = PZONNX.PHASE,
        nativeGates = {
            P0A = "OPEN/UNVERIFIED",
            P0B = "OPEN/UNVERIFIED",
            P1 = "OPEN/UNVERIFIED",
            P2 = "OPEN/UNVERIFIED",
            P3 = "OPEN/UNVERIFIED",
            P4 = "OPEN/UNVERIFIED",
            P5 = "OPEN/UNVERIFIED",
            P6 = "OPEN/UNVERIFIED",
            P7 = "OPEN/UNVERIFIED",
        },
    }
end

PZONNX.Tensor = Tensor
PZONNX.Session = Session
PZONNX.OperatorRegistry = OperatorRegistry
PZONNX.TinyLM = TinyLM
PZONNX.InferenceJob = InferenceJob
PZONNX.TinyTTS = TinyTTS
PZONNX.Fallback = Fallback

return PZONNX
