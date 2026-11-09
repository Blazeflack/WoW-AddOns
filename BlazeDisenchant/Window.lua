local _, addon = ...
local window, edit, scroll, status, reset, cancel
local confirming = false

local function cancelReset()
    confirming = false
    reset:SetText("Reset log")
    cancel:Hide()
end

local function formatEntry(i, entry)
    local materials = {}
    for id, count in pairs(entry.materials) do
        local name = C_Item.GetItemInfo(id)
        if issecretvalue(name) or not name then name = "Item" end
        materials[#materials + 1] = ("%dx %s [%d]"):format(count, name, id)
    end
    table.sort(materials)
    local name = entry.link:match("%[(.-)%]") or "Item"
    return ("#%d  %s  %s [%d], ilvl %d, bag %d slot %d, build %s: %s"):format(
        i, date("%Y-%m-%d %H:%M:%S", entry.time), name, entry.itemID, entry.itemLevel,
        entry.bag, entry.slot, entry.build, table.concat(materials, ", "))
end

function addon.refreshLog()
    if not window or not window:IsShown() then return end
    cancelReset()
    local entries = BlazeDisenchantDB.attempts
    local lines = {}
    for i = #entries, 1, -1 do lines[#lines + 1] = formatEntry(i, entries[i]) end
    edit:SetText(table.concat(lines, "\n"))
    edit:SetCursorPosition(0)
    scroll:SetVerticalScroll(0)
    status:SetText(("%d observations. %s"):format(#entries, addon.getStatus()))
    reset:SetEnabled(#entries > 0)
end

local function button(label, width, onClick)
    local b = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local function createWindow()
    window = CreateFrame("Frame", "BlazeDisenchantLogWindow", UIParent, "BackdropTemplate")
    window:Hide()
    window:SetSize(680, 420)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
    window:SetBackdropColor(0.07, 0.07, 0.09, 0.98)
    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("BlazeDisenchant log")
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    status = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)

    scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -72)
    scroll:SetPoint("BOTTOMRIGHT", -38, 52)
    edit = CreateFrame("EditBox", nil, scroll)
    edit:SetWidth(624)
    edit:SetHeight(1)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetScript("OnEscapePressed", function() edit:ClearFocus() end)
    scroll:SetScrollChild(edit)

    local selectAll = button("Select all (Ctrl+C)", 148, function()
        edit:SetFocus()
        edit:HighlightText()
    end)
    selectAll:SetPoint("BOTTOMLEFT", 16, 14)
    reset = button("Reset log", 148, function()
        if confirming then
            addon.resetLog()
        else
            confirming = true
            reset:SetText("Confirm reset")
            cancel:Show()
        end
    end)
    reset:SetPoint("BOTTOMRIGHT", -16, 14)
    cancel = button("Cancel", 80, cancelReset)
    cancel:SetPoint("RIGHT", reset, "LEFT", -6)
    window:SetScript("OnShow", addon.refreshLog)
    window:SetScript("OnHide", function() edit:ClearFocus() end)
    table.insert(UISpecialFrames, "BlazeDisenchantLogWindow")
end

SLASH_BLAZEDISENCHANT1 = "/bde"
SLASH_BLAZEDISENCHANT2 = "/blazedisenchant"
SlashCmdList.BLAZEDISENCHANT = function()
    if not window then createWindow() end
    window:SetShown(not window:IsShown())
end
