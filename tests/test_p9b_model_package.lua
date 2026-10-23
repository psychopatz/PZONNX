package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local ModelStore = require "PZONNX/Models/ModelStore"
local ModelPackage = require "PZONNX/Models/ModelPackage"
local UserFile = require "PZONNX/IO/UserFile"

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(message .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
end

local registry = ModelStore.refreshFromText("llama/model.onnx\n", function(path)
    return path == "llama/model.onnx"
end)
local entry = registry.entries[1]
local package = ModelPackage.new(entry)
assertEqual(package.modelPath, "llama/model.onnx", "package model path was not preserved")
assertEqual(package.modelRoot, "llama", "package root was not derived from the model path")
assertEqual(package.fullModelPath, "Models/llama/model.onnx",
    "package model path escaped the user root")

local existsCalls = {}
local originalExists = UserFile.exists
UserFile.exists = function(path)
    table.insert(existsCalls, path)
    return path == "llama/config.json" or path == "llama/tokenizer.json"
end

if #existsCalls ~= 0 then
    error("constructing a model package eagerly inspected companion files")
end
local config = package:getCompanion("config.json")
if not config.present or config.status ~= "PRESENT" then
    error("present companion was not reported")
end
local missing = package:getCompanion("vocab.json")
if missing.present or missing.status ~= "MISSING" then
    error("missing companion was not reported")
end
assertEqual(existsCalls[1], "llama/config.json", "companion path was not package-relative")
assertEqual(existsCalls[2], "llama/vocab.json", "companion probe order was not deterministic")

local companions = package:listCompanions()
assertEqual(#companions, #ModelPackage.COMPANION_NAMES,
    "companion probing enumerated outside the fixed known-name list")
assertEqual(existsCalls[3], "llama/config.json", "known companion list started with an unexpected name")

local external = package:resolveExternalData("weights/model.onnx_data")
if external == nil then
    error("safe external-data location was rejected")
end
assertEqual(external.path, "llama/weights/model.onnx_data",
    "external data was not resolved relative to the package")
assertEqual(external.fullPath, "Models/llama/weights/model.onnx_data",
    "external data escaped the user model root")

local unsafeExternal = package:resolveExternalData("../outside.bin")
if unsafeExternal ~= nil then
    error("external-data traversal was accepted")
end
local absoluteExternal = package:resolveExternalData("C:/outside.bin")
if absoluteExternal ~= nil then
    error("external-data drive path was accepted")
end

local ok = pcall(function() package:getCompanion("arbitrary.txt") end)
if ok then
    error("arbitrary companion names bypassed the fixed package contract")
end

UserFile.exists = originalExists
local notRegistered, reason = ModelPackage.forEntry("missing/model.onnx")
if notRegistered ~= nil or reason == nil then
    error("non-registered model entry became a package")
end

print("PZONNX P9B model package tests passed")
