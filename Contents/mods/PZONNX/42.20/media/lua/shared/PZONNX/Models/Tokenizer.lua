local Json = require "PZONNX/IO/Json"

local Tokenizer = {}
Tokenizer.__index = Tokenizer

local function utf8Symbols(text)
    local symbols = {}
    local index = 1
    while index <= #text do
        local byte = string.byte(text, index)
        local width = 1
        if byte >= 240 then width = 4
        elseif byte >= 224 then width = 3
        elseif byte >= 192 then width = 2
        elseif byte >= 128 then error("PZONNX tokenizer received invalid UTF-8") end
        if index + width - 1 > #text then error("PZONNX tokenizer received truncated UTF-8") end
        table.insert(symbols, string.sub(text, index, index + width - 1))
        index = index + width
    end
    return symbols
end

local function applyNormalizer(text, normalizer)
    if normalizer == nil then return text end
    local components = normalizer.type == "Sequence" and normalizer.normalizers or { normalizer }
    for _, component in ipairs(components or {}) do
        if component.type == "Prepend" then
            text = tostring(component.prepend or "") .. text
        elseif component.type == "Replace" and component.pattern ~= nil and component.pattern.String ~= nil then
            text = string.gsub(text, component.pattern.String, component.content or "")
        else
            error("PZONNX tokenizer normalizer is unsupported: " .. tostring(component.type))
        end
    end
    return text
end

local function mergeKey(left, right)
    return left .. "\0" .. right
end

local function parseMerge(merge)
    if type(merge) == "string" then
        local separator = string.find(merge, " ", 1, true)
        if separator == nil then error("PZONNX tokenizer merge is malformed") end
        return string.sub(merge, 1, separator - 1), string.sub(merge, separator + 1)
    end
    if type(merge) == "table" and #merge == 2 then
        return merge[1], merge[2]
    end
    error("PZONNX tokenizer merge format is unsupported")
end

local function parseDecoder(document)
    local decoder = document.decoder
    local result = { replace = {}, byteFallback = false, stripStart = 0, stripStop = 0 }
    if decoder == nil then return result end
    local components = decoder.type == "Sequence" and decoder.decoders or { decoder }
    for _, component in ipairs(components or {}) do
        if component.type == "Replace" and component.pattern ~= nil and component.pattern.String ~= nil then
            table.insert(result.replace, { from = component.pattern.String, to = component.content or "" })
        elseif component.type == "ByteFallback" then
            result.byteFallback = true
        elseif component.type == "Fuse" then
            -- Concatenation is the default decoder behavior.
        elseif component.type == "Strip" then
            result.stripStart = component.start or 0
            result.stripStop = component.stop or 0
        else
            error("PZONNX tokenizer decoder is unsupported: " .. tostring(component.type))
        end
    end
    return result
end

local function parsePostProcessor(document, tokenizer)
    local processor = document.post_processor
    if processor == nil then return end
    if processor.type ~= "TemplateProcessing" then
        error("PZONNX tokenizer post-processor is unsupported: " .. tostring(processor.type))
    end
    local first = processor.single ~= nil and processor.single[1] or nil
    if first ~= nil and first.SpecialToken ~= nil then
        tokenizer.addBos = true
        local special = first.SpecialToken
        tokenizer.bosTokenId = tokenizer.vocab[special.id]
    end
end

function Tokenizer.fromDocument(document, profile, profiler)
    assert(type(document) == "table" and type(document.model) == "table",
        "PZONNX tokenizer JSON is missing model")
    if document.model.type ~= "BPE" then
        error("PZONNX tokenizer model is unsupported: " .. tostring(document.model.type))
    end
    if document.pre_tokenizer ~= nil then
        error("PZONNX tokenizer pre-tokenizer is unsupported")
    end
    local vocab = document.model.vocab
    local merges = document.model.merges
    if type(vocab) ~= "table" or type(merges) ~= "table" then
        error("PZONNX BPE tokenizer requires vocab and merges")
    end

    local tokenizer = setmetatable({
        vocab = vocab,
        idToToken = {},
        merges = {},
        unkToken = document.model.unk_token,
        unkTokenId = nil,
        addBos = false,
        addEos = false,
        bosTokenId = nil,
        eosTokenId = nil,
        specialIds = {},
        normalizer = document.normalizer,
        decoder = parseDecoder(document),
        profiler = profiler,
    }, Tokenizer)
    for token, id in pairs(vocab) do
        tokenizer.idToToken[id] = token
        if token == tokenizer.unkToken then tokenizer.unkTokenId = id end
    end
    for rank, merge in ipairs(merges) do
        local left, right = parseMerge(merge)
        tokenizer.merges[mergeKey(left, right)] = rank
    end
    for _, token in ipairs(document.added_tokens or {}) do
        if token.id ~= nil and token.content ~= nil then
            tokenizer.idToToken[token.id] = token.content
            if token.special then tokenizer.specialIds[token.id] = true end
            if token.content == tokenizer.unkToken then tokenizer.unkTokenId = token.id end
            if token.content == "<s>" then tokenizer.bosTokenId = token.id end
            if token.content == "</s>" then tokenizer.eosTokenId = token.id end
        end
    end
    parsePostProcessor(document, tokenizer)
    if profile ~= nil then
        if profile.bosToken ~= nil then tokenizer.bosTokenId = profile.bosToken end
        if type(profile.eosTokens) == "table" then tokenizer.eosTokenId = profile.eosTokens[1] end
    end
    if tokenizer.unkTokenId == nil then error("PZONNX BPE tokenizer is missing unk_token") end
    return tokenizer
