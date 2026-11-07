local addonName, addon = ...
local eventFrame = CreateFrame("Frame")
local popup, picker, Refresh
local page, managing, pendingDelete = 1, false, nil
local editingNote, positionKey
local pendingMail
local mailSession, recipientRevision = 0, 0
local PAGE_SIZE = 7
local fonts
local LAYOUT_SCALE = 1
local function Layout(value) return value * LAYOUT_SCALE end

local function GetFonts()
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

local function Button(parent, text, width, height, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(Layout(width), Layout(height))
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
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function EditBox(parent, width, height)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(Layout(width), Layout(height))
    box:SetAutoFocus(false)
    box:SetFontObject(GetFonts().small)
    box:SetTextInsets(Layout(6), Layout(6), Layout(2), Layout(2))
    local background = box:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.224, 0.173, 0.129, 1)
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
        if sent.session == mailSession and sent.revision == recipientRevision
            and SendMailFrame:IsShown() and SendMailNameEditBox:GetText() == "" then
            FillRecipient(sent.name)
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
    popup = CreateFrame("Frame", "BlazeMailPicker", UIParent)
    popup:SetSize(Layout(390), Layout(500))
    popup:SetFrameStrata("DIALOG")
    popup:SetClampedToScreen(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    local border = popup:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.408, 0.318, 0.227, 1)
    local background = popup:CreateTexture(nil, "BORDER")
    background:SetPoint("TOPLEFT", 1, -1)
    background:SetPoint("BOTTOMRIGHT", -1, 1)
    background:SetColorTexture(0.157, 0.125, 0.094, 1)
    popup.title = Label(popup, "BlazeMail", 12, -12, 366)
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
    popup.context = Label(popup, "", 12, -35, 366)
    popup.context:SetFontObject(GetFonts().small)
    Label(popup, "Search:", 12, -66, 54)
    popup.search = EditBox(popup, 270, 25)
    popup.search:SetPoint("TOPLEFT", Layout(68), Layout(-58))
    popup.search:SetMaxLetters(77)
    popup.clearSearch = Button(popup, "X", 32, 25, function()
        popup.search:SetText("")
        popup.search:ClearFocus()
    end)
    popup.clearSearch:SetPoint("TOPRIGHT", Layout(-12), Layout(-58))
    popup.rows = {}
    for i = 1, PAGE_SIZE do
        local row = Button(popup, "", 366, 38, function(self)
            if managing then
                pendingDelete = self.entry
                GameTooltip:Hide()
                popup.search:ClearFocus()
                Refresh()
            else
                SelectRecipient(self.entry)
            end
        end)
        row:SetPoint("TOPLEFT", Layout(12), Layout(-96 - (i - 1) * 41))
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
        row.favorite = Button(row, "Favorite", 78, 16, function()
            if not managing or pendingDelete or editingNote then return end
            GameTooltip:Hide()
            addon.ToggleFavorite(row.entry.id)
            Refresh()
        end)
        row.favorite:SetPoint("TOPRIGHT", Layout(-4), Layout(-2))
        row.favorite:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(row.entry.character.favorite and "Remove favorite" or "Add favorite")
            GameTooltip:Show()
        end)
        row.favorite:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.note = Button(row, "Note", 78, 16, function()
            if not managing or pendingDelete or editingNote then return end
            GameTooltip:Hide()
            editingNote = row.entry
            popup.search:ClearFocus()
            popup.noteInput:SetText(editingNote.character.note or "")
            Refresh()
            popup.noteInput:SetFocus()
        end)
        row.note:SetPoint("BOTTOMRIGHT", Layout(-4), Layout(2))
        for _, action in ipairs({ row.favorite, row.note }) do
            action.background:SetColorTexture(0.32, 0.245, 0.17, 1)
            for _, edge in ipairs(edges) do
                local line = action:CreateTexture(nil, "OVERLAY")
                line:SetColorTexture(0.55, 0.43, 0.29, 1)
                line:SetPoint(edge[1], action, edge[1])
                line:SetPoint(edge[2], action, edge[2])
                if edge[3] then line:SetHeight(1) else line:SetWidth(1) end
            end
        end
        row.name = Label(row, "", 8, -4, 270)
        row.detail = Label(row, "", 8, -21, 270)
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
    popup.previous:SetPoint("TOPLEFT", Layout(12), Layout(-392))
    popup.next = Button(popup, ">", 30, 22, function()
        page = page + 1
        Refresh()
    end)
    popup.next:SetPoint("TOPRIGHT", Layout(-12), Layout(-392))
    popup.page = Label(popup, "", 165, -397, 85)
    popup.noteInput = EditBox(popup, 366, 25)
    popup.noteInput:SetPoint("TOPLEFT", Layout(12), Layout(-423))
    popup.noteInput:SetMaxLetters(100)
    popup.manage = Button(popup, "Manage characters", 180, 24, function()
        managing, pendingDelete, editingNote, page = not managing, nil, nil, 1
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

Refresh = function()
    local entries = addon.GetCharacters(managing, popup.search:GetText())
    local busy = pendingDelete or editingNote
    local pages = math.max(1, math.ceil(#entries / PAGE_SIZE))
    page = math.max(1, math.min(page, pages))
    popup.title:SetText(managing and "BlazeMail - Manage characters" or "BlazeMail - Your alts")
    local current = addon.current
    popup.context:SetText(pendingDelete and ("Remove " .. pendingDelete.character.name .. "?")
        or (editingNote and ("Note for " .. editingNote.character.name))
        or (managing and "Click a character to remove it from the saved list.")
        or (current and (current.faction .. " - " .. current.ruleset) or "Character data not available yet."))
    for i, row in ipairs(popup.rows) do
        local entry = entries[(page - 1) * PAGE_SIZE + i]
        row.entry = entry
        if entry then
            local character = entry.character
            row.name:SetText(character.name)
            row.favorite:SetText(character.favorite and "Unfavorite" or "Favorite")
            row.favorite:SetShown(managing)
            row.name:SetWidth(Layout(managing and 270 or 350))
            row.detail:SetWidth(Layout(managing and 270 or 350))
            for _, line in ipairs(row.favoriteBorder) do
                line:SetShown(character.favorite == true)
            end
            row.favorite:SetEnabled(not busy)
            row.note:SetShown(managing)
            row.note:SetEnabled(not busy)
            local color = C_ClassColor.GetClassColor(character.class)
            row.name:SetTextColor(color.r, color.g, color.b)
            local scope = character.faction .. " - " .. character.ruleset
                .. (managing and (" - region " .. character.region) or "")
            row.detail:SetText(character.note and (character.note .. " | " .. scope) or scope)
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
    popup.manage:SetText(managing and "Back to recipients" or "Manage characters")
    local canSwitch = not managing or (SendMailFrame and SendMailFrame:IsShown()) or false
    popup.manage:SetShown(not busy and canSwitch)
    popup.manage:SetEnabled(canSwitch)
    popup.close:SetShown(not busy)
    popup.confirm:SetText(editingNote and "Save" or "Remove")
    popup.confirm:SetShown(busy ~= nil)
    popup.cancel:SetShown(busy ~= nil)
    popup.noteInput:SetShown(editingNote ~= nil)
end

local function OpenPicker(manage)
    CreatePopup()
    managing, pendingDelete, editingNote, page = manage, nil, nil, 1
    positionKey = manage and "manage" or nil
    popup.search:SetText("")
    popup.search:ClearFocus()
    popup:ClearAllPoints()
    local position = BlazeMailDB.positions and BlazeMailDB.positions[positionKey]
    if position and type(position.x) == "number" and type(position.y) == "number"
        and position.x >= 0 and position.x <= 1 and position.y >= 0 and position.y <= 1 then
        popup:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            position.x * UIParent:GetWidth(), position.y * UIParent:GetHeight())
    elseif not manage and picker then
        popup:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", addon.mailWindowGap, addon.mailWindowTopPadding)
    else
        popup:SetPoint("CENTER")
    end
    Refresh()
    popup:Show()
end

local function AttachPicker()
    addon.ApplyMailTheme()
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
        if popup and popup:IsShown() then popup:Hide() else OpenPicker(false) end
    end)
    picker:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", 3, 0)
    picker:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("BlazeMail: Choose an alt")
        GameTooltip:Show()
    end)
    picker:SetScript("OnLeave", function() GameTooltip:Hide() end)
    SendMailFrame:HookScript("OnHide", function() if popup then popup:Hide() end end)
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
