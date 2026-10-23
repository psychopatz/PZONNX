require "ISUI/ISRichTextPanel"
require "PsychopatzCore/UI/PsychopatzUI"
require "PsychopatzCore/UI/PsychopatzCommandHub"
require "PsychopatzCore/UI/PsychopatzDebugHubWindow"
require "PsychopatzCore/Input/PsychopatzKeybinds"

local Core = PsychopatzCore
local UI = Core.UI
local Layout = UI.Layout
local Theme = UI.Theme
local Translation = Core.Translation
local PZONNX = require "PZONNX/PZONNX"

local function tr(key, fallback)
    return Translation and Translation.GetKey
        and Translation.GetKey(key, fallback)
        or fallback or key
end

local function setPanelText(panel, value)
    panel.text = tostring(value or "")
    panel:paginate()
    if panel.scrollToBottom then panel:scrollToBottom() end
end

local function parseLimit(text)
    local value = tonumber(text)
    if value == nil or value < 0 or value ~= math.floor(value) then
        return nil, "max tokens must be a non-negative integer"
    end
    return value
end

PZONNXGenerationWindow = UI.Window:derive("PZONNXGenerationWindow")
PZONNXGenerationWindow.instance = nil
PZONNXGenerationWindow.FRAME_BUDGET = 1

function PZONNXGenerationWindow:initialise()
    UI.Window.initialise(self)
end

function PZONNXGenerationWindow:createChildren()
    UI.Window.createChildren(self)

    self.transcript = ISRichTextPanel:new(0, 0, 1, 1)
    self.transcript:initialise()
    self.transcript:instantiate()
    self.transcript.backgroundColor = Theme.Color("surface")
    self.transcript.borderColor = Theme.Color("border")
    self.transcript.autosetheight = false
    self.transcript.clip = true
    self.transcript.marginLeft = Layout.Pixels(8, self.uiScale)
    self.transcript.marginTop = Layout.Pixels(8, self.uiScale)
    self.transcript.marginBottom = Layout.Pixels(8, self.uiScale)
    self.transcript:addScrollBars()
    self:addChild(self.transcript)

    self.modelEntry = UI.CreateTextEntry(self, { text = "", maxTextLength = 240 })
    self.promptEntry = UI.CreateTextEntry(self, {
        text = "Hello. Introduce yourself briefly.", maxTextLength = 4096,
    })
    self.maxTokensEntry = UI.CreateTextEntry(self, {
        text = "16", maxTextLength = 8, onlyNumbers = true,
    })
    self.refreshButton = UI.CreateButton(self, {
        id = "refresh-models", title = tr("UI_PZONNX_Generation_Refresh", "Refresh models"),
        target = self, onclick = PZONNXGenerationWindow.onRefresh, variant = "quiet",
    })
    self.loadButton = UI.CreateButton(self, {
        id = "load-generation-model", title = tr("UI_PZONNX_Generation_Load", "Load model"),
        target = self, onclick = PZONNXGenerationWindow.onLoadModel, variant = "quiet",
    })
    self.sendButton = UI.CreateButton(self, {
        id = "generate-text", title = tr("UI_PZONNX_Generation_Send", "Generate"),
        target = self, onclick = PZONNXGenerationWindow.onSend, variant = "primary",
    })
    self.cancelButton = UI.CreateButton(self, {
        id = "cancel-generation", title = tr("UI_PZONNX_Generation_Cancel", "Cancel"),
        target = self, onclick = PZONNXGenerationWindow.onCancel, variant = "quiet",
    })
    self.clearButton = UI.CreateButton(self, {
        id = "clear-generation", title = tr("UI_PZONNX_Generation_Clear", "Clear"),
        target = self, onclick = PZONNXGenerationWindow.onClear, variant = "quiet",
    })

    self.generator = nil
    self.status = tr("UI_PZONNX_Generation_Ready",
        "No user model loaded. Refresh the ledger, select a registered model entry, then load it.")
    self:appendTranscript(tr("UI_PZONNX_Generation_Instructions",
        "PZONNX generative chat\n\nThis window uses only ledger-registered user model packages under Zomboid/Lua/Models/. The prompt is tokenized, run through resumable prefill/KV decode, sampled, and decoded back to text. Unsupported model contracts fail explicitly.\n\nThe older Tiny-LLM numeric forward-pass probe remains available separately."))
    self:requestResponsiveLayout(true)
