local Log = require("PZONNX/Diagnostics/Log")

local PZONNX = {
    VERSION = "0.0.1",
    PHASE = "P0",
    Log = Log,
}

function PZONNX.getCapabilities()
    return {
        binaryReader = true,
        protobufWire = true,
        onnxModelParser = false,
        tensorRuntime = false,
        graphExecutor = false,
        llm = false,
        tts = false,
    }
end

return PZONNX
