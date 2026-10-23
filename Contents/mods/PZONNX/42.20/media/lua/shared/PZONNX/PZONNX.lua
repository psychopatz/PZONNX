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
local P9AProbe = require "PZONNX/Diagnostics/P9AProbe"
local P9BProbe = require "PZONNX/Diagnostics/P9BProbe"
local P9CProbe = require "PZONNX/Diagnostics/P9CProbe"
local P9DProbe = require "PZONNX/Diagnostics/P9DProbe"
local P10Probe = require "PZONNX/Diagnostics/P10Probe"
local P11Probe = require "PZONNX/Diagnostics/P11Probe"
local P12Probe = require "PZONNX/Diagnostics/P12Probe"
local P13Probe = require "PZONNX/Diagnostics/P13Probe"
local P14Probe = require "PZONNX/Diagnostics/P14Probe"
local P15Probe = require "PZONNX/Diagnostics/P15Probe"
local P17Probe = require "PZONNX/Diagnostics/P17Probe"
local TinyTTS = require "PZONNX/Adapters/TinyTTS"
local Model = require "PZONNX/ONNX/Model"
local Session = require "PZONNX/Runtime/Session"
local Tensor = require "PZONNX/Tensor"
local OperatorRegistry = require "PZONNX/Runtime/OperatorRegistry"
local TinyLM = require "PZONNX/Adapters/TinyLM"
local InferenceJob = require "PZONNX/Runtime/InferenceJob"
local Fallback = require "PZONNX/Adapters/Fallback"
local UserFile = require "PZONNX/IO/UserFile"
local ModelStore = require "PZONNX/Models/ModelStore"
local ModelPackage = require "PZONNX/Models/ModelPackage"
local ModelProfile = require "PZONNX/Models/ModelProfile"
local ModelProbe = require "PZONNX/Models/ModelProbe"
local Tokenizer = require "PZONNX/Models/Tokenizer"
local Decoder = require "PZONNX/Runtime/Decoder"
local Sampler = require "PZONNX/Runtime/Sampler"
local Profiler = require "PZONNX/Runtime/Profiler"
local CompatibilityMatrix = require "PZONNX/Models/CompatibilityMatrix"
local Generator = require "PZONNX/Runtime/Generator"
local Pipeline = require "PZONNX/Runtime/Pipeline"

