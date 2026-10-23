package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Model = require("PZONNX/ONNX/Model")

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertFails(fn, expectedText, label)
    local ok, err = pcall(fn)
    if ok then
        error((label or "failure") .. ": expected an error")
    end
    if expectedText ~= nil and not string.find(tostring(err), expectedText, 1, true) then
        error((label or "failure") .. ": missing error text " .. expectedText .. ", got " .. tostring(err))
    end
end

local function readFixture()
    local file = assert(io.open("Contents/mods/PZONNX/42.20/media/pzonnx/fixtures/p0b_minimal.onnx", "rb"))
    local data = file:read("*all")
    file:close()
    local bytes = {}
    for i = 1, #data do
        bytes[i] = string.byte(data, i)
    end
    return bytes
end

do
    local model = Model.parseBytes(readFixture())
    assertEqual(model.irVersion, 8, "ir_version")
    assertEqual(model.producerName, "PZONNX", "producer_name")
    assertEqual(model.producerVersion, "0.1.0", "producer_version")
    assertEqual(#model.opsetImports, 1, "opset count")
    assertEqual(model.opsetImports[1].domain, "", "opset domain")
    assertEqual(model.opsetImports[1].version, 13, "opset version")
    assertEqual(model.graph.name, "pzonxx_p0b_graph", "graph name")
    assertEqual(model.graph.nodeCount, 1, "node count")
    assertEqual(model.graph.inputCount, 1, "input count")
    assertEqual(model.graph.outputCount, 1, "output count")
end

do
    local bytes = readFixture()
    table.insert(bytes, 0xA0) -- field 20, wire type 0: unknown field must be skippable
    table.insert(bytes, 0x01)
    table.insert(bytes, 0x07)
    local model = Model.parseBytes(bytes)
    assertEqual(model.irVersion, 8, "unknown-field ir_version")
end

assertFails(function()
    Model.parseBytes({ 0x12, 0x05, 0x50 })
end, "truncated", "truncated length-delimited field")

assertFails(function()
    Model.parseBytes({ 0x08, 0x08, 0x3A, 0x03, 0x12, 0x01, 0x67 })
end, "missing opset_import", "missing required opset import")

print("PZONNX P0B model metadata tests passed")
