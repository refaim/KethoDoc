---@type table
local _G = getfenv(0)

KethoWindow = {}

local FRAME_NAME = 'KethoWindowFrame'

---@class Action
---@field [1] string
---@field [2] nil|fun():string

---@param name string
---@param onclick function|nil
---@param parent Frame
---@return Button
local function createButton(name, onclick, parent)
    local button = CreateFrame('Button',
        'KethoWindow' .. string.gsub(name, '[_%s]+', '') .. 'Button',
        parent,
        'GameMenuButtonTemplate')
    button:SetText(name)
    button:SetWidth(button:GetTextWidth() + 16 * 2)
    if onclick == nil then
        button:Disable()
    else
        button:SetScript('OnClick', function()
            local oldText = button:GetText()
            button:SetText('Loading...')
            button:Disable()
            onclick()
            button:Enable()
            button:SetText(oldText)
        end)
    end
    return button
end

---@return Frame
function KethoWindow:__CreateFrame()
    local frame = CreateFrame('Frame', FRAME_NAME, UIParent)

    frame:SetPoint('CENTER', UIParent)
    frame:SetBackdrop({
        bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
        edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border',
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetScript('OnMouseDown', function()
        if arg1 == 'LeftButton' then
            this:StartMoving()
        end
    end)
    frame:SetScript('OnMouseUp', function()
        if arg1 == 'LeftButton' then
            this:StopMovingOrSizing()
        end
    end)

    return frame
end

---@param frame Frame
---@return ScrollFrame, EditBox
function KethoWindow:__CreateTextControls(frame)
    local scrollFrame = CreateFrame('ScrollFrame', 'KethoWindowScrollFrame', frame, 'UIPanelScrollFrameTemplate')

    local editBox = CreateFrame('EditBox', 'KethoWindowEditBox', scrollFrame)
    scrollFrame:SetScrollChild(editBox)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject('ChatFontNormal')
    editBox:SetScript('OnEscapePressed', function () editBox:ClearFocus() end)

    return scrollFrame, editBox
end

---@param frame Frame
---@param actions Action[]
---@param onclick fun(callback:function):function
---@return Button[]
function KethoWindow:__CreateActionButtons(frame, actions, onclick)
    ---@type Button[]
    local buttons = {}
    local maxActionButtonWidth = 0
    for _, action in ipairs(actions) do
        local name = action[1]
        local callback = action[2]
        local handle
        if type(callback) == 'function' then
            handle = onclick(--[[---@type function]] callback)
        end
        local button = createButton(name, handle, frame)
        maxActionButtonWidth = max(maxActionButtonWidth, button:GetWidth())
        tinsert(buttons, button)
    end
    for _, button in ipairs(buttons) do
        button:SetWidth(maxActionButtonWidth)
    end
    return buttons
end

---@param frame Frame
---@param scrollFrame ScrollFrame
---@param editBox EditBox
---@param actionButtons Button[]
function KethoWindow:__SetupLayout(frame, scrollFrame, editBox, actionButtons)
    ---@type Region|nil
    local anchor
    ---@type WidgetAnchorPoint|nil
    local anchorPoint

    local vertButtonInterval = 1
    for _, button in ipairs(actionButtons) do
        button:SetPoint('LEFT', frame, 'LEFT', 16, 0)
        if anchor ~= nil then
            button:SetPoint('TOP', anchor, anchorPoint, 0, -vertButtonInterval)
        end
        anchor = button
        anchorPoint = 'BOTTOM'
    end

    local topButton = actionButtons[1]
    local actionButtonVerticalPadding = 32
    topButton:SetPoint('TOP', frame, 'TOP', 0, -actionButtonVerticalPadding)
    frame:SetWidth(500)
    frame:SetHeight(2 * actionButtonVerticalPadding + getn(actionButtons) * topButton:GetHeight() + (getn(actionButtons) - 1) * vertButtonInterval)

    local bottomButton = actionButtons[getn(actionButtons)]
    scrollFrame:SetPoint('TOPLEFT', topButton, 'TOPRIGHT', 8, 0)
    scrollFrame:SetPoint('RIGHT', frame, 'RIGHT', -40, 0)
    scrollFrame:SetPoint('BOTTOM', bottomButton, 'BOTTOM', 0, 8)

    editBox:SetPoint('TOPLEFT', scrollFrame, 'TOPLEFT')
    editBox:SetPoint('BOTTOMRIGHT', scrollFrame, 'BOTTOMRIGHT')
end

---@param actions Action[]
function KethoWindow:Create(actions)
    if _G[FRAME_NAME] == nil then
        local frame = self:__CreateFrame()
        local scrollFrame, editBox = self:__CreateTextControls(frame)
        local actionButtons = self:__CreateActionButtons(frame, actions, function(callback)
            return function()
                local data = callback()
                local text
                if type(data) == 'string' then
                    text = data
                elseif type(data) == 'table' then
                    ---@type string[]
                    local strings = {}
                    if data[1] ~= nil then
                        strings = data
                    else
                        for k, v in pairs(data) do
                            tinsert(strings, k .. '=' .. v)
                        end
                    end
                    sort(strings)
                    text = table.concat(strings, '\n')
                end
                editBox:SetText(text)
            end
        end)
        self:__SetupLayout(frame, scrollFrame, editBox, actionButtons)
        self.frame = frame
    end
end

function KethoWindow:Show()
    self.frame:Show()
end
