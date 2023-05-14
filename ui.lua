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
local function create_button(name, onclick, parent)
    local button = CreateFrame('Button',
        format('KethoWindow%sButton', gsub(name, '[_%s]+', '')),
        parent,
        'GameMenuButtonTemplate')
    button:SetText(name)
    button:SetWidth(button:GetTextWidth() + 16 * 2)
    if onclick == nil then
        button:Disable()
    else
        button:SetScript('OnClick', function()
            local old_text = button:GetText()
            button:SetText('Loading...')
            button:Disable()
            onclick()
            button:Enable()
            button:SetText(old_text)
        end)
    end
    return button
end

---@return Frame
function KethoWindow:__create_frame()
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
function KethoWindow:__create_text_controls(frame)
    local scroll_frame = CreateFrame('ScrollFrame', 'KethoWindowScrollFrame', frame, 'UIPanelScrollFrameTemplate')

    local edit_box = CreateFrame('EditBox', 'KethoWindowEditBox', scroll_frame)
    scroll_frame:SetScrollChild(edit_box)
    edit_box:SetMultiLine(true)
    edit_box:SetAutoFocus(false)
    edit_box:SetFontObject('ChatFontNormal')
    edit_box:SetScript('OnEscapePressed', function () edit_box:ClearFocus() end)

    return scroll_frame, edit_box
end

---@param frame Frame
---@param actions Action[]
---@param onclick fun(callback:function):function
---@return Button[]
function KethoWindow:__create_action_buttons(frame, actions, onclick)
    ---@type Button[]
    local buttons = {}
    local max_action_button_width = 0
    for _, action in ipairs(actions) do
        local name = action[1]
        local callback = action[2]
        local handle
        if type(callback) == 'function' then
            handle = onclick(--[[---@type function]] callback)
        end
        local button = create_button(name, handle, frame)
        max_action_button_width = max(max_action_button_width, button:GetWidth())
        tinsert(buttons, button)
    end
    for _, button in ipairs(buttons) do
        button:SetWidth(max_action_button_width)
    end
    return buttons
end

---@param frame Frame
---@param scroll_frame ScrollFrame
---@param edit_box EditBox
---@param action_buttons Button[]
function KethoWindow:__setup_layout(frame, scroll_frame, edit_box, action_buttons)
    ---@type Region|nil
    local anchor
    ---@type WidgetAnchorPoint|nil
    local anchor_point

    local vert_button_interval = 1
    for _, button in ipairs(action_buttons) do
        button:SetPoint('LEFT', frame, 'LEFT', 16, 0)
        if anchor ~= nil then
            button:SetPoint('TOP', anchor, anchor_point, 0, -vert_button_interval)
        end
        anchor = button
        anchor_point = 'BOTTOM'
    end

    local top_button = action_buttons[1]
    local vert_button_padding = 32
    top_button:SetPoint('TOP', frame, 'TOP', 0, -vert_button_padding)
    frame:SetWidth(500)
    frame:SetHeight(2 * vert_button_padding + getn(action_buttons) * top_button:GetHeight() + (getn(action_buttons) - 1) * vert_button_interval)

    local bottomButton = action_buttons[getn(action_buttons)]
    scroll_frame:SetPoint('TOPLEFT', top_button, 'TOPRIGHT', 8, 0)
    scroll_frame:SetPoint('RIGHT', frame, 'RIGHT', -40, 0)
    scroll_frame:SetPoint('BOTTOM', bottomButton, 'BOTTOM', 0, 8)

    edit_box:SetPoint('TOPLEFT', scroll_frame, 'TOPLEFT')
    edit_box:SetPoint('BOTTOMRIGHT', scroll_frame, 'BOTTOMRIGHT')
end

---@param actions Action[]
function KethoWindow:Create(actions)
    if _G[FRAME_NAME] == nil then
        local frame = self:__create_frame()
        local scroll_frame, edit_box = self:__create_text_controls(frame)
        local action_buttons = self:__create_action_buttons(frame, actions, function(callback)
            return function() edit_box:SetText(callback()) end
        end)
        self:__setup_layout(frame, scroll_frame, edit_box, action_buttons)
        self.__frame = frame
    end
end

function KethoWindow:Show()
    self.__frame:Show()
end
