package.path = "Contents/mods/PZONNX/42.20/media/lua/shared/?.lua;" .. package.path

local Json = require "PZONNX/IO/Json"
local Tokenizer = require "PZONNX/Models/Tokenizer"

local file = assert(io.open("tests/fixtures/p11_bpe_tokenizer.json", "rb"))
local tokenizerText = file:read("*all")
file:close()
local modelPackage = {}
function modelPackage:readCompanionText(name, limit)
    if name ~= "tokenizer.json" or limit < #tokenizerText then
        error("tokenizer fixture was requested through an unexpected path/limit")
    end
    return tokenizerText
end

local tokenizer = Tokenizer.fromPackage(modelPackage)
local hello = tokenizer:encode("hello")
if #hello ~= 2 or hello[1] ~= 1 or hello[2] ~= 15 then
    error("P11 BPE encode did not match the trusted tokenizer vector for hello")
end
local helloWorld = tokenizer:encode("hello world")
if #helloWorld ~= 3 or helloWorld[1] ~= 1 or helloWorld[2] ~= 15 or helloWorld[3] ~= 20 then
    error("P11 BPE encode did not match the trusted tokenizer vector for hello world")
end
local withoutBos = tokenizer:encode("hello world", { addBos = false })
if #withoutBos ~= 2 or withoutBos[1] ~= 15 or withoutBos[2] ~= 20 then
    error("P11 profile-driven BOS override was not honored")
end
local withEos = tokenizer:encode("hello", { addEos = true })
if withEos[3] ~= 2 then
    error("P11 EOS rule did not append the configured special token")
end
if tokenizer:decode(helloWorld) ~= "hello world" then
    error("P11 decode did not skip special BOS and restore normalized spacing")
end
if tokenizer:decode(helloWorld, { skipSpecialTokens = false }) ~= "<s> hello world" then
    error("P11 decode did not preserve special tokens when requested")
end

local document, reason = Json.decode("{invalid")
if document ~= nil or reason == nil then
    error("P11 JSON boundary did not reject malformed tokenizer metadata")
end
local unsupported = Json.decode(tokenizerText)
unsupported.model.type = "WordPiece"
local ok = pcall(function() Tokenizer.fromDocument(unsupported) end)
if ok then
    error("P11 accepted an unsupported tokenizer model family")
end

print("PZONNX P11 tokenizer tests passed")
