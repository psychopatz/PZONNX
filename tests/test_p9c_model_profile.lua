package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Model = require "PZONNX/ONNX/Model"
local ModelProfile = require "PZONNX/Models/ModelProfile"

local function readFixture()
    local file = assert(io.open("Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p2_linear.onnx", "rb"))
    local data = file:read("*all")
    file:close()
    local bytes = {}
    for index = 1, #data do bytes[index] = string.byte(data, index) end
    return bytes
end

local model = Model.parseBytes(readFixture())
local companionText = {
    ["config.json"] = [[{"model_type":"profile_fixture","architectures":["GenericForCausalLM"],"vocab_size":321,"max_position_embeddings":128,"bos_token_id":1,"eos_token_id":[2,3]}]],
    ["generation_config.json"] = [[{"pad_token_id":0}]],
}
local package = {
    id = "fixture/model.onnx",
    modelPath = "fixture/model.onnx",
    fullModelPath = "Models/fixture/model.onnx",
}
function package:withModelReader(callback)
    return callback({})
end
function package:readCompanionText(name)
    if companionText[name] ~= nil then
        return companionText[name]
    end
    return nil, "missing fixture companion"
end
function package:getCompanion(name)
    return {
        name = name,
        status = companionText[name] ~= nil and "PRESENT" or "MISSING",
        present = companionText[name] ~= nil,
    }
end
function package:resolveExternalData(location)
    return {
        location = location,
        path = "fixture/" .. location,
        fullPath = "Models/fixture/" .. location,
    }
end

-- Use the host-parsed fixture as the explicit user-model reader result. The
-- production path invokes Model.parseReader against UserFile.withReader.
local originalParseReader = Model.parseReader
Model.parseReader = function(reader)
    return model
end
local profile = ModelProfile.inspect(package)
Model.parseReader = originalParseReader

if profile.architecture ~= "profile_fixture" or profile.vocabSize ~= 321 or
        profile.contextLength ~= 128 then
    error("P9C did not prefer explicit model metadata")
end
if profile.bosToken ~= 1 or profile.padToken ~= 0 or #profile.eosTokens ~= 2 then
    error("P9C did not preserve configured token metadata")
end
if #profile.requiredOperators ~= #model.graph.nodes or profile.compatibility ~= model.compatibility then
    error("P9C did not retain generic graph compatibility evidence")
end
if profile.tokenizer.status ~= "MISSING" or profile.confidence <= 0 then
    error("P9C did not preserve unknown tokenizer state or confidence evidence")
end
local sawUnknownTask = false
for _, name in ipairs(profile.unknown) do
    if name == "task" then sawUnknownTask = true end
end
if not sawUnknownTask then
    error("P9C guessed an absent task instead of preserving unknown")
end

print("PZONNX P9C model profile tests passed")
