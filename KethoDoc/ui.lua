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

    -- TODO draw background under frame, add button to select all text

    local scrollFrame = CreateFrame("ScrollFrame", "KethoWindowScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetWidth(frame:GetWidth() * 2)
    scrollFrame:SetHeight(frame:GetHeight());
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
    self.scrollFrame = scrollFrame

    local editBox = CreateFrame("EditBox", "KethoWindowEditBox", scrollFrame)
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetHeight(scrollFrame:GetHeight())
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetScript("OnEscapePressed", function () editBox:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)
    self.editBox = editBox
end

--- @param name string
--- @param callback fun():string
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
        self.editBox:SetText(callback())
        button:Enable()
        button:SetText(oldText)
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
