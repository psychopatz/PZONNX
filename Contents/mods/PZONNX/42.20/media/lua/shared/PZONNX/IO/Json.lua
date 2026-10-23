local Json = {}

local function utf8Codepoint(codepoint)
    if codepoint < 128 then return string.char(codepoint) end
    if codepoint < 2048 then
        return string.char(192 + math.floor(codepoint / 64), 128 + codepoint % 64)
    end
    if codepoint < 65536 then
        return string.char(224 + math.floor(codepoint / 4096),
            128 + math.floor(codepoint / 64) % 64, 128 + codepoint % 64)
    end
    return string.char(240 + math.floor(codepoint / 262144),
        128 + math.floor(codepoint / 4096) % 64,
        128 + math.floor(codepoint / 64) % 64, 128 + codepoint % 64)
end

local function decoder(text)
    local state = { text = text, index = 1 }

    local function fail(message)
        error("PZONNX JSON error at byte " .. tostring(state.index) .. ": " .. message)
    end

    local function skipWhitespace()
        while state.index <= #state.text and
            string.find(" \t\r\n", string.sub(state.text, state.index, state.index), 1, true) ~= nil do
            state.index = state.index + 1
        end
    end

    local parseValue
    local function parseString()
        if string.sub(state.text, state.index, state.index) ~= '"' then fail("expected string") end
        state.index = state.index + 1
        local result = {}
        while state.index <= #state.text do
            local character = string.sub(state.text, state.index, state.index)
            state.index = state.index + 1
            if character == '"' then return table.concat(result) end
            if character ~= "\\" then
                table.insert(result, character)
            else
                if state.index > #state.text then fail("unterminated escape") end
                local escaped = string.sub(state.text, state.index, state.index)
                state.index = state.index + 1
                local replacements = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/",
                    b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
                if replacements[escaped] ~= nil then
                    table.insert(result, replacements[escaped])
                elseif escaped == "u" then
                    local digits = string.sub(state.text, state.index, state.index + 3)
                    if #digits ~= 4 or not string.match(digits, "^[%x]+$") then
                        fail("invalid unicode escape")
                    end
                    state.index = state.index + 4
                    table.insert(result, utf8Codepoint(tonumber(digits, 16)))
                else
                    fail("unsupported string escape")
                end
            end
        end
        fail("unterminated string")
    end

    local function parseNumber()
        local start = state.index
        local token = string.match(string.sub(state.text, start),
            "^[%-]?%d+%.?%d*[eE]?[+%-]?%d*")
        if token == nil or token == "" then fail("invalid number") end
        state.index = start + #token
        local number = tonumber(token)
        if number == nil then fail("invalid number") end
        return number
    end

    local function parseArray()
        state.index = state.index + 1
        skipWhitespace()
        local result = {}
        if string.sub(state.text, state.index, state.index) == "]" then
            state.index = state.index + 1
            return result
        end
        while true do
            table.insert(result, parseValue())
            skipWhitespace()
            local separator = string.sub(state.text, state.index, state.index)
            if separator == "]" then
                state.index = state.index + 1
                return result
            end
            if separator ~= "," then fail("expected array separator") end
            state.index = state.index + 1
            skipWhitespace()
        end
    end

    local function parseObject()
        state.index = state.index + 1
        skipWhitespace()
        local result = {}
        if string.sub(state.text, state.index, state.index) == "}" then
            state.index = state.index + 1
            return result
        end
        while true do
            local key = parseString()
            skipWhitespace()
            if string.sub(state.text, state.index, state.index) ~= ":" then fail("expected object colon") end
            state.index = state.index + 1
            result[key] = parseValue()
            skipWhitespace()
            local separator = string.sub(state.text, state.index, state.index)
            if separator == "}" then
                state.index = state.index + 1
                return result
            end
            if separator ~= "," then fail("expected object separator") end
            state.index = state.index + 1
            skipWhitespace()
        end
    end

    function parseValue()
        skipWhitespace()
        local character = string.sub(state.text, state.index, state.index)
        if character == '"' then return parseString() end
        if character == "{" then return parseObject() end
        if character == "[" then return parseArray() end
        if string.sub(state.text, state.index, state.index + 3) == "true" then
            state.index = state.index + 4
            return true
        end
        if string.sub(state.text, state.index, state.index + 4) == "false" then
            state.index = state.index + 5
            return false
        end
        if string.sub(state.text, state.index, state.index + 3) == "null" then
            state.index = state.index + 4
            return nil
        end
        return parseNumber()
    end

    local result = parseValue()
    skipWhitespace()
    if state.index <= #state.text then fail("trailing JSON data") end
    return result
end

function Json.decode(text)
    assert(type(text) == "string", "PZONNX JSON decoder requires text")
    local ok, result = pcall(decoder, text)
    if not ok then return nil, tostring(result) end
    return result
end

return Json