end

function PZONNXGenerationWindow:appendTranscript(value)
    local current = self.transcript and self.transcript.text or ""
    if current ~= "" then current = current .. "\n\n" end
    current = current .. tostring(value or "")
    if #current > 60000 then current = string.sub(current, -60000) end
    if self.transcript then setPanelText(self.transcript, current) end
end

function PZONNXGenerationWindow:setStatus(value)
    self.status = tostring(value or "")
end

function PZONNXGenerationWindow:onRefresh()
    if self.generator and self.generator:isBusy() then
        self:setStatus("Cancel the active generation before refreshing models.")
        return
    end
    local ok, state = pcall(PZONNX.refreshModels)
    if not ok then
        self:setStatus("Ledger refresh failed explicitly: " .. tostring(state))
        return
    end
    local lines = {
        "system: ledger=" .. tostring(state.ledgerPath) ..
            " status=" .. tostring(state.ledgerStatus),
        "registered=" .. tostring(state.registeredCount) ..
            " missing=" .. tostring(state.missingCount) ..
            " invalid=" .. tostring(state.invalidCount),
    }
    for _, entry in ipairs(state.entries or {}) do
        table.insert(lines, tostring(entry.status) .. " " .. tostring(entry.path or entry.raw) ..
            (entry.reason and (" (" .. tostring(entry.reason) .. ")") or ""))
    end
    self:appendTranscript(table.concat(lines, "\n"))
    self:setStatus("Ledger refreshed: " .. tostring(state.registeredCount) .. " registered model(s).")
end

function PZONNXGenerationWindow:onLoadModel()
    if self.generator and self.generator:isBusy() then
        self:setStatus("Cancel the active generation before loading another model.")
        return
    end
    local path = self.modelEntry:getText()
    if path == nil or path == "" then
        self:setStatus("Enter a registered ledger model path, then load it.")
        return
    end
    self:setStatus("Loading and inspecting user package " .. tostring(path) .. "...")
    local ok, generatorOrError = pcall(PZONNX.newGeneratorForEntry, path, {
        maxNewTokens = 16,
        budget = PZONNXGenerationWindow.FRAME_BUDGET,
    })
    if not ok then
        self.generator = nil
        self:setStatus("Model rejected explicitly: " .. tostring(generatorOrError))
        self:appendTranscript("system: model load failed\n" .. tostring(generatorOrError))
        return
    end
    self.generator = generatorOrError
    self:setStatus("Loaded registered model package " .. tostring(path) .. ".")
    self:appendTranscript("system: loaded " .. tostring(path) ..
        "; prompt text is now connected to generic generation.")
end

function PZONNXGenerationWindow:onSend()
    if self.generator == nil then
        self:setStatus("Load a registered user model before generating.")
        return
    end
    if self.generator:isBusy() then
        self:setStatus("Generation is already running; use Cancel to stop it.")
        return
    end
    local maxTokens, limitError = parseLimit(self.maxTokensEntry:getText())
    if maxTokens == nil then
        self:setStatus("Input rejected: " .. tostring(limitError))
        return
    end
    local prompt = self.promptEntry:getText()
    if prompt == nil or prompt == "" then
        self:setStatus("Enter a prompt before generating.")
        return
    end
    local ok, result = pcall(self.generator.begin, self.generator, prompt, {
        maxNewTokens = maxTokens,
    })
    if not ok then
        self:setStatus("Prompt rejected explicitly: " .. tostring(result))
        return
    end
    self:appendTranscript("user: " .. tostring(prompt) .. "\nmax tokens: " .. tostring(maxTokens))
    self:setStatus("Prefill started; generation is stepping cooperatively.")
    if result.done then self:finishGeneration(result) end
end

