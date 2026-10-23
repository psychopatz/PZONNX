local Log = require("PZONNX/Diagnostics/Log")
local P0Probe = require("PZONNX/Diagnostics/P0Probe")

local PZONNX = {
    VERSION = "0.0.1",
    PHASE = "P0",
    Log = Log,
}

function PZONNX.getCapabilities()
    return {
        binaryReader = true,
        packagedGameFileAdapter = true,
        protobufWire = true,
        p0Probe = true,
        onnxModelParser = false,
        tensorRuntime = false,
        graphExecutor = false,
        llm = false,
        tts = false,
    }
end

function PZONNX.runP0Probe()
    return P0Probe.run()
end

return PZONNX