end

function Tokenizer.fromPackage(modelPackage, profile, profiler)
    assert(type(modelPackage) == "table" and type(modelPackage.readCompanionText) == "function",
        "PZONNX Tokenizer.load requires a ModelPackage")
    local text, reason = modelPackage:readCompanionText("tokenizer.json", 8388608)
    if text == nil then error("PZONNX tokenizer.json is unavailable: " .. tostring(reason)) end
    local document, parseReason = Json.decode(text)
    if document == nil then error("PZONNX tokenizer.json is invalid: " .. tostring(parseReason)) end
    return Tokenizer.fromDocument(document, profile, profiler)
end

local function mergeSymbols(tokenizer, symbols)
    while true do
        local bestRank = nil
        local bestIndex = nil
        for index = 1, #symbols - 1 do
            local rank = tokenizer.merges[mergeKey(symbols[index], symbols[index + 1])]
            if rank ~= nil and (bestRank == nil or rank < bestRank) then
                bestRank = rank
                bestIndex = index
            end
        end
        if bestIndex == nil then return symbols end
        local merged = {}
        local index = 1
        while index <= #symbols do
            if index == bestIndex then
                table.insert(merged, symbols[index] .. symbols[index + 1])
                index = index + 2
            else
                table.insert(merged, symbols[index])
                index = index + 1
            end
        end
        symbols = merged
    end
end

function Tokenizer:encode(text, options)
    assert(type(text) == "string", "PZONNX tokenizer encode requires text")
    options = options or {}
    local normalized = applyNormalizer(text, self.normalizer)
    local symbols = mergeSymbols(self, utf8Symbols(normalized))
    local ids = {}
    if (options.addBos == nil and self.addBos) or options.addBos then
        if self.bosTokenId == nil then error("PZONNX tokenizer has no BOS token") end
        table.insert(ids, self.bosTokenId)
    end
    for _, symbol in ipairs(symbols) do
        table.insert(ids, self.vocab[symbol] or self.unkTokenId)
    end
    if options.addEos then
        if self.eosTokenId == nil then error("PZONNX tokenizer has no EOS token") end
        table.insert(ids, self.eosTokenId)
    end
    if self.profiler ~= nil then
        self.profiler:record("tokenizer.encode", { work = #ids, characters = #text })
    end
    return ids
end

local function decodeByteFallback(token)
    local hex = string.match(token, "^<0x(%x%x)>$")
    if hex == nil then return nil end
    return string.char(tonumber(hex, 16))
end

function Tokenizer:decode(ids, options)
    assert(type(ids) == "table", "PZONNX tokenizer decode requires token IDs")
    options = options or {}
    local tokens = {}
    for _, id in ipairs(ids) do
        local token = self.idToToken[id]
        if token == nil then error("PZONNX tokenizer cannot decode token ID: " .. tostring(id)) end
        if not (options.skipSpecialTokens ~= false and self.specialIds[id]) then
            local byteToken = self.decoder.byteFallback and decodeByteFallback(token)
            table.insert(tokens, byteToken or token)
        end
    end
    local text = table.concat(tokens)
    for _, replacement in ipairs(self.decoder.replace) do
        text = string.gsub(text, replacement.from, replacement.to)
    end
    for _ = 1, self.decoder.stripStart do
        if string.sub(text, 1, 1) == " " then text = string.sub(text, 2) end
    end
    for _ = 1, self.decoder.stripStop do
        if string.sub(text, -1) == " " then text = string.sub(text, 1, -2) end
    end
    if self.profiler ~= nil then
        self.profiler:record("tokenizer.decode", { work = #ids, characters = #text })
    end
    return text
end

return Tokenizer
