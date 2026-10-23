package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local UserFile = require "PZONNX/IO/UserFile"
local ModelStore = require "PZONNX/Models/ModelStore"

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(message .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
end

local function assertRejected(path)
    local normalized, reason = UserFile.validateRelativePath(path)
    if normalized ~= nil or reason == nil then
        error("unsafe user path was accepted: " .. tostring(path))
    end
end

assertEqual(UserFile.validateRelativePath("tiny/model.onnx"), "tiny/model.onnx",
    "nested model path was not preserved")
assertEqual(UserFile.validateRelativePath("  folder\\model.onnx  "), "folder/model.onnx",
    "separators or surrounding whitespace were not normalized")
assertEqual(UserFile.resolve("tiny/model.onnx"), "Models/tiny/model.onnx",
    "user model path did not remain under Models")

assertRejected("")
assertRejected("../outside.onnx")
assertRejected("tiny/../../outside.onnx")
assertRejected("./model.onnx")
assertRejected("/absolute/model.onnx")
assertRejected("//server/share/model.onnx")
assertRejected("\\\\server\\share\\model.onnx")
assertRejected("C:/models/model.onnx")
assertRejected("C:model.onnx")
assertRejected("tiny//model.onnx")
assertRejected("tiny/model.onnx/")
assertRejected("tiny/\0model.onnx")

local openedPath = nil
local closed = false
local bytes = {}
for index = 1, #"# test ledger\n" do
    bytes[index] = string.byte("# test ledger\n", index)
end
local stream = {
    index = 0,
}
function stream:readUnsignedByte()
    self.index = self.index + 1
    return bytes[self.index]
end
function stream:available()
    return #bytes - self.index
end
function stream:close()
    closed = true
end

getFileInput = function(path)
    openedPath = path
    return stream
end

local text, readReason = UserFile.tryReadText("ledger.txt")
if text ~= "# test ledger\n" or readReason ~= nil then
    error("supported user-file adapter did not read bounded text")
end
assertEqual(openedPath, "Models/ledger.txt", "user-file adapter escaped its Models root")
if not closed then
    error("user-file adapter did not close the stream")
end

local existsCalls = {}
local ledger = [[
# comments and blank lines are ignored

tiny/model.onnx
missing/model.onnx
../outside.onnx
tiny/model.onnx
folder\second.onnx
]]
local registry = ModelStore.refreshFromText(ledger, function(path)
    table.insert(existsCalls, path)
    return path == "tiny/model.onnx" or path == "folder/second.onnx"
end)

assertEqual(registry.ledgerStatus, "READABLE", "ledger fixture was not readable")
assertEqual(registry.entryCount, 5, "unexpected non-comment ledger entry count")
assertEqual(registry.registeredCount, 2, "registered model count was incorrect")
assertEqual(registry.missingCount, 1, "missing model count was incorrect")
assertEqual(registry.invalidCount, 2, "invalid model count was incorrect")
assertEqual(#existsCalls, 3, "invalid and duplicate entries performed existence checks")
assertEqual(existsCalls[1], "tiny/model.onnx", "first existence check was not canonical")
assertEqual(existsCalls[2], "missing/model.onnx", "missing existence check was not isolated")
assertEqual(existsCalls[3], "folder/second.onnx", "backslash path was not normalized")

local registered = ModelStore.getModelEntry("tiny/model.onnx")
if registered == nil or registered.status ~= ModelStore.STATUS_REGISTERED then
    error("registered model entry was not retrievable by path")
end
local missing = ModelStore.getModelEntry("missing/model.onnx")
if missing == nil or missing.status ~= ModelStore.STATUS_MISSING then
    error("missing model entry was not preserved as a diagnostic")
end
local duplicate = ModelStore.getModelEntry("line:6")
if duplicate == nil or duplicate.status ~= ModelStore.STATUS_INVALID or
        duplicate.reason ~= "duplicate of ledger line 3" then
    error("duplicate ledger entry was not deterministic")
end
if ModelStore.getModelEntry("../outside.onnx") ~= nil then
    error("invalid path was exposed as a model lookup")
end

local listed = ModelStore.listModels()
assertEqual(#listed, 5, "listModels did not preserve invalid entries")
assertEqual(#ModelStore.getDiagnostics(), 3, "diagnostics did not preserve missing and invalid entries")

print("PZONNX P9A model store/ledger tests passed")
