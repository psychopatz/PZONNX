require "ISUI/ISRichTextPanel"
require "PsychopatzCore/UI/PsychopatzUI"
require "PsychopatzCore/UI/PsychopatzCommandHub"
require "PsychopatzCore/Input/PsychopatzKeybinds"

local Core = PsychopatzCore
local UI = Core.UI
local Layout = UI.Layout
local Theme = UI.Theme
local Translation = Core.Translation
local PZONNX = require "PZONNX/PZONNX"
local Chat = require "PZONNX/Adapters/Chat"

local function tr(key, fallback)
    return Translation and Translation.GetKey
        and Translation.GetKey(key, fallback)
        or fallback or key
end

local function parseTokenIDs(text)
    local result = {}
    for value in string.gmatch(tostring(text or ""), "[^,%s]+") do
        local token = tonumber(value)
        if token == nil or token ~= math.floor(token) then
            return nil, "token IDs must be comma-separated integers"
        end
        result[#result + 1] = token
    end
    if #result == 0 then return nil, "enter at least one token ID" end
    return result
end

local function setPanelText(panel, value)
    panel.text = tostring(value or "")
    panel:paginate()
    if panel.scrollToBottom then panel:scrollToBottom() end
end

PZONNXChatWindow = UI.Window:derive("PZONNXChatWindow")
PZONNXChatWindow.instance = nil
PZONNXChatWindow.MODEL_PATH = "media/pzonnx/models/tiny_llm/model_int8.onnx"

function PZONNXChatWindow:initialise()
    UI.Window.initialise(self)
end

function PZONNXChatWindow:createChildren()
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

    self.modelEntry = UI.CreateTextEntry(self, {
        text = PZONNXChatWindow.MODEL_PATH,
        maxTextLength = 240,
    })
    self.tokenEntry = UI.CreateTextEntry(self, {
        text = "1",
        maxTextLength = 240,
    })
    self.promptEntry = UI.CreateTextEntry(self, {
        text = "token probe",
        maxTextLength = 240,
    })
    self.loadButton = UI.CreateButton(self, {
        id = "load-model",
        title = tr("UI_PZONNX_Chat_Load", "Load model"),
        target = self,
        onclick = PZONNXChatWindow.onLoadModel,
        variant = "quiet",
    })
    self.sendButton = UI.CreateButton(self, {
        id = "send-token-probe",
        title = tr("UI_PZONNX_Chat_Run", "Run inference"),
        target = self,
        onclick = PZONNXChatWindow.onSend,
        variant = "primary",
    })
    self.clearButton = UI.CreateButton(self, {
        id = "clear-transcript",
        title = tr("UI_PZONNX_Chat_Clear", "Clear"),
        target = self,
        onclick = PZONNXChatWindow.onClear,
        variant = "quiet",
    })

    self.model = nil
    self.session = nil
    self.activeJob = nil
    self.pendingPrompt = nil
    self.inferenceWork = 0
    self.status = tr("UI_PZONNX_Chat_NotLoaded",
        "Model not loaded. Copy the ONNX file into the configured path, then load it.")
    self:appendTranscript(tr("UI_PZONNX_Chat_Instructions",
        "PZONNX chat probe\n\nThis is an inference harness, not a tokenizer. Enter numeric token IDs separated by commas. The linked Tiny-LLM model returns the next token ID; text is shown only as a chat label.\n\nDefault model path: media/pzonnx/models/tiny_llm/model_int8.onnx"))
    self:requestResponsiveLayout(true)
end

function PZONNXChatWindow:appendTranscript(value)
    local current = self.transcript and self.transcript.text or ""
    if current ~= "" then current = current .. "\n\n" end
    current = current .. tostring(value or "")
    if #current > 60000 then current = string.sub(current, -60000) end
    if self.transcript then setPanelText(self.transcript, current) end
end

function PZONNXChatWindow:setStatus(value)
    self.status = tostring(value or "")
end

function PZONNXChatWindow:onLoadModel()
    if self.activeJob then
        self:setStatus("Wait for the active inference job to finish before loading another model.")
        return
    end
    local path = self.modelEntry:getText()
    self:setStatus("Loading " .. tostring(path) .. "...")
    local ok, modelOrError = pcall(PZONNX.loadModel, path)
    if not ok then
        self.model = nil
        self.session = nil
        self:setStatus("Load failed: " .. tostring(modelOrError))
        return
    end
    local model = modelOrError
    local unsupported = model.compatibility and model.compatibility.unsupported or {}
    if #unsupported > 0 then
        self.model = nil
        self.session = nil
        self:setStatus("Load rejected: unsupported ONNX behavior: " .. tostring(unsupported[1]))
        return
    end

    local sessionOK, sessionOrError = pcall(PZONNX.newSession, model)
    if not sessionOK then
        self.model = nil
        self.session = nil
        self:setStatus("Session creation failed: " .. tostring(sessionOrError))
        return
    end
    self.model = model
    self.session = sessionOrError
    self:setStatus(string.format("Loaded %s: %d nodes, %d inputs, %d outputs.",
        tostring(path), #model.graph.nodes, #model.graph.inputs,
        #model.graph.outputs))
    self:appendTranscript("system: " .. self.status)
end

function PZONNXChatWindow:onSend()
    if self.activeJob then
        self:setStatus("Inference is already running; the UI is keeping it cooperative.")
        return
    end
    if self.session == nil or self.model == nil then
        self:setStatus("Load a model before running inference.")
        return
    end
    local tokenIDs, tokenError = parseTokenIDs(self.tokenEntry:getText())
    if tokenIDs == nil then
        self:setStatus("Input rejected: " .. tostring(tokenError))
        return
    end
    local inputs, profileOrError = nil, nil
    local buildOK, buildResult, buildProfile = pcall(function()
        local builtInputs, profile = Chat.buildInputs(self.model, tokenIDs)
        return builtInputs, profile
    end)
    if not buildOK then
        self:setStatus("Input rejected: " .. tostring(buildResult))
        return
    end
    inputs, profileOrError = buildResult, buildProfile

    local jobOK, jobOrError = pcall(function()
        return self.session:newJob(inputs)
    end)
    if not jobOK then
        self:setStatus("Job creation failed: " .. tostring(jobOrError))
        return
    end
    self.activeJob = jobOrError
    self.pendingPrompt = self.promptEntry:getText()
    self.pendingProfile = profileOrError
    self.inferenceWork = 0
    self:appendTranscript("user: " .. tostring(self.pendingPrompt)
        .. "\ntokens: " .. tostring(self.tokenEntry:getText()))
    self:setStatus("Running " .. tostring(profileOrError.mode)
        .. " inference; nodes are stepped cooperatively.")
end

function PZONNXChatWindow:finishInference(result)
    local pendingPrompt = self.pendingPrompt or "token probe"
    local nextTokenOK, nextTokenOrError = pcall(Chat.nextToken,
        self.model, result.outputs)
    if not nextTokenOK then
        self:setStatus("Inference output rejected explicitly: " ..
            tostring(nextTokenOrError))
        self:appendTranscript("system: output rejected: " ..
            tostring(nextTokenOrError))
        self.activeJob = nil
        self.pendingPrompt = nil
        self.pendingProfile = nil
        self.inferenceWork = 0
        return
    end
    local nextToken = nextTokenOrError
    self:appendTranscript("assistant: next token ID = " .. tostring(nextToken.tokenId)
        .. "\nlogit = " .. tostring(nextToken.logit)
        .. "\noutput = " .. tostring(nextToken.outputName))
    self:setStatus("Completed " .. tostring(self.inferenceWork)
        .. " node steps for " .. tostring(pendingPrompt) .. ".")
    self.activeJob = nil
    self.pendingPrompt = nil
    self.pendingProfile = nil
    self.inferenceWork = 0
end

function PZONNXChatWindow:stepInference()
    if self.activeJob == nil then return end
    local ok, result = pcall(self.activeJob.step, self.activeJob, 4)
    if not ok then
        self:setStatus("Inference failed explicitly: " .. tostring(result))
        self:appendTranscript("system: inference failed: " .. tostring(result))
        self.activeJob = nil
        self.pendingPrompt = nil
        self.pendingProfile = nil
        self.inferenceWork = 0
        return
    end
    self.inferenceWork = self.inferenceWork + (result.work or 0)
    if result.done then self:finishInference(result) end
end

function PZONNXChatWindow:onClear()
    setPanelText(self.transcript, "")
    self:setStatus("Transcript cleared.")
end

function PZONNXChatWindow:onResponsiveLayout()
    if not self.transcript then return end
    local rect = self:getContentRect({ top = 112, bottom = 10 })
    local scale = self.uiScale or Layout.Scale()
    local gap = Layout.Pixels(6, scale)
    local rowHeight = Layout.Pixels(30, scale)
    local labelWidth = Layout.Pixels(86, scale)
    local actionWidth = Layout.Pixels(112, scale)
    local inputX = rect.x + labelWidth
    local inputWidth = rect.width - labelWidth - actionWidth - gap
    local rowY = rect.y

    Layout.SetBounds(self.modelEntry, inputX, rowY, inputWidth, rowHeight)
    Layout.SetBounds(self.loadButton, inputX + inputWidth + gap, rowY,
        actionWidth, rowHeight)
    rowY = rowY + rowHeight + gap
    Layout.SetBounds(self.tokenEntry, inputX, rowY, inputWidth, rowHeight)
    rowY = rowY + rowHeight + gap
    Layout.SetBounds(self.promptEntry, inputX, rowY, inputWidth, rowHeight)
    Layout.SetBounds(self.sendButton, inputX + inputWidth + gap, rowY,
        actionWidth, rowHeight)

    local transcriptY = rowY + rowHeight + Layout.Pixels(28, scale)
    local footerY = rect.y + rect.height - rowHeight
    Layout.SetBounds(self.transcript, rect.x, transcriptY, rect.width,
        math.max(rowHeight, footerY - transcriptY - gap))
    Layout.SetBounds(self.clearButton, rect.x, footerY, actionWidth, rowHeight)
    self.layoutRect = rect
    self.labelWidth = labelWidth
end

function PZONNXChatWindow:render()
    UI.Window.render(self)
    if not self.layoutRect then return end
    local color = Theme.colors.textMuted
    local textColor = Theme.colors.text
    local rect = self.layoutRect
    local scale = self.uiScale or Layout.Scale()
    local labelX = rect.x
    local rowHeight = Layout.Pixels(30, scale)
    local gap = Layout.Pixels(6, scale)
    local labels = {
        { "Model", rect.y },
        { "Token IDs", rect.y + rowHeight + gap },
        { "Prompt", rect.y + (rowHeight + gap) * 2 },
    }
    for _, label in ipairs(labels) do
        self:drawText(label[1], labelX, label[2] + 8,
            textColor.r, textColor.g, textColor.b, textColor.a, UIFont.Small)
    end
    local statusY = rect.y + (rowHeight + gap) * 3 + 4
    self:drawText(Layout.Ellipsize(self.status or "", UIFont.Small,
        rect.width), rect.x, statusY,
        color.r, color.g, color.b, color.a, UIFont.Small)
end

function PZONNXChatWindow:new(x, y, width, height, options)
    local object = UI.Window.new(self, x, y, width, height, options)
    setmetatable(object, self)
    self.__index = self
    return object
end

function PZONNXChatWindow.Open()
    local window = PZONNXChatWindow.instance
    if window then
        window:setVisible(true)
        window:bringToTop()
        return window
    end
    window = UI.NewWindow(PZONNXChatWindow, {
        title = tr("UI_PZONNX_Chat_Title", "PZONNX Tiny-LLM Chat Probe"),
        resizable = true,
        persistenceNamespace = "PZONNX",
        persistenceKey = "ChatProbe",
        responsiveSpec = {
            width = 760, height = 610,
            minWidth = 560, minHeight = 430,
            maxWidth = 1200, maxHeight = 900,
        },
    })
    window:initialise()
    window:instantiate()
    window:addToUIManager()
    window:bringToTop()
    PZONNXChatWindow.instance = window
    return window
end

function PZONNXChatWindow.Toggle()
    local window = PZONNXChatWindow.instance
    if window and window:getIsVisible() then
        window:setVisible(false)
        return false
    end
    PZONNXChatWindow.Open()
    return true
end

function PZONNXChatWindow:close()
    if self.activeJob and not self.activeJob:isDone() then
        self.activeJob:cancel()
    end
    self.activeJob = nil
    self:setVisible(false)
    self:removeFromUIManager()
    PZONNXChatWindow.instance = nil
end

local CommandHub = Core.CommandHub
CommandHub.RegisterButton({
    id = "PZONNX",
    source = "PZONNX",
    order = 250,
    titleKey = "UI_PZONNX_Chat_Category",
    titleFallback = "PZONNX",
    actions = {
        {
            id = "PZONNX.ChatProbe",
            source = "PZONNX",
            order = 10,
            titleKey = "UI_PZONNX_Chat_Open",
            titleFallback = "Open Tiny-LLM chat probe",
            tooltipKey = "UI_PZONNX_Chat_OpenTooltip",
            tooltipFallback = "Open the local PZONNX inference test window.",
            closePanel = true,
            onClick = function()
                PZONNXChatWindow.Open()
                return true
            end,
        },
    },
})

Core.Keybinds.RegisterPress({
    id = "PZONNX.ChatProbe.Toggle",
    defaultKey = "F8",
    label = tr("UI_PZONNX_Chat_Keybind", "Toggle PZONNX chat probe"),
    tooltip = tr("UI_PZONNX_Chat_KeybindTooltip",
        "Open or close the PZONNX Tiny-LLM test window."),
    onTrigger = PZONNXChatWindow.Toggle,
})

if Events and Events.OnTick and not PZONNXChatWindow._tickHookRegistered then
    Events.OnTick.Add(function()
        local window = PZONNXChatWindow.instance
        if window and window:getIsVisible() then window:stepInference() end
    end)
    PZONNXChatWindow._tickHookRegistered = true
end

PZONNXChatUI = {
    Open = PZONNXChatWindow.Open,
    Toggle = PZONNXChatWindow.Toggle,
    Window = PZONNXChatWindow,
}

return PZONNXChatUI
