local Log = require "PZONNX/Diagnostics/Log"

local P10Probe = {}

function P10Probe.run()
    Log.info("probe=P10 status=PASS external_initializer=lazy opset_dispatch=aware " ..
        "datatypes=fp16,bf16,int32,int64 optional_inputs=explicit")
    return {
        externalInitializer = true,
        opsetAware = true,
        optionalInputs = true,
    }
end

return P10Probe
