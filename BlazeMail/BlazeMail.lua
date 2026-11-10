local addonName, addon = ...
local eventFrame = CreateFrame("Frame")
local popup, picker, Refresh, OpenPicker
local settingsTab
local page, managing, pendingDelete = 1, false, nil
local editingNote, positionKey
local pendingMail
local mailSession, recipientRevision = 0, 0
local PAGE_SIZE = 7
local fonts
local LAYOUT_SCALE = 1
local function Layout(value) return value * LAYOUT_SCALE end

local function GetFonts()
    if addon.IsBlizzardTheme() then
        return { normal = GameFontHighlight, small = GameFontHighlightSmall, disabled = GameFontDisableSmall }
    end
    if not fonts then
        local function SizedFont(name, base, size)
            local font = CreateFont(name)
            font:SetFontObject(base)
            local file, _, flags = base:GetFont()
            font:SetFont(file, size, flags)
            font:SetTextColor(0.933, 0.910, 0.863)
            font:SetShadowOffset(0, 0)
            return font
        end
        fonts = {
            normal = SizedFont("BlazeMailFontNormal", GameFontHighlight, 13),
            small = SizedFont("BlazeMailFontSmall", GameFontHighlightSmall, 11),
            disabled = SizedFont("BlazeMailFontDisabled", GameFontDisableSmall, 11),
        }
        fonts.disabled:SetTextColor(0.69, 0.66, 0.60)
    end
    return fonts
end
addon.GetFonts = GetFonts

local function SavePosition()
    if not popup.moving then return end
    popup:StopMovingOrSizing()
    popup.moving = false
    if not positionKey then return end
    local x, y = popup:GetCenter()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if x and y and width > 0 and height > 0 then
        BlazeMailDB.positions = BlazeMailDB.positions or {}
        BlazeMailDB.positions[positionKey] = { x = x / width, y = y / height }
    end
end

local function RegisterShortAlias()
    local command = "/BM"
    -- The chat parser uses uppercase cache keys. Also inspect pending aliases
    -- that have not yet been imported into those caches.
    if (IsSecureCmd and IsSecureCmd(command))
        or (hash_SlashCmdList and hash_SlashCmdList[command])
        or (hash_ChatTypeInfoList and hash_ChatTypeInfoList[command])
        or (hash_EmoteTokenList and hash_EmoteTokenList[command]) then return end
    for name in pairs(SlashCmdList) do
        local index = 1
        local alias = _G["SLASH_" .. name .. index]
        while alias do
            if type(alias) == "string" and alias:upper() == command then return end
            index = index + 1
            alias = _G["SLASH_" .. name .. index]
        end
    end
    SLASH_BLAZEMAIL2 = "/bm"
end