function PZONNXGenerationWindow:finishGeneration(result)
    self:appendTranscript("assistant: " .. tostring(result.generatedText or "") ..
        "\nstop: " .. tostring(result.stopReason or "completed") ..
        "\nwork: " .. tostring(result.work or 0))
    self:setStatus("Generation finished: " .. tostring(result.stopReason or "completed") .. ".")
end

function PZONNXGenerationWindow:stepGeneration()
    if self.generator == nil or not self.generator:isBusy() then return end
    local ok, result = pcall(self.generator.step, self.generator,
        PZONNXGenerationWindow.FRAME_BUDGET)
    if not ok then
        self:setStatus("Generation failed explicitly: " .. tostring(result))
        self:appendTranscript("system: generation failed\n" .. tostring(result))
        return
    end
    self:setStatus("Generating: " .. tostring(result.phase) ..
        " work=" .. tostring(result.work or 0) ..
        " tokens=" .. tostring(#(result.generatedTokens or {})))
    if result.done then self:finishGeneration(result) end
end

function PZONNXGenerationWindow:onCancel()
    if self.generator == nil or not self.generator:isBusy() then
        self:setStatus("No generation is running.")
        return
    end
    self.generator:cancel()
    self:setStatus("Generation cancelled; resumable decoder state was released.")
    self:appendTranscript("system: generation cancelled")
end

function PZONNXGenerationWindow:onClear()
    setPanelText(self.transcript, "")
    self:setStatus("Transcript cleared.")
end

function PZONNXGenerationWindow:onResponsiveLayout()
    if not self.transcript then return end
    local rect = self:getContentRect({ top = 142, bottom = 10 })
    local scale = self.uiScale or Layout.Scale()
    local gap = Layout.Pixels(6, scale)
    local rowHeight = Layout.Pixels(30, scale)
    local labelWidth = Layout.Pixels(86, scale)
    local actionWidth = Layout.Pixels(112, scale)
    local inputX = rect.x + labelWidth
    local inputWidth = rect.width - labelWidth - actionWidth * 2 - gap * 2
    local rowY = rect.y

    Layout.SetBounds(self.modelEntry, inputX, rowY, inputWidth, rowHeight)
    Layout.SetBounds(self.refreshButton, inputX + inputWidth + gap, rowY, actionWidth, rowHeight)
    Layout.SetBounds(self.loadButton, inputX + inputWidth + gap + actionWidth + gap,
        rowY, actionWidth, rowHeight)
    rowY = rowY + rowHeight + gap
    Layout.SetBounds(self.promptEntry, inputX, rowY,
        rect.width - labelWidth - actionWidth - gap, rowHeight)
    Layout.SetBounds(self.sendButton, inputX + rect.width - labelWidth - actionWidth,
        rowY, actionWidth, rowHeight)
    rowY = rowY + rowHeight + gap
    Layout.SetBounds(self.maxTokensEntry, inputX, rowY, actionWidth, rowHeight)
    local transcriptY = rowY + rowHeight + Layout.Pixels(28, scale)
    local footerY = rect.y + rect.height - rowHeight
    Layout.SetBounds(self.transcript, rect.x, transcriptY, rect.width,
        math.max(rowHeight, footerY - transcriptY - gap))
    local footerGap = Layout.Pixels(6, scale)
    local footerButtonWidth = math.floor((rect.width - footerGap) / 2)
    Layout.SetBounds(self.cancelButton, rect.x, footerY, footerButtonWidth, rowHeight)
    Layout.SetBounds(self.clearButton, rect.x + footerButtonWidth + footerGap,
        footerY, footerButtonWidth, rowHeight)
    self.layoutRect = rect
end

function PZONNXGenerationWindow:render()
    UI.Window.render(self)
    if not self.layoutRect then return end
    local color = Theme.colors.textMuted
    local textColor = Theme.colors.text
    local rect = self.layoutRect
    local scale = self.uiScale or Layout.Scale()
    local rowHeight = Layout.Pixels(30, scale)
    local gap = Layout.Pixels(6, scale)
    local labelX = rect.x
    local labels = {
        { "Model entry", rect.y },
        { "Prompt", rect.y + rowHeight + gap },
        { "Max tokens", rect.y + (rowHeight + gap) * 2 },
    }
    for _, label in ipairs(labels) do
        self:drawText(label[1], labelX, label[2] + 8,
            textColor.r, textColor.g, textColor.b, textColor.a, UIFont.Small)
    end
    local statusY = rect.y + (rowHeight + gap) * 3 + 4
    self:drawText(Layout.Ellipsize(self.status or "", UIFont.Small, rect.width),
        rect.x, statusY, color.r, color.g, color.b, color.a, UIFont.Small)
end

function PZONNXGenerationWindow:new(x, y, width, height, options)
    local object = UI.Window.new(self, x, y, width, height, options)
    setmetatable(object, self)
    self.__index = self
    return object
end

function PZONNXGenerationWindow.Open()
    local window = PZONNXGenerationWindow.instance
    if window then
        window:setVisible(true)
        window:bringToTop()
        return window
    end
    window = UI.NewWindow(PZONNXGenerationWindow, {
        title = tr("UI_PZONNX_Generation_Title", "PZONNX Generative Chat"),
        resizable = true,
        persistenceNamespace = "PZONNX",
        persistenceKey = "GenerationChat",
        responsiveSpec = {
            width = 820, height = 650,
            minWidth = 620, minHeight = 470,
            maxWidth = 1300, maxHeight = 950,
        },
    })
    window:initialise()
    window:instantiate()
    window:addToUIManager()
    window:bringToTop()
    PZONNXGenerationWindow.instance = window
    return window
end

function PZONNXGenerationWindow.Toggle()
    local window = PZONNXGenerationWindow.instance
    if window and window:getIsVisible() then
        window:setVisible(false)
        return false
    end
    PZONNXGenerationWindow.Open()
    return true
end

local CommandHub = Core.CommandHub
if CommandHub and CommandHub.RegisterAction then
    CommandHub.RegisterAction("PZONNX", {
        id = "PZONNX.GenerativeChat",
        source = "PZONNX",
        order = 20,
        titleKey = "UI_PZONNX_Generation_Open",
        titleFallback = "Open generative chat",
        tooltipKey = "UI_PZONNX_Generation_OpenTooltip",
        tooltipFallback = "Open the ledger-backed PZONNX text generation window.",
        closePanel = true,
        onClick = function()
            PZONNXGenerationWindow.Open()
            return true
        end,
    })
end

local DebugHub = Core.DebugHub
if DebugHub and DebugHub.RegisterTool then
    DebugHub.RegisterTool({
        id = "pzonxx.generativeChat",
        source = "PZONNX",
        order = 20,
        title = tr("UI_PZONNX_Generation_DebugTitle", "PZONNX Generative Chat"),
        description = tr("UI_PZONNX_Generation_DebugDescription",
            "Open the ledger-backed PZONNX text generation window."),
        available = function() return true end,
        action = function() return PZONNXGenerationWindow.Open() end,
    })
end

Core.Keybinds.RegisterPress({
    id = "PZONNX.GenerativeChat.Toggle",
    defaultKey = "F9",
    label = tr("UI_PZONNX_Generation_Keybind", "Toggle PZONNX generative chat"),
    tooltip = tr("UI_PZONNX_Generation_KeybindTooltip",
        "Open or close PZONNX ledger-backed generative chat."),
    onTrigger = PZONNXGenerationWindow.Toggle,
})

if Events and Events.OnTick and not PZONNXGenerationWindow._tickHookRegistered then
    Events.OnTick.Add(function()
        local window = PZONNXGenerationWindow.instance
        if window and window:getIsVisible() then window:stepGeneration() end
    end)
    PZONNXGenerationWindow._tickHookRegistered = true
end

PZONNXGenerationUI = {
    Open = PZONNXGenerationWindow.Open,
    Toggle = PZONNXGenerationWindow.Toggle,
    Window = PZONNXGenerationWindow,
}

if PZONNX.Log and PZONNX.Log.info then
    PZONNX.Log.info("generation_ui=registered core_backed=true ledger_backed=true")
end

return PZONNXGenerationUI
