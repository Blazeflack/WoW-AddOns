local _, addon = ...

local function InitializeSettings()
    if type(BlazeTweaksCharDB) ~= "table" then BlazeTweaksCharDB = {} end
    if type(BlazeTweaksDB) ~= "table" then BlazeTweaksDB = {} end
    local db = BlazeTweaksCharDB
    if type(db.tweaks) ~= "table" then db.tweaks = {} end
    -- Preserve the existing keys and character-specific choices.
    for _, key in ipairs({ "autoOpenClams", "autoGossip" }) do
        if type(db.tweaks[key]) ~= "boolean" then db.tweaks[key] = false end
    end
    if type(db.gossipTypes) ~= "table" then db.gossipTypes = {} end
    for _, key in ipairs({ "bank", "taxi", "vendor" }) do
        if type(db.gossipTypes[key]) ~= "boolean" then db.gossipTypes[key] = true end
    end
    local items = {}
    if type(BlazeTweaksDB.containerItems) == "table" then
        for itemID, enabled in pairs(BlazeTweaksDB.containerItems) do
            if type(itemID) == "number" and itemID > 0
                and itemID < 2147483648 and itemID == math.floor(itemID)
                and enabled == true then
                items[itemID] = true
            end
        end
    end
    BlazeTweaksDB.containerItems = items
    local order, seen = {}, {}
    if type(BlazeTweaksDB.containerItemOrder) == "table" then
        for _, id in ipairs(BlazeTweaksDB.containerItemOrder) do
            if items[id] and not addon.Containers.defaults[id] and not seen[id] then
                order[#order + 1] = id
                seen[id] = true
            end
        end
    end
    -- Older saves contain only a set; their original insertion order is unknown.
    local missing = {}
    for id in pairs(items) do
        if not addon.Containers.defaults[id] and not seen[id] then missing[#missing + 1] = id end
    end
    table.sort(missing)
    for _, id in ipairs(missing) do order[#order + 1] = id end
    BlazeTweaksDB.containerItemOrder = order
    addon.db = db
    addon.shared = BlazeTweaksDB
end

local function ApplySetting(key, enabled)
    addon.db.tweaks[key] = enabled
    if key == "autoOpenClams" then
        addon.Containers:SetEnabled(enabled)
    else
        addon.Gossip:SetEnabled(enabled)
    end
end

local optionsFrame
local requestedItems, failedItems = {}, {}
local pendingAdd, requestRevision = nil, 0
local feedbackRevision = 0
local hoveredRow
local RefreshItems
local LIST_WIDTH, LIST_HEIGHT = 524, 180
local ITEM_WIDTH, ITEM_STEP = 256, 38
local fonts

-- Match BlazeMail's palette and typography without requiring that addon.
local function InitializeFonts()
    if fonts then return end
    local function SizedFont(name, base, size, muted)
        local font = CreateFont(name)
        font:SetFontObject(base)
        local file, _, flags = base:GetFont()
        font:SetFont(file, size, flags)
        if muted then font:SetTextColor(0.69, 0.66, 0.60)
        else font:SetTextColor(0.933, 0.910, 0.863) end
        font:SetShadowOffset(0, 0)
        return font
    end
    fonts = {
        normal = SizedFont("BlazeTweaksFontNormal", GameFontHighlight, 13),
        small = SizedFont("BlazeTweaksFontSmall", GameFontHighlightSmall, 11),
        disabled = SizedFont("BlazeTweaksFontDisabled", GameFontDisableSmall, 11, true),
    }
end

local function Fill(frame, layer, r, g, b, a, inset)
    local texture = frame:CreateTexture(nil, layer)
    inset = inset or 0
    texture:SetPoint("TOPLEFT", inset, -inset)
    texture:SetPoint("BOTTOMRIGHT", -inset, inset)
    texture:SetColorTexture(r, g, b, a or 1)
    return texture
end

local function ThemeButton(button)
    button:SetNormalFontObject(fonts.small)
    button:SetHighlightFontObject(fonts.small)
    button:SetDisabledFontObject(fonts.disabled)
    button:SetNormalTexture(Fill(button, "BACKGROUND", 0.224, 0.173, 0.129))
    button:SetPushedTexture(Fill(button, "BACKGROUND", 0.29, 0.22, 0.15))
    button:SetDisabledTexture(Fill(button, "BACKGROUND", 0.18, 0.145, 0.11))
    button:SetHighlightTexture(Fill(button, "HIGHLIGHT", 0.706, 0.604, 0.420, 0.15))
end

local function ThemeCheckbox(checkbox, text)
    checkbox:SetNormalTexture(Fill(checkbox, "BACKGROUND", 0.408, 0.318, 0.227, 1, 4))
    Fill(checkbox, "ARTWORK", 0.224, 0.173, 0.129, 1, 5)
    checkbox:SetCheckedTexture(Fill(checkbox, "OVERLAY", 0.706, 0.604, 0.420, 1, 8))
    checkbox:SetHighlightTexture(Fill(checkbox, "HIGHLIGHT", 0.706, 0.604, 0.420, 0.15, 4))
    local label = checkbox:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(fonts.small)
    label:SetPoint("LEFT", checkbox, "RIGHT", 3, 0)
    label:SetText(text)
end

local function ShowFeedback(text)
    feedbackRevision = feedbackRevision + 1
    local revision = feedbackRevision
    optionsFrame.message:SetText(text)
    C_Timer.After(5, function()
        if feedbackRevision == revision then optionsFrame.message:SetText("") end
    end)
end

local function UpdateItemScrollbar(range)
    range = math.max(0, range)
    local scroll, bar = optionsFrame.listScroll, optionsFrame.listScrollbar
    local offset = math.min(scroll:GetVerticalScroll(), range)
    bar:SetMinMaxValues(0, range)
    bar:SetValue(offset)
    scroll:SetVerticalScroll(offset)
    if range > 0 then bar:Show() else bar:Hide() end
end

local function RestartContainers()
    addon.Containers:SetEnabled(false)
    addon.Containers:SetEnabled(addon.db.tweaks.autoOpenClams)
end

local function ShowItemTooltip(row)
    hoveredRow = row
    local name, link = C_Item.GetItemInfo(row.itemID)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if name then
        GameTooltip:SetHyperlink(link or ("item:" .. row.itemID))
    else
        GameTooltip:SetText("Item " .. row.itemID)
        GameTooltip:AddLine(failedItems[row.itemID] and "Could not load item data." or "Loading item data...", 1, 1, 1)
    end
    GameTooltip:Show()
end

local function HideItemTooltip(row)
    if hoveredRow == row then
        hoveredRow = nil
        GameTooltip:Hide()
    end
end

local function RequestItem(itemID)
    if requestedItems[itemID] or failedItems[itemID] then return end
    requestedItems[itemID] = true
    C_Item.RequestLoadItemDataByID(itemID)
end

RefreshItems = function()
    local ids = {}
    for id in pairs(addon.Containers.defaults) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(addon.shared.containerItemOrder) do ids[#ids + 1] = id end
    for index, id in ipairs(ids) do
        local row = optionsFrame.rows[index]
        if not row then
            row = CreateFrame("Button", nil, optionsFrame.listContent)
            row:SetSize(ITEM_WIDTH, 36)
            row:SetPoint("TOPLEFT", ((index - 1) % 2) * (ITEM_WIDTH + 12), -math.floor((index - 1) / 2) * ITEM_STEP)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(28, 28)
            row.icon:SetPoint("LEFT", 2, 0)
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.name:SetFontObject(fonts.small)
            row.name:SetPoint("TOPLEFT", 38, -3)
            row.name:SetWidth(ITEM_WIDTH - 65)
            row.name:SetJustifyH("LEFT")
            row.name:SetWordWrap(false)
            row.details = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.details:SetFontObject(fonts.disabled)
            row.details:SetPoint("TOPLEFT", 38, -19)
            row.remove = CreateFrame("Button", nil, row)
            ThemeButton(row.remove)
            row.remove:SetSize(20, 20)
            row.remove:SetPoint("RIGHT", -1, 0)
            row.remove:SetText("X")
            row.remove:SetScript("OnClick", function()
                if addon.Containers.defaults[row.itemID] then return end
                addon.shared.containerItems[row.itemID] = nil
                for position, id in ipairs(addon.shared.containerItemOrder) do
                    if id == row.itemID then
                        table.remove(addon.shared.containerItemOrder, position)
                        break
                    end
                end
                HideItemTooltip(row)
                RestartContainers()
                RefreshItems()
                ShowFeedback("Item removed from the shared list.")
            end)
            row:SetScript("OnEnter", ShowItemTooltip)
            row:SetScript("OnLeave", HideItemTooltip)
            row:SetScript("OnHide", HideItemTooltip)
            optionsFrame.rows[index] = row
        end
        if row.itemID ~= id then HideItemTooltip(row) end
        row.itemID = id
        local name, link, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
        row.icon:SetTexture(icon or 134400)
        row.name:SetText(link or name or (failedItems[id] and ("Item " .. id .. " (data unavailable)") or "Loading item..."))
        row.details:SetText("ID: " .. id .. (addon.Containers.defaults[id] and "  ·  Default" or ""))
        if addon.Containers.defaults[id] then row.remove:Hide() else row.remove:Show() end
        row:Show()
        if hoveredRow == row then ShowItemTooltip(row) end
        if not name then RequestItem(id) end
    end
    for index = #ids + 1, #optionsFrame.rows do
        HideItemTooltip(optionsFrame.rows[index])
        optionsFrame.rows[index]:Hide()
    end
    local height = math.max(LIST_HEIGHT, math.ceil(#ids / 2) * ITEM_STEP)
    optionsFrame.listContent:SetHeight(height)
    optionsFrame.listScroll:UpdateScrollChildRect()
    UpdateItemScrollbar(height - LIST_HEIGHT)
end

local function SaveNewItem(itemID)
    if not addon.shared.containerItems[itemID] then
        table.insert(addon.shared.containerItemOrder, itemID)
    end
    addon.shared.containerItems[itemID] = true
    RestartContainers()
    RefreshItems()
    if tonumber(optionsFrame.itemInput:GetText()) == itemID then optionsFrame.itemInput:SetText("") end
    if optionsFrame:IsShown() then optionsFrame.itemInput:SetFocus() end
    ShowFeedback("Item added for all characters.")
end

local function AddItem()
    if pendingAdd then return end
    local text = optionsFrame.itemInput:GetText():match("^%s*(.-)%s*$")
    local id = tonumber(text)
    if not text:match("^%d+$") or not id or id <= 0 or id >= 2147483648 then
        ShowFeedback("Enter a valid item ID.")
        return
    end
    if addon.Containers.defaults[id] or addon.shared.containerItems[id] then
        ShowFeedback("This item is already on the list.")
        return
    end
    if C_Item.GetItemInfo(id) then SaveNewItem(id); return end
    pendingAdd = id
    requestRevision = requestRevision + 1
    local revision = requestRevision
    failedItems[id] = nil
    optionsFrame.addButton:Disable()
    ShowFeedback("Checking item " .. id .. "...")
    RequestItem(id)
    C_Timer.After(5, function()
        if pendingAdd == id and requestRevision == revision then
            pendingAdd = nil
            requestedItems[id] = nil
            optionsFrame.addButton:Enable()
            ShowFeedback("Item lookup timed out. Try again.")
        end
    end)
end

local function ShowOptions()
    if not addon.db then return end
    if not optionsFrame then
        InitializeFonts()
        optionsFrame = CreateFrame("Frame", "BlazeTweaksOptionsFrame", UIParent, "BackdropTemplate")
        optionsFrame:SetSize(600, 585)
        optionsFrame:SetPoint("CENTER")
        optionsFrame:SetFrameStrata("DIALOG")
        optionsFrame:SetClampedToScreen(true)
        optionsFrame:SetMovable(true)
        optionsFrame:EnableMouse(true)
        optionsFrame:RegisterForDrag("LeftButton")
        optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
        optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
        optionsFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        optionsFrame:SetBackdropColor(0.157, 0.125, 0.094, 1)
        optionsFrame:SetBackdropBorderColor(0.408, 0.318, 0.227, 1)

        local function Label(text, x, y, font)
            local label = optionsFrame:CreateFontString(nil, "OVERLAY")
            label:SetFontObject(font or fonts.small)
            label:SetPoint("TOPLEFT", x, y)
            label:SetText(text)
            return label
        end
        Label("BlazeTweaks", 22, -22, fonts.normal)
        Label("Settings for: " .. UnitName("player") .. " - " .. GetRealmName(), 22, -48)
        Label("Changes apply immediately. Both tweaks are disabled by default.", 22, -74)
        Label("Containers", 22, -104, fonts.normal)
        Label("Gossip", 22, -484, fonts.normal)
        for _, y in ipairs({ -94, -467 }) do
            local separator = optionsFrame:CreateTexture(nil, "ARTWORK")
            separator:SetSize(556, 1)
            separator:SetPoint("TOPLEFT", 22, y)
            separator:SetColorTexture(0.408, 0.318, 0.227, 1)
        end
        local close = CreateFrame("Button", nil, optionsFrame)
        ThemeButton(close)
        close:SetSize(24, 23)
        close:SetText("X")
        close:SetPoint("TOPRIGHT", -12, -12)
        close:SetScript("OnClick", function() optionsFrame:Hide() end)

        optionsFrame.checkboxes = {}
        local tweaks = {
            { key = "autoOpenClams", name = "Automatically open new clams and containers", y = -124 },
            { key = "autoGossip", name = "Automatically select gossip (hold Shift to skip)", y = -504 },
        }
        for index, tweak in ipairs(tweaks) do
            local key = tweak.key
            local checkbox = CreateFrame("CheckButton", "BlazeTweaksOption" .. index, optionsFrame)
            checkbox:SetSize(26, 26)
            checkbox:SetPoint("TOPLEFT", 22, tweak.y)
            ThemeCheckbox(checkbox, tweak.name)
            checkbox:SetScript("OnClick", function(self)
                ApplySetting(key, self:GetChecked() and true or false)
            end)
            optionsFrame.checkboxes[key] = checkbox
        end
        optionsFrame.gossipCheckboxes = {}
        local gossipTypes = {
            { key = "bank", name = "Bank" },
            { key = "taxi", name = "Taxi" },
            { key = "vendor", name = "Vendor" },
        }
        for index, gossipType in ipairs(gossipTypes) do
            local key = gossipType.key
            local checkbox = CreateFrame("CheckButton", "BlazeTweaksGossipType" .. index, optionsFrame)
            checkbox:SetSize(24, 24)
            checkbox:SetPoint("TOPLEFT", 42 + (index - 1) * 160, -539)
            ThemeCheckbox(checkbox, gossipType.name)
            checkbox:SetScript("OnClick", function(self)
                addon.db.gossipTypes[key] = self:GetChecked() and true or false
            end)
            optionsFrame.gossipCheckboxes[key] = checkbox
        end
        Label("Item list — shared by all characters", 22, -160)
        Label("Item ID:", 22, -191)

        local edit = CreateFrame("EditBox", nil, optionsFrame, "BackdropTemplate")
        edit:SetSize(100, 26)
        edit:SetPoint("TOPLEFT", 80, -183)
        edit:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        edit:SetBackdropColor(0.224, 0.173, 0.129, 1)
        edit:SetBackdropBorderColor(0.408, 0.318, 0.227, 1)
        edit:SetMultiLine(false)
        edit:SetAutoFocus(false)
        edit:SetFontObject(fonts.small)
        edit:SetTextInsets(6, 6, 0, 0)
        edit:SetNumeric(true)
        edit:SetMaxLetters(10)
        edit:SetBlinkSpeed(0.5)
        edit:EnableMouse(true)
        edit:SetScript("OnMouseDown", function(self) self:SetFocus() end)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        edit:SetScript("OnEnterPressed", AddItem)
        optionsFrame.itemInput = edit
        local add = CreateFrame("Button", nil, optionsFrame)
        ThemeButton(add)
        add:SetSize(76, 26)
        add:SetPoint("LEFT", edit, "RIGHT", 8, 0)
        add:SetText("Add")
        add:SetScript("OnClick", AddItem)
        optionsFrame.addButton = add

        local scroll = CreateFrame("ScrollFrame", nil, optionsFrame)
        scroll:SetPoint("TOPLEFT", 26, -225)
        scroll:SetSize(LIST_WIDTH, LIST_HEIGHT)
        scroll:SetClipsChildren(true)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(LIST_WIDTH, LIST_HEIGHT)
        scroll:SetScrollChild(content)
        optionsFrame.listScroll, optionsFrame.listContent, optionsFrame.rows = scroll, content, {}
        -- Explicit slider: drag and mouse-wheel use the same bounded offset.
        local bar = CreateFrame("Slider", nil, optionsFrame, "BackdropTemplate")
        bar:SetSize(16, LIST_HEIGHT)
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 0)
        bar:SetOrientation("VERTICAL")
        bar:EnableMouse(true)
        bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        bar:SetBackdropColor(0.224, 0.173, 0.129, 1)
        local thumb = bar:CreateTexture(nil, "ARTWORK")
        thumb:SetColorTexture(0.706, 0.604, 0.420, 1)
        bar:SetThumbTexture(thumb)
        bar:GetThumbTexture():SetSize(16, 24)
        bar:SetValueStep(1)
        bar:SetMinMaxValues(0, 0)
        bar:SetValue(0)
        bar:SetScript("OnValueChanged", function(_, value) scroll:SetVerticalScroll(value) end)
        optionsFrame.listScrollbar = bar
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(_, delta)
            local range = math.max(0, content:GetHeight() - LIST_HEIGHT)
            bar:SetValue(math.max(0, math.min(range, scroll:GetVerticalScroll() - delta * ITEM_STEP)))
        end)
        scroll:SetScript("OnScrollRangeChanged", function(_, _, range) UpdateItemScrollbar(range) end)

        local message = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        message:SetFontObject(fonts.small)
        message:SetPoint("LEFT", add, "RIGHT", 10, 0)
        message:SetWidth(300)
        message:SetJustifyH("LEFT")
        optionsFrame.message = message
        Label("Only newly acquired items are opened. Default items cannot be removed.", 22, -442)
        optionsFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
        optionsFrame:SetScript("OnEvent", function(_, _, itemID, success)
            if not requestedItems[itemID] then return end
            requestedItems[itemID] = nil
            failedItems[itemID] = (not success or not C_Item.GetItemInfo(itemID)) or nil
            if pendingAdd == itemID then
                pendingAdd = nil
                optionsFrame.addButton:Enable()
                if success and C_Item.GetItemInfo(itemID) then
                    SaveNewItem(itemID)
                else
                    ShowFeedback("Item " .. itemID .. " not found. Check the ID.")
                end
            else
                RefreshItems()
            end
        end)
        optionsFrame:SetScript("OnHide", function()
            edit:ClearFocus()
            if hoveredRow then HideItemTooltip(hoveredRow) end
        end)
        table.insert(UISpecialFrames, "BlazeTweaksOptionsFrame")
        optionsFrame:Hide()
    end

    for key, checkbox in pairs(optionsFrame.checkboxes) do
        checkbox:SetChecked(addon.db.tweaks[key])
    end
    for key, checkbox in pairs(optionsFrame.gossipCheckboxes) do
        checkbox:SetChecked(addon.db.gossipTypes[key])
    end
    failedItems = {}
    RefreshItems()
    optionsFrame:Show()
end

SLASH_BLAZETWEAKS1 = "/bt"
SLASH_BLAZETWEAKS2 = "/blazetweaks"
SlashCmdList.BLAZETWEAKS = ShowOptions

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    InitializeSettings()
    addon.Containers:SetEnabled(addon.db.tweaks.autoOpenClams)
    addon.Gossip:SetEnabled(addon.db.tweaks.autoGossip)
end)