local function Label(parent, text, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(GetFonts().normal)
    label:SetPoint("TOPLEFT", Layout(x), Layout(y))
    label:SetWidth(Layout(width))
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(text)
    return label
end

local function Button(parent, text, width, height, callback, listRow)
    local blizzard = addon.IsBlizzardTheme()
    local template = blizzard and not listRow and "UIPanelButtonTemplate" or nil
    local button = CreateFrame("Button", nil, parent, template)
    button:SetSize(Layout(width), Layout(height))
    if listRow then button:EnableMouse(true) end
    if blizzard and listRow then
        local fill = button:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(0.08, 0.07, 0.06, 0.85)
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 0.82, 0, 0.12)
        button:SetHighlightTexture(highlight)
    end
    if not blizzard then
        local background = button:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.224, 0.173, 0.129, 1)
        button.background = background
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.706, 0.604, 0.420, 0.15)
        button:SetHighlightTexture(highlight)
        button:SetNormalFontObject(GetFonts().small)
        button:SetHighlightFontObject(GetFonts().small)
        button:SetDisabledFontObject(GetFonts().disabled)
    end
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function Outline(frame, thickness)
    local lines = {}
    for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local line = frame:CreateTexture(nil, "OVERLAY")
        line:SetPoint(edge[1])
        line:SetPoint(edge[2])
        if edge[3] then line:SetHeight(thickness) else line:SetWidth(thickness) end
        line:SetColorTexture(0.68, 0.59, 0.43, 0.8)
        line:Hide()
        lines[#lines + 1] = line
    end
    return lines
end

local function EditBox(parent, width, height)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(Layout(width), Layout(height))
    box:EnableMouse(true)
    box:SetBlinkSpeed(0.5)
    box:SetScript("OnMouseDown", function(self) self:SetFocus() end)
    box:SetAutoFocus(false)
    box:SetFontObject(GetFonts().small)
    box:SetTextInsets(Layout(6), Layout(6), Layout(2), Layout(2))
    local background = box:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    if addon.IsBlizzardTheme() then
        background:SetColorTexture(0.06, 0.06, 0.06, 1)
    else
        background:SetColorTexture(0.224, 0.173, 0.129, 1)
    end
    box.focusBorder = Outline(box, 1)
    local function Focus(shown)
        for _, line in ipairs(box.focusBorder) do line:SetShown(shown) end
    end
    box:SetScript("OnEditFocusGained", function() Focus(true) end)
    box:SetScript("OnEditFocusLost", function() Focus(false) end)
    box:SetScript("OnHide", function(self) self:ClearFocus(); Focus(false) end)
    box:SetText("")
    return box
end

local function FillRecipient(name)
    SendMailNameEditBox:SetText(name)
    SendMailNameEditBox:ClearFocus()
    SendMailNameEditBox:SetCursorPosition(0)
end

local function RestoreSentRecipient()
    local sent = pendingMail
    pendingMail = nil
    if not sent then return end
    -- Blizzard clears the form in its own MAIL_SEND_SUCCESS handler. Waiting
    -- until the next frame makes this independent of event-handler ordering.
    C_Timer.After(0, function()
        if sent.session ~= mailSession or not SendMailFrame:IsShown() then return end
        if sent.revision == recipientRevision and SendMailNameEditBox:GetText() == "" then
            FillRecipient(sent.name)
        end
        if BlazeMailDB.openAutomatically then
            OpenPicker(false, true)
        end
    end)
end

local function SelectRecipient(entry)
    -- Recheck scope and mailbox visibility at click time.
    local current, character = addon.current, BlazeMailDB.characters[entry.id]
    if not current or not character or entry.id == current.guid
        or character.region ~= current.region or character.ruleset ~= current.ruleset
        or character.faction ~= current.faction
        or not SendMailFrame or not SendMailFrame:IsShown() then return end
    recipientRevision = recipientRevision + 1
    FillRecipient(character.name)
    popup:Hide()
end

local function CreatePopup()
    if popup then return end
    local blizzard = addon.IsBlizzardTheme()
    popup = CreateFrame("Frame", "BlazeMailPicker", UIParent, blizzard and "DefaultPanelTemplate" or nil)
    popup:SetSize(Layout(390), Layout(240))
    popup:SetFrameStrata("DIALOG")
    popup:SetClampedToScreen(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    if not blizzard then
        local border = popup:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(0.408, 0.318, 0.227, 1)
        local background = popup:CreateTexture(nil, "BORDER")
        background:SetPoint("TOPLEFT", 1, -1)
        background:SetPoint("BOTTOMRIGHT", -1, 1)
        background:SetColorTexture(0.157, 0.125, 0.094, 1)
        popup.title = Label(popup, "BlazeMail", 12, -12, 366)
    else
        popup.title = popup.TitleContainer.TitleText
    end
    local titleBar = CreateFrame("Frame", nil, popup)
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    titleBar:SetHeight(Layout(30))
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        popup:StartMoving()
        popup.moving = true
    end)
    titleBar:SetScript("OnDragStop", SavePosition)
    if blizzard then
        popup.CloseButton = CreateFrame("Button", nil, popup, "UIPanelCloseButtonDefaultAnchors")
    end
    popup.context = Label(popup, "", 12, -35, 366)
    popup.context:SetFontObject(GetFonts().small)
    popup.searchLabel = Label(popup, "Search:", 12, -66, 54)
    popup.search = EditBox(popup, 250, 25)
    popup.search:SetPoint("TOPLEFT", Layout(68), Layout(-58))
    popup.search:SetMaxLetters(77)
    popup.clearSearch = Button(popup, "X", 32, 25, function()
        popup.search:SetText("")
        popup.search:ClearFocus()
    end)
    popup.clearSearch:SetPoint("TOPRIGHT", Layout(-12), Layout(-58))
    popup.rows = {}
    for i = 1, PAGE_SIZE do
        local row = Button(popup, "", 342, 64, function(self)
            if managing then
                pendingDelete = self.entry
                GameTooltip:Hide()
                popup.search:ClearFocus()
                Refresh()
            else
                SelectRecipient(self.entry)
            end
        end, true)
        row.selection = row:CreateTexture(nil, "ARTWORK")
        row.selection:SetAllPoints()
        row.selection:SetColorTexture(addon.accent.r, addon.accent.g, addon.accent.b, 0.30)
        row.selection:Hide()
        row.favoriteBorder = {}
        local edges = {
            { "TOPLEFT", "TOPRIGHT", true },
            { "BOTTOMLEFT", "BOTTOMRIGHT", true },
            { "TOPLEFT", "BOTTOMLEFT", false },
            { "TOPRIGHT", "BOTTOMRIGHT", false },
        }
        for _, edge in ipairs(edges) do
            local line = row:CreateTexture(nil, "OVERLAY")
            line:SetColorTexture(addon.accent.r, addon.accent.g, addon.accent.b, 1)
            line:SetPoint(edge[1], row, edge[1])
            line:SetPoint(edge[2], row, edge[2])
            if edge[3] then line:SetHeight(2) else line:SetWidth(2) end
            line:Hide()
            row.favoriteBorder[#row.favoriteBorder + 1] = line
        end
        row.favorite = Button(row, "Favorite", 90, 24, function()
            if not managing or pendingDelete or editingNote then return end
            GameTooltip:Hide()
            addon.ToggleFavorite(row.entry.id)
            Refresh()
        end)
        row.favorite:SetPoint("TOPRIGHT", Layout(-8), Layout(-6))
        row.favorite:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(row.entry.character.favorite and "Remove favorite" or "Add favorite")
            GameTooltip:Show()
        end)
        row.favorite:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.note = Button(row, "Note", 90, 24, function()
            if not managing or pendingDelete or editingNote then return end
            GameTooltip:Hide()
            editingNote = row.entry
            popup.search:ClearFocus()
            popup.noteInput:SetText(editingNote.character.note or "")
            Refresh()
            popup.noteInput:SetFocus()
        end)
        row.note:SetPoint("BOTTOMRIGHT", Layout(-8), Layout(6))
        for _, action in ipairs({ row.favorite, row.note }) do
            if not blizzard then
                action.background:SetColorTexture(0.32, 0.245, 0.17, 1)
                for _, edge in ipairs(edges) do
                    local line = action:CreateTexture(nil, "OVERLAY")
                    line:SetColorTexture(0.55, 0.43, 0.29, 1)
                    line:SetPoint(edge[1], action, edge[1])
                    line:SetPoint(edge[2], action, edge[2])
                    if edge[3] then line:SetHeight(1) else line:SetWidth(1) end
                end
            end
        end
        row.name = Label(row, "", 10, -10, 248)
        row.detail = Label(row, "", 10, -32, 248)
        row.detail:SetFontObject(GetFonts().small)
        row:SetScript("OnEnter", function(self)
            if self.entry then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local character = self.entry.character
                GameTooltip:SetText(character.name .. (character.note and ("\n" .. character.note) or ""))
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        popup.rows[i] = row
    end
    popup.empty = Label(popup, "", 16, -108, 358)
    popup.previous = Button(popup, "<", 30, 22, function()
        page = math.max(1, page - 1)
        Refresh()
    end)
    popup.next = Button(popup, ">", 30, 22, function()
        page = page + 1
        Refresh()
    end)
    popup.page = Label(popup, "", 165, -397, 85)
    popup.noteLabel = Label(popup, "Set note:", 24, 0, 66)
    popup.noteInput = EditBox(popup, 270, 25)
    popup.noteInput:SetMaxLetters(100)
    popup.manage = Button(popup, "Characters / Settings", 180, 24, function()
        managing, pendingDelete, editingNote, page = not managing, nil, nil, 1
        popup.visibleSlots, popup.showPagination = nil, nil
        Refresh()
    end)
    popup.manage:SetPoint("BOTTOMLEFT", Layout(12), Layout(12))
    popup.close = Button(popup, "Close", 110, 24, function() popup:Hide() end)
    popup.close:SetPoint("BOTTOMRIGHT", Layout(-12), Layout(12))
    popup.confirm = Button(popup, "Remove", 150, 24, function()
        if editingNote then
            addon.SetNote(editingNote.id, popup.noteInput:GetText())
        elseif pendingDelete then
            addon.RemoveCharacter(pendingDelete.id)
        end
        pendingDelete, editingNote = nil, nil
        popup.noteInput:ClearFocus()
        Refresh()
    end)
    popup.confirm:SetPoint("BOTTOMLEFT", Layout(12), Layout(12))
    popup.cancel = Button(popup, "Cancel", 150, 24, function()
        pendingDelete, editingNote = nil, nil
        popup.noteInput:ClearFocus()
        Refresh()
    end)
    popup.cancel:SetPoint("BOTTOMRIGHT", Layout(-12), Layout(12))
    popup.themeLabel = Label(popup, "Theme:", 24, -46, 54)
    popup.dropdown = CreateFrame("DropdownButton", nil, popup, "WowStyle1DropdownTemplate")
    popup.dropdown:SetSize(148, 26)
    popup.dropdown:SetPoint("TOPLEFT", 84, -38)
    local function IsSelected(theme)
        return BlazeMailDB.theme == theme
    end
    local function SelectTheme(theme)
        BlazeMailDB.theme = theme
        Refresh()
    end
    popup.dropdown:SetupMenu(function(_, menu)
        menu:CreateRadio("BlazeMail", IsSelected, SelectTheme, "blaze")
        menu:CreateRadio("Blizzard", IsSelected, SelectTheme, "blizzard")
    end)
    popup.reload = Button(popup, "Reload UI", 110, 26, function() ReloadUI() end)
    popup.reload:SetPoint("TOPRIGHT", -24, -38)
    popup.autoOpen = CreateFrame("CheckButton", nil, popup, blizzard and "UICheckButtonTemplate" or nil)
    if blizzard then
        popup.autoOpen:SetPoint("TOPLEFT", Layout(19), Layout(-67))
        popup.autoOpen.Text:SetFontObject(GetFonts().normal)
        popup.autoOpen.Text:SetText("Open Automatically")
        popup.autoOpen.label = popup.autoOpen.Text
    else
        popup.autoOpen:SetSize(Layout(22), Layout(22))
        popup.autoOpen:SetPoint("TOPLEFT", Layout(24), Layout(-72))
        local background = popup.autoOpen:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.408, 0.318, 0.227, 1)
        local checked = popup.autoOpen:CreateTexture(nil, "ARTWORK")
        checked:SetPoint("TOPLEFT", 5, -5)
        checked:SetPoint("BOTTOMRIGHT", -5, 5)
        checked:SetColorTexture(0.933, 0.910, 0.863, 1)
        popup.autoOpen:SetCheckedTexture(checked)
        popup.autoOpen.label = Label(popup.autoOpen, "Open Automatically", 28, -4, 160)
    end
    popup.autoOpen:SetHitRectInsets(0, Layout(-160), 0, 0)
    popup.autoOpen:SetScript("OnClick", function(self)
        BlazeMailDB.openAutomatically = self:GetChecked() == true
    end)
    popup.autoOpen:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("When enabled, the list of alts opens automatically when you switch to the Send Mail tab and after successfully sending mail.", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    popup.autoOpen:SetScript("OnLeave", function() GameTooltip:Hide() end)
    popup:SetScript("OnHide", function()
        SavePosition()
        popup.search:ClearFocus()
        popup.noteInput:ClearFocus()
        pendingDelete, editingNote = nil, nil
    end)
    popup.search:SetScript("OnTextChanged", function()
        page = 1
        Refresh()
    end)
    popup.search:SetScript("OnEscapePressed", function() popup:Hide() end)
    popup.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    popup.noteInput:SetScript("OnEnterPressed", function() popup.confirm:GetScript("OnClick")() end)
    popup.noteInput:SetScript("OnEscapePressed", function() popup.cancel:GetScript("OnClick")() end)
    UISpecialFrames[#UISpecialFrames + 1] = "BlazeMailPicker"
    popup:Hide()
end

local function LayoutPopup(entryCount, pages)
    local rowHeight = managing and 64 or 48
    -- Keep capacity stable while searching or paging, so the controls do not
    -- move under the mouse/keyboard. Recalculate when the window is reopened
    -- or its recipient/management mode changes.
    if not popup.visibleSlots then
        local fullCount = #addon.GetCharacters(managing)
        popup.visibleSlots = math.max(1, math.min(PAGE_SIZE, fullCount))
        popup.showPagination = fullCount > PAGE_SIZE
    end
    local slots = math.max(popup.visibleSlots, math.min(PAGE_SIZE, entryCount))
    popup.visibleSlots = slots
    if pages > 1 then popup.showPagination = true end
    local searchTop = managing and 130 or 38
    local listTop = searchTop + 38
    local function Place(widget, point, x, y)
        widget:ClearAllPoints()
        widget:SetPoint(point, Layout(x), Layout(-y))
    end
    Place(popup.searchLabel, "TOPLEFT", 24, searchTop + 7)
    Place(popup.search, "TOPLEFT", 80, searchTop)
    Place(popup.clearSearch, "TOPRIGHT", -24, searchTop)
    Place(popup.context, "TOPLEFT", 24, searchTop - 21)
    Place(popup.empty, "TOPLEFT", 32, listTop + 10)
    for i, row in ipairs(popup.rows) do
        row:SetHeight(Layout(rowHeight))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", Layout(24), Layout(-listTop - (i - 1) * (rowHeight + 6)))
        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", Layout(14), Layout(managing and -10 or -8))
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", Layout(14), Layout(managing and -32 or -27))
    end
    local y = listTop + slots * (rowHeight + 6) - 6 + 10
    for _, control in ipairs({ popup.previous, popup.next, popup.page }) do control:SetShown(popup.showPagination) end
    popup.previous:ClearAllPoints()
    popup.previous:SetPoint("TOPLEFT", Layout(12), Layout(-y))
    popup.next:ClearAllPoints()
    popup.next:SetPoint("TOPRIGHT", Layout(-12), Layout(-y))
    popup.page:ClearAllPoints()
    popup.page:SetPoint("TOPLEFT", Layout(165), Layout(-y - 5))
    if popup.showPagination then y = y + 32 end
    Place(popup.noteLabel, "TOPLEFT", 24, y + 7)
    Place(popup.noteInput, "TOPLEFT", 96, y)
    if editingNote then y = y + 37 end
    popup:SetHeight(Layout(y + 46))
end

Refresh = function()
    local entries = addon.GetCharacters(managing, popup.search:GetText())
    local busy = pendingDelete or editingNote
    popup.themeLabel:SetShown(managing)
    popup.dropdown:SetShown(managing)
    popup.dropdown:SetEnabled(not busy)
    popup.reload:SetShown(managing)
    popup.reload:SetEnabled(not busy and BlazeMailDB.theme ~= addon.activeTheme)
    popup.autoOpen:SetShown(managing)
    popup.autoOpen:SetEnabled(not busy)
    popup.autoOpen:SetChecked(BlazeMailDB.openAutomatically == true)
    popup.context:SetShown(managing)
    local pages = math.max(1, math.ceil(#entries / PAGE_SIZE))
    page = math.max(1, math.min(page, pages))
    popup.title:SetText(managing and "BlazeMail - Characters / Settings" or "BlazeMail - Your alts")
    popup.context:SetText(pendingDelete and ("Remove " .. pendingDelete.character.name .. "?")
        or (editingNote and ("Note for " .. editingNote.character.name))
        or "Click a character to remove it from the saved list.")
    for i, row in ipairs(popup.rows) do
        local entry = entries[(page - 1) * PAGE_SIZE + i]
        row.entry = entry
        if entry then
            local character = entry.character
            row.name:SetText(character.name)
            row.favorite:SetText(character.favorite and "Unfavorite" or "Favorite")
            row.favorite:SetShown(managing)
            row.name:SetWidth(Layout(managing and 224 or 314))
            row.detail:SetWidth(Layout(managing and 224 or 314))
            for _, line in ipairs(row.favoriteBorder) do
                line:SetShown(character.favorite == true)
            end
            row.favorite:SetEnabled(not busy)
            row.note:SetShown(managing)
            row.note:SetEnabled(not busy)
            local color = C_ClassColor.GetClassColor(character.class)
            row.name:SetTextColor(color.r, color.g, color.b)
            row.detail:SetText(character.note or "")
            row.selection:SetShown(busy ~= nil and busy.id == entry.id)
            row:SetEnabled(not busy)
            row:Show()
        else
            row:Hide()
        end
    end
    popup.empty:SetText(popup.search:GetText() ~= "" and "No matching characters."
        or (managing and "No saved characters." or "No eligible alts yet. Log in on your alts first."))
    popup.empty:SetShown(#entries == 0)
    popup.page:SetText(page .. " / " .. pages)
    popup.previous:SetEnabled(page > 1 and not busy)
    popup.next:SetEnabled(page < pages and not busy)
    popup.search:SetEnabled(not busy)
    popup.clearSearch:SetEnabled(not busy)
    popup.manage:SetText(managing and "Back to recipients" or "Characters / Settings")
    local canSwitch = not managing or (SendMailFrame and SendMailFrame:IsShown()) or false
    popup.manage:SetShown(not busy and canSwitch)
    popup.manage:SetEnabled(canSwitch)
    popup.close:SetShown(not busy)
    popup.confirm:SetText(editingNote and "Save" or "Remove")
    popup.confirm:SetShown(busy ~= nil)
    popup.cancel:SetShown(busy ~= nil)
    popup.noteInput:SetShown(editingNote ~= nil)
    popup.noteLabel:SetShown(editingNote ~= nil)
    LayoutPopup(#entries, pages)
end

OpenPicker = function(manage, besideMailbox)
    CreatePopup()
    popup.visibleSlots, popup.showPagination = nil, nil
    managing, pendingDelete, editingNote, page = manage, nil, nil, 1
    positionKey = manage and not besideMailbox and "manage" or nil
    popup.search:SetText("")
    popup.search:ClearFocus()
    popup:ClearAllPoints()
    local position = BlazeMailDB.positions and BlazeMailDB.positions[positionKey]
    if position and type(position.x) == "number" and type(position.y) == "number"
        and position.x >= 0 and position.x <= 1 and position.y >= 0 and position.y <= 1 then
        popup:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            position.x * UIParent:GetWidth(), position.y * UIParent:GetHeight())
    elseif besideMailbox then
        popup:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", addon.mailWindowGap,
            addon.IsBlizzardTheme() and 0 or addon.mailWindowTopPadding)
    else
        popup:SetPoint("CENTER")
    end
    Refresh()
    popup:Show()
end

local function AttachPicker()
    addon.ApplyMailTheme()
    if MailFrame and not settingsTab then
        local function OpenSettings() OpenPicker(true, true) end
        if addon.IsBlizzardTheme() then
            settingsTab = CreateFrame("Button", "BlazeMailSettingsTab", MailFrame, "FriendsFrameTabTemplate")
            settingsTab:SetText("BlazeMail")
            PanelTemplates_DeselectTab(settingsTab)
            settingsTab:SetWidth(98)
            settingsTab:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -12, -30)
            settingsTab:SetScript("OnClick", OpenSettings)
        else
            settingsTab = Button(MailFrame, "BlazeMail", 90, 25, OpenSettings)
            settingsTab:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 256, -2)
        end
    end
    if picker or not SendMailFrame or not SendMailNameEditBox then return end
    SendMailNameEditBox:HookScript("OnTextChanged", function(_, userInput)
        if userInput then recipientRevision = recipientRevision + 1 end
    end)
    -- Observe the actual submitted name, including manually entered recipients.
    -- This post-hook does not initiate or replace mail sending.
    hooksecurefunc("SendMail", function(recipient)
        recipientRevision = recipientRevision + 1
        pendingMail = nil
        if issecretvalue and issecretvalue(recipient) then return end
        if SendMailFrame:IsShown() and type(recipient) == "string" and recipient ~= "" then
            pendingMail = { name = recipient, session = mailSession, revision = recipientRevision }
        end
    end)
    picker = Button(SendMailFrame, "v", 22, 22, function()
        if popup and popup:IsShown() then popup:Hide() else OpenPicker(false, true) end
    end)
    picker:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", 3, 0)
    picker:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("BlazeMail: Choose an alt")
        GameTooltip:Show()
    end)
    picker:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local function RefreshSettings()
        if managing and popup and popup:IsShown() then Refresh() end
    end
    SendMailFrame:HookScript("OnShow", function()
        if BlazeMailDB.openAutomatically then
            OpenPicker(false, true)
        else
            RefreshSettings()
        end
    end)
    SendMailFrame:HookScript("OnHide", function()
        if managing then
            RefreshSettings()
        elseif popup then
            popup:Hide()
        end
    end)
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("MAIL_SHOW")
eventFrame:RegisterEvent("MAIL_CLOSED")
eventFrame:RegisterEvent("MAIL_SEND_SUCCESS")
eventFrame:RegisterEvent("MAIL_FAILED")
eventFrame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        BlazeMailDB = BlazeMailDB or { characters = {} }
        BlazeMailDB.characters = BlazeMailDB.characters or {}
        BlazeMailDB.openAutomatically = BlazeMailDB.openAutomatically ~= false
        addon.InitializeTheme()
        addon.MigrateRulesets()
        SLASH_BLAZEMAIL1 = "/blazemail"
        SlashCmdList.BLAZEMAIL = function() OpenPicker(true) end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- Wait until the normal addon-loading phase has completed, so aliases
        -- registered by addons loaded after BlazeMail are included in the check.
        if event == "PLAYER_LOGIN" then RegisterShortAlias() end
        if not addon.current then addon.DiscoverCharacter() end
        AttachPicker()
    elseif event == "MAIL_SEND_SUCCESS" then
        RestoreSentRecipient()
    elseif event == "MAIL_FAILED" then
        pendingMail = nil
        recipientRevision = recipientRevision + 1
    elseif event == "MAIL_SHOW" or event == "MAIL_CLOSED" then
        pendingMail = nil
        mailSession = mailSession + 1
        if event == "MAIL_SHOW" then AttachPicker() end
    elseif event == "ADDON_LOADED" and name == "Blizzard_MailFrame" then
        AttachPicker()
    end
end)
