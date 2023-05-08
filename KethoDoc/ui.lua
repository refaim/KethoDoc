local _G = getfenv(0)

KethoWindow = {}

function KethoWindow:Create(actions)
    local frame = CreateFrame("Frame", "KethoWindowFrame", UIParent)
    self.mainFrame = frame

    frame:SetPoint("CENTER", UIParent)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", function()
        if arg1 == "LeftButton" then
            this:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function()
        if arg1 == "LeftButton" then
            this:StopMovingOrSizing()
        end
    end)

    self.buttons = {}
    for _, action in ipairs(actions) do
        self:AddButton(action["name"], action["callback"])
    end

    --local scrollFrame = CreateFrame("ScrollFrame", "KethoWindowScrollFrame", frame, "UIPanelScrollFrameTemplate")
    ----sf:SetPoint("LEFT", 16, 0)
    ----sf:SetPoint("RIGHT", -32, 0)
    ----sf:SetPoint("TOP", 0, -16)
    ----sf:SetPoint("BOTTOM", frame, "BOTTOM", 0, 50)
    --scrollFrame:SetScrollChild(editBox)
    --
    --local editBox = CreateFrame("EditBox", "KethoWindowEditBox", frame)
    ----eb:SetSize(sf:GetSize())
    --eb:SetMultiLine(true)
    --eb:SetAutoFocus(false) -- TODO !!!
    --eb:SetFontObject("ChatFontNormal")
    ----eb:SetScript("OnEscapePressed", eb.ClearFocus)

    --self.scrollFrame = scrollFrame
    --self.editBox = editBox
end

--- @param id string
--- @param name string
function KethoWindow:AddButton(name, callback)
    local button = CreateFrame(
        "Button",
        "KethoWindow" .. string.gsub(name, "[_%s]+", "") .. "Button",
        self.mainFrame, "GameMenuButtonTemplate")

    tinsert(self.buttons, button)
    local buttons_num = getn(self.buttons)

    button:SetText(name)
    button:SetWidth(button:GetTextWidth() + 16)
    local intervals_height =  8 * (buttons_num - 1)
    button:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", 16, -1 * (16 * buttons_num + intervals_height))

    button:SetScript("OnClick", function()
        local oldText = button:GetText()
        button:SetText("Loading...")
        button:Disable()
        local data = callback()
        button:Enable()
        button:SetText(oldText)
        -- TODO output data to editbox
    end)

    local max_button_width = 0
    for _, btn in ipairs(self.buttons) do
        max_button_width = max(max_button_width, btn:GetWidth())
    end
    for _, btn in ipairs(self.buttons) do
        btn:SetWidth(max_button_width)
    end

    self.mainFrame:SetWidth(max_button_width + 32)
    self.mainFrame:SetHeight(button:GetHeight() * buttons_num + intervals_height - 8)
end

function KethoWindow:Show()
    self.mainFrame:Show()
end