local PZONNX = {
    VERSION = "0.0.1",
    PHASE = "P16",
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
        userFileAdapter = true,
        modelStore = true,
        modelLedger = true,
        p9aProbe = true,
        modelPackage = true,
        p9bProbe = true,
        modelProfile = true,
        p9cProbe = true,
        modelProbe = true,
        p9dProbe = true,
        modelPackageLoader = true,
        externalInitializer = true,
        opsetAwareDispatch = true,
        fp16Initializer = true,
        bfloat16Initializer = true,
        int32Initializer = true,
        int64Initializer = true,
        optionalInputs = true,
        p10Probe = true,
        tokenizerRuntime = true,
        tokenizerBPE = true,
        p11Probe = true,
        decoderRuntime = true,
        kvCache = true,
        p12Probe = true,
        sampler = true,
        seededSampling = true,
        p13Probe = true,
        profiler = true,
        storageMetrics = true,
        p14Probe = true,
        compatibilityMatrix = true,
        p15Probe = true,
        generator = true,
        textGenerationAPI = true,
        pipeline = true,
        ttsPipelineBoundary = true,
        p17Probe = true,
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

function PZONNX.runP9AProbe()
    return P9AProbe.run()
end

function PZONNX.runP9BProbe()
    return P9BProbe.run()
end

function PZONNX.runP9CProbe()
    return P9CProbe.run()
end

function PZONNX.runP9DProbe()
    return P9DProbe.run()
end

function PZONNX.runP10Probe()
    return P10Probe.run()
end

function PZONNX.runP11Probe()
    return P11Probe.run()
end

function PZONNX.runP12Probe()
    return P12Probe.run()
end

function PZONNX.runP13Probe()
    return P13Probe.run()
end

function PZONNX.runP14Probe()
    return P14Probe.run()
end

function PZONNX.runP15Probe()
    return P15Probe.run()
end

function PZONNX.runP17Probe()
    return P17Probe.run()
end

function PZONNX.refreshModels()
    return ModelStore.refresh()
end

function PZONNX.listModels()
    return ModelStore.listModels()
end

function PZONNX.getModelEntry(idOrPath)
    return ModelStore.getModelEntry(idOrPath)
end

function PZONNX.getModelDiagnostics()
    return ModelStore.getDiagnostics()
end

function PZONNX.getModelPackage(idOrPath)
    return ModelPackage.forEntry(idOrPath)
end

function PZONNX.getModelProfile(idOrPath)
    return ModelProfile.forEntry(idOrPath)
end

function PZONNX.probeModel(idOrPath, options)
    return ModelProbe.forEntry(idOrPath, options)
end

function PZONNX.newTokenizer(idOrPath, profile, options)
    local modelPackage, reason = ModelPackage.forEntry(idOrPath)
    if modelPackage == nil then
        error("PZONNX could not load tokenizer package: " .. tostring(reason))
    end
    return Tokenizer.fromPackage(modelPackage, profile, options and options.profiler)
end

function PZONNX.encode(idOrPath, text, options)
    return PZONNX.newTokenizer(idOrPath, nil, options):encode(text, options)
end

function PZONNX.decode(idOrPath, tokenIds, options)
    return PZONNX.newTokenizer(idOrPath, nil, options):decode(tokenIds, options)
end

function PZONNX.newDecoder(session, profile, options)
    return Decoder.new(session, profile, options)
end

function PZONNX.newDecoderForEntry(idOrPath, options)
    local modelPackage, reason = ModelPackage.forEntry(idOrPath)
    if modelPackage == nil then
        error("PZONNX could not load decoder package: " .. tostring(reason))
    end
    local model = Model.loadPackage(modelPackage)
    local profile = ModelProfile.inspect(modelPackage)
    return Decoder.new(Session.new(model, options), profile, options)
end

function PZONNX.newSampler(options)
    return Sampler.new(options)
end

function PZONNX.newGenerator(decoder, tokenizer, sampler, options)
    return Generator.new(decoder, tokenizer, sampler, options)
end

function PZONNX.newGeneratorForEntry(idOrPath, options)
    options = options or {}
    local modelPackage, reason = ModelPackage.forEntry(idOrPath)
    if modelPackage == nil then
        error("PZONNX could not load generator package: " .. tostring(reason))
    end
    local profile = ModelProfile.inspect(modelPackage)
    local model = Model.loadPackage(modelPackage)
    local session = Session.new(model, options)
    local decoder = Decoder.new(session, profile, options)
    local tokenizer = Tokenizer.fromPackage(modelPackage, profile, options.profiler)
    local sampler = Sampler.new(options.samplerOptions or options)
    return Generator.new(decoder, tokenizer, sampler, options)
end

function PZONNX.generateText(idOrPath, prompt, options)
    options = options or {}
    local generator = PZONNX.newGeneratorForEntry(idOrPath, options)
    return generator:run(prompt, options.budget or 1, options.stepLimit)
end

function PZONNX.newPipeline(generator, options)
    return Pipeline.new(generator, options)
end

function PZONNX.newPipelineForEntry(idOrPath, options)
    options = options or {}
    return Pipeline.new(PZONNX.newGeneratorForEntry(idOrPath, options), options)
end

function PZONNX.newProfiler(options)
    return Profiler.new(options)
end

function PZONNX.assessCompatibility(report)
    return CompatibilityMatrix.assess(report)
end

function PZONNX.compareCompatibility(reports)
    return CompatibilityMatrix.compare(reports)
end

function PZONNX.loadModel(relativePath)
    return Model.loadFile(relativePath)
end

function PZONNX.loadModelPackage(idOrPath)
    local modelPackage, reason = ModelPackage.forEntry(idOrPath)
    if modelPackage == nil then
        error("PZONNX could not load user model package: " .. tostring(reason))
    end
    return Model.loadPackage(modelPackage)
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
            P9A = "OPEN/UNVERIFIED",
            P9B = "OPEN/UNVERIFIED",
            P9C = "OPEN/UNVERIFIED",
            P9D = "OPEN/UNVERIFIED",
            P10 = "OPEN/UNVERIFIED",
            P11 = "OPEN/UNVERIFIED",
            P12 = "OPEN/UNVERIFIED",
            P13 = "OPEN/UNVERIFIED",
            P14 = "OPEN/UNVERIFIED",
            P15 = "PARTIAL/REAL_FAMILIES_OPEN",
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
PZONNX.UserFile = UserFile
PZONNX.ModelStore = ModelStore
PZONNX.ModelPackage = ModelPackage
PZONNX.ModelProfile = ModelProfile
PZONNX.ModelProbe = ModelProbe
PZONNX.Tokenizer = Tokenizer
PZONNX.Decoder = Decoder
PZONNX.Sampler = Sampler
PZONNX.Profiler = Profiler
PZONNX.CompatibilityMatrix = CompatibilityMatrix
PZONNX.Generator = Generator
PZONNX.Pipeline = Pipeline

return PZONNX
