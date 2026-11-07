-- Run from the repository root with Lua 5.1; not loaded by the addon.
local addon, frames = {}, {}
local player = { first = "Ada", surname = "Ember", guid = "Player-A",
    class = "MAGE", faction = "Alliance", region = 3, ruleset = "PvE" }
local secret
issecretvalue = function(value) return rawequal(value, secret) and secret ~= nil end
UnitNameUnmodified = function() return player.first, player.surname end
UnitGUID = function() return player.guid end
UnitClass = function() return "Mage", player.class end
UnitFactionGroup = function() return player.faction end
GetCurrentRegion = function() return player.region end
GetRealmName = function() return player.ruleset end
C_ClassColor = { GetClassColor = function() return { r = 0.25, g = 0.78, b = 0.92 } end }
BlazeMailDB = { characters = {} }
SlashCmdList, UISpecialFrames = {}, {}
local timers = {}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
local sendHooks = {}
local themeHooks = {}
hooksecurefunc = function(name, callback)
    if name == "SendMail" then
        sendHooks[#sendHooks + 1] = callback
    else
        assert(name == "MailFrameTab_OnClick")
        themeHooks[#themeHooks + 1] = callback
    end
end
local function Send(recipient)
    for _, callback in ipairs(sendHooks) do callback(recipient) end
end
local function RunTimers()
    local callbacks = timers
    timers = {}
    for _, callback in ipairs(callbacks) do callback() end
end

local function Frame(name, parent)
    local f = { name = name, parent = parent, shown = true, scripts = {}, hooks = {}, children = {} }
    frames[#frames + 1] = f
    if name then _G[name] = f end
    if parent then parent.children[#parent.children + 1] = f end
    function f:SetScript(event, callback) self.scripts[event] = callback end
    function f:GetScript(event) return self.scripts[event] end
    function f:HookScript(event, callback) self.hooks[event] = callback end
    function f:RegisterEvent(event) self[event] = true end
    function f:Show() self.shown = true end
    function f:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
        if wasShown and self.hooks.OnHide then self.hooks.OnHide(self) end
    end
    function f:SetShown(value) if value then self:Show() else self:Hide() end end
    function f:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
    function f:SetText(text)
        self.text = text
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
    end
    function f:GetText() return self.text or "" end
    function f:IsObjectType(kind) return self.kind == kind end
    function f:GetRegions()
        local regions = {}
        for _, child in ipairs(self.children) do
            if child.kind == "Texture" or child.kind == "FontString" then
                regions[#regions + 1] = child
            end
        end
        return unpack(regions)
    end
    function f:SetFont(file, size, flags) self.font = { file, size, flags } end
    function f:SetNormalTexture(texture) self.normalTexture = texture end
    function f:SetPushedTexture(texture) self.pushedTexture = texture end
    function f:SetDisabledTexture(texture) self.disabledTexture = texture end
    function f:SetCursorPosition(position) self.cursor = position end
    function f:SetTextColor(r, g, b) self.color = { r, g, b } end
    function f:GetTextColor() return unpack(self.color or { 1, 1, 1 }) end
    function f:SetEnabled(value) self.enabled = not not value end
    function f:ClearFocus() self.focused = false end
    function f:SetFocus() self.focused = true end
    function f:GetCenter() return self.centerX or 960, self.centerY or 540 end
    function f:GetWidth() return 1920 end
    function f:GetHeight() return 1080 end
    function f:CreateFontString()
        local region = Frame(nil, self)
        region.kind = "FontString"
        return region
    end
    function f:CreateTexture()
        local region = Frame(nil, self)
        region.kind = "Texture"
        return region
    end
    function f:SetPoint(...) self.point = { ... } end
    local noop = function() end
    for _, method in ipairs({ "SetSize", "SetWidth", "SetJustifyH", "SetAllPoints", "SetHitRectInsets",
        "SetColorTexture", "SetHighlightTexture", "SetNormalFontObject", "SetHighlightFontObject",
        "SetDisabledFontObject", "SetFrameStrata",
        "SetClampedToScreen", "EnableMouse", "SetFontObject", "ClearAllPoints", "SetOwner", "SetWordWrap",
        "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetHeight" }) do
        f[method] = noop
    end
    for _, method in ipairs({ "SetAutoFocus", "SetTextInsets", "SetMaxLetters" }) do f[method] = noop end
    return f
end
CreateFrame = function(_, name, parent) return Frame(name, parent) end
CreateFont = function(name)
    local font = {}
    function font:SetFontObject(base) self.base = base end
    function font:SetFont(file, size, flags) self.file, self.size, self.flags = file, size, flags end
    function font:GetFont() return self.file, self.size, self.flags end
    function font:SetTextColor(r, g, b) self.color = { r, g, b } end
    function font:SetShadowOffset() end
    _G[name] = font
    return font
end
GameFontHighlight = CreateFont("GameFontHighlight")
GameFontHighlight:SetFont("Fonts\\test.ttf", 12, "")
GameFontHighlightSmall = CreateFont("GameFontHighlightSmall")
GameFontHighlightSmall:SetFont("Fonts\\test.ttf", 10, "")
GameFontDisableSmall = CreateFont("GameFontDisableSmall")
GameFontDisableSmall:SetFont("Fonts\\test.ttf", 10, "")
UIParent = Frame("UIParent")
GameTooltip = Frame("GameTooltip")
assert(loadfile("BlazeMail/Characters.lua"))("BlazeMail", addon)
assert(loadfile("BlazeMail/MailTheme.lua"))("BlazeMail", addon)
assert(loadfile("BlazeMail/BlazeMail.lua"))("BlazeMail", addon)
local events = frames[#frames]
local function Event(event, name) events.scripts.OnEvent(events, event, name) end
local function Click(button)
    assert(button:IsShown() and button.enabled ~= false, "button unavailable: " .. tostring(button.text))
    button.scripts.OnClick(button)
end
local function FindButton(text)
    for _, f in ipairs(frames) do
        if f.text == text and f.scripts.OnClick and f:IsShown() then return f end
    end
    error("missing visible button: " .. text)
end
local function Register(guid, first, faction, ruleset, region)
    player.guid, player.first = guid, first
    player.faction, player.ruleset, player.region = faction or "Alliance", ruleset or "PvE", region or 3
    assert(addon.DiscoverCharacter())
end

Event("ADDON_LOADED", "BlazeMail")
assert(addon.NormalizeRuleset("CAMWOW EU4 Realm 7 PvE") == "PvE", "reported client format")
assert(addon.NormalizeRuleset("CAMWOW EU4 Realm 12 PvE") == "PvE", "ignore connection number")
assert(addon.NormalizeRuleset("CAMWOW EU4 Realm 7 PvP") == "PvP")
assert(addon.NormalizeRuleset("CAMWOW EU4 Realm 7 Roleplay") == "Roleplay")
assert(addon.NormalizeRuleset("CAMWOW EU4 Realm 7 PvP Roleplay") == "PvP Roleplay")
assert(not addon.NormalizeRuleset("CAMWOW EU4 Realm 7"), "unknown ruleset is not guessed")
assert(not SLASH_BLAZEMAIL2, "defer optional alias until login")
local otherHandler = function() end
SlashCmdList.OTHER = otherHandler
SLASH_OTHER1, SLASH_OTHER2 = "/other", "/bM"
Event("PLAYER_LOGIN")
assert(not SLASH_BLAZEMAIL2, "existing alias is respected case-insensitively")
assert(SlashCmdList.OTHER == otherHandler and SLASH_OTHER2 == "/bM", "existing command untouched")
SlashCmdList.OTHER, SLASH_OTHER1, SLASH_OTHER2 = nil, nil, nil
hash_SlashCmdList = { ["/BM"] = otherHandler }
Event("PLAYER_LOGIN")
assert(not SLASH_BLAZEMAIL2 and hash_SlashCmdList["/BM"] == otherHandler, "cached command preserved")
hash_SlashCmdList = {}
IsSecureCmd = function(command) return command == "/BM" end
Event("PLAYER_LOGIN")
assert(not SLASH_BLAZEMAIL2, "secure command preserved")
IsSecureCmd = nil
hash_ChatTypeInfoList = { ["/BM"] = "OTHER" }
Event("PLAYER_LOGIN")
assert(not SLASH_BLAZEMAIL2, "chat command preserved")
hash_ChatTypeInfoList = nil
hash_EmoteTokenList = { ["/BM"] = "OTHER" }
Event("PLAYER_LOGIN")
assert(not SLASH_BLAZEMAIL2, "emote preserved")
hash_EmoteTokenList = nil
Event("PLAYER_LOGIN")
assert(SLASH_BLAZEMAIL2 == "/bm" and SLASH_BLAZEMAIL1 == "/blazemail", "free alias registered")
assert(BlazeMailDB.characters["Player-A"].name == "Ada Ember")
Register("Player-B", "Bea")
Register("Player-H", "HordeAlt", "Horde")
Register("Player-P", "PvPAlt", "Alliance", "PvP")
Register("Player-R", "RegionAlt", "Alliance", "PvE", 1)
Register("Player-A", "Ada")
local eligible = addon.GetCharacters(false)
assert(#eligible == 1 and eligible[1].id == "Player-B", "filter faction/ruleset/region/self")
assert(#addon.GetCharacters(true) == 5, "management includes both factions and all scopes")
assert(#addon.GetCharacters(false, " eMb ") == 1, "trimmed case-insensitive surname search")
assert(#addon.GetCharacters(false, "PvPAlt") == 0, "search cannot reveal another ruleset")
assert(#addon.GetCharacters(true, "a.") == 0, "search uses plain text, not patterns")
addon.ToggleFavorite("Player-B")
addon.SetNote("Player-B", "  Bank  ")
Register("Player-B", "Bea")
assert(addon.current.favorite and addon.current.note == "Bank", "rediscovery preserves user metadata")
local grouped = addon.GetCharacters(true)
local aIndex, bIndex
for index, entry in ipairs(grouped) do
    if entry.id == "Player-A" then aIndex = index end
    if entry.id == "Player-B" then bIndex = index end
end
assert(bIndex < aIndex, "favorite before alphabetical names within group")
addon.ToggleFavorite("Player-B")
addon.SetNote("Player-B", " ")
assert(not addon.current.favorite and not addon.current.note, "favorite and note can be cleared")
Register("Player-A", "Ada")

-- Migrate existing raw connection names without losing characters or scopes.
BlazeMailDB.characters["Player-B"].ruleset = "CAMWOW EU4 Realm 12 PvE"
BlazeMailDB.characters["Player-P"].ruleset = "CAMWOW EU4 Realm 7 PvP"
Event("ADDON_LOADED", "BlazeMail")
assert(BlazeMailDB.characters["Player-B"].ruleset == "PvE")
assert(BlazeMailDB.characters["Player-P"].ruleset == "PvP")
player.ruleset = "CAMWOW EU4 Realm 7 PvE"
assert(addon.DiscoverCharacter() and addon.current.ruleset == "PvE")
eligible = addon.GetCharacters(false)
assert(#eligible == 1 and eligible[1].id == "Player-B", "same ruleset across numbered connections")
assert(#addon.GetCharacters(true) == 5, "migration preserves records")
player.ruleset = "PvE"

player.first = "Ada-Ember"
assert(addon.DiscoverCharacter() and addon.current.name == "Ada Ember", "normalize joined name")
player.first = "Ada Ember"
assert(addon.DiscoverCharacter() and addon.current.name == "Ada Ember", "avoid duplicate surname")
player.first, player.surname = "Ada", nil
assert(addon.DiscoverCharacter() and addon.current.name == "Ada", "missing surname")
player.surname = "Ember"
assert(addon.DiscoverCharacter())
player.ruleset = ""
assert(not addon.DiscoverCharacter(), "do not discover unknown scope")
player.ruleset = "PvE"
secret = setmetatable({}, { __eq = function() error("inspected secret") end,
    __concat = function() error("concatenated secret") end })
player.first = secret
assert(not addon.DiscoverCharacter(), "reject secret identity before comparisons")
player.first, secret = "Ada", nil

-- Blizzard_MailFrame loads after this addon; installing the picker is idempotent.
SendMailFrame = Frame("SendMailFrame", UIParent)
SendMailNameEditBox = Frame("SendMailNameEditBox", SendMailFrame)
Event("ADDON_LOADED", "Blizzard_MailFrame")
local picker = FindButton("v")
local frameCount = #frames
Event("MAIL_SHOW")
Event("MAIL_SHOW")
assert(#frames == frameCount, "no duplicate picker on mailbox reopen")
Click(picker)
local popup = BlazeMailPicker
assert(popup:IsShown() and popup.rows[1].name.text == "Bea Ember")
popup.search:SetText("does not exist")
assert(popup.empty:IsShown() and not popup.rows[1]:IsShown(), "empty search results")
Click(popup.clearSearch)
assert(popup.rows[1]:IsShown(), "clear restores recipients")
assert(popup.rows[1].name.color[1] == 0.25, "class color applied")
Click(popup.rows[1])
assert(SendMailNameEditBox.text == "Bea Ember" and not popup:IsShown(), "recipient selection")
assert(SendMailNameEditBox.cursor == 0, "show first name after choosing recipient")
Send("Bea Ember")
Event("MAIL_SEND_SUCCESS")
SendMailNameEditBox:SetText("") -- Blizzard's handler runs after ours.
RunTimers()
assert(SendMailNameEditBox.text == "Bea Ember" and SendMailNameEditBox.cursor == 0,
    "successful mail restores recipient and shows start of name")
Send("Typed Recipient")
SendMailNameEditBox:SetText("") -- Blizzard's handler runs before ours.
Event("MAIL_SEND_SUCCESS")
RunTimers()
assert(SendMailNameEditBox.text == "Typed Recipient", "typed recipients also restored")
Send("Typed Recipient")
Event("MAIL_FAILED")
SendMailNameEditBox:SetText("")
Event("MAIL_SEND_SUCCESS")
RunTimers()
assert(SendMailNameEditBox.text == "", "failure invalidates remembered submission")
Send("Old Recipient")
Event("MAIL_SEND_SUCCESS")
SendMailNameEditBox:SetText("")
Click(picker)
Click(popup.rows[1])
RunTimers()
assert(SendMailNameEditBox.text == "Bea Ember", "new selection wins over scheduled restore")
Send("Old Recipient")
Event("MAIL_SEND_SUCCESS")
SendMailNameEditBox:SetText("")
SendMailNameEditBox.hooks.OnTextChanged(SendMailNameEditBox, true)
RunTimers()
assert(SendMailNameEditBox.text == "", "intentional user clearing is respected")
Send("Old Recipient")
Event("MAIL_SEND_SUCCESS")
Event("MAIL_CLOSED")
Event("MAIL_SHOW")
SendMailNameEditBox:SetText("")
RunTimers()
assert(SendMailNameEditBox.text == "", "closed mailbox invalidates queued restore")

Click(picker)
player.faction = "Horde"
assert(addon.DiscoverCharacter())
Click(popup.rows[1])
assert(popup:IsShown(), "stale row cannot cross faction")
player.faction = "Alliance"
assert(addon.DiscoverCharacter())
popup:Hide()
SlashCmdList.BLAZEMAIL()
assert(popup:IsShown())
local removed = popup.rows[1].entry.id
Click(popup.rows[1])
assert(BlazeMailDB.characters[removed], "deletion requires confirmation")
assert(popup.rows[1].selection:IsShown() and not popup.rows[2].selection:IsShown(), "persistent deletion selection")
Click(popup.cancel)
assert(BlazeMailDB.characters[removed], "cancel preserves character")
assert(not popup.rows[1].selection:IsShown(), "cancel clears selection")
Click(popup.rows[1].note)
popup.noteInput:SetText("Alchemy")
Click(popup.cancel)
assert(not BlazeMailDB.characters[removed].note, "cancel discards note edits")
Click(popup.rows[1].note)
popup.noteInput:SetText("Bank")
popup.noteInput.scripts.OnEnterPressed()
assert(BlazeMailDB.characters[removed].note == "Bank", "Enter saves note")
assert(popup.rows[1].detail.text:find("Bank", 1, true), "saved note displayed beneath name")
Click(popup.rows[1])
assert(not popup.close:IsShown(), "confirmation buttons do not overlap Close")
Click(popup.confirm)
assert(not BlazeMailDB.characters[removed], "confirmed removal")
Event("PLAYER_ENTERING_WORLD")
assert(not BlazeMailDB.characters[removed], "zone events do not restore removed current character")

-- Account-wide entries survive loading a fresh addon namespace on another alt.
local nextSession = {}
assert(loadfile("BlazeMail/Characters.lua"))("BlazeMail", nextSession)
assert(#nextSession.GetCharacters(true) == 4)
assert(nextSession.DiscoverCharacter())
assert(BlazeMailDB.characters["Player-A"], "login restores removed current character")

for i = 1, 10 do Register("Player-Extra" .. i, "Extra" .. i) end
Register("Player-A", "Ada")
popup:Hide()
Click(picker)
assert(popup.page.text == "1 / 2")
Click(popup.next)
assert(popup.page.text == "2 / 2" and not popup.next.enabled, "pagination boundary")
SendMailFrame:Hide()
assert(not popup:IsShown(), "hide recipient picker with Send Mail")
SlashCmdList.BLAZEMAIL()
assert(popup:IsShown() and not popup.manage.enabled, "management works outside mailbox")
local titleBar
for _, child in ipairs(popup.children) do
    if child.scripts.OnDragStart then titleBar = child end
end
titleBar.scripts.OnDragStart()
popup.centerX, popup.centerY = 480, 810
titleBar.scripts.OnDragStop()
assert(BlazeMailDB.positions.manage.x == 0.25 and BlazeMailDB.positions.manage.y == 0.75)
popup:Hide()
SlashCmdList.BLAZEMAIL()
assert(popup.point[1] == "CENTER" and popup.point[4] == 480 and popup.point[5] == 810,
    "reopen restores saved position")
popup:Hide()
-- Reconstruct the UI with the same SavedVariables to simulate a fresh session.
assert(loadfile("BlazeMail/MailTheme.lua"))("BlazeMail", nextSession)
assert(loadfile("BlazeMail/BlazeMail.lua"))("BlazeMail", nextSession)
local nextEvents = frames[#frames]
nextEvents.scripts.OnEvent(nextEvents, "ADDON_LOADED", "BlazeMail")
SlashCmdList.BLAZEMAIL()
assert(BlazeMailPicker.point[4] == 480 and BlazeMailPicker.point[5] == 810,
    "fresh UI restores account-wide position")

-- Theme representative Blizzard frames without touching mail actions or icons.
MailFrame = Frame("MailFrame", UIParent)
MailFrame.NineSlice = Frame(nil, MailFrame)
MailFrame.PortraitContainer = Frame(nil, MailFrame)
MailFrame.Inset = Frame(nil, MailFrame)
MailFrame.TitleContainer = Frame(nil, MailFrame)
MailFrame.TitleContainer.TitleText = MailFrame.TitleContainer:CreateFontString()
local originalBackground = MailFrame:CreateTexture()
InboxFrame = Frame("InboxFrame", MailFrame)
MailFrameTab1, MailFrameTab2 = Frame("MailFrameTab1", MailFrame), Frame("MailFrameTab2", MailFrame)
local tabArt = MailFrameTab1:CreateTexture()
MailItem1 = Frame("MailItem1", InboxFrame)
MailItem1Sender = MailItem1:CreateFontString()
MailItem1Subject = MailItem1:CreateFontString()
MailItem1Sender:SetTextColor(1, 0.82, 0)
local itemButton = Frame("MailItem1Button", MailItem1)
local icon = itemButton:CreateTexture()
local clickHandler = function() end
itemButton:SetScript("OnClick", clickHandler)
SendMailMoneyGold = Frame("SendMailMoneyGold", SendMailFrame)
local coin = SendMailMoneyGold:CreateTexture()
SendMailMailButton = Frame("SendMailMailButton", SendMailFrame)
SendMailMailButton:SetScript("OnClick", clickHandler)
SendMailErrorText = SendMailFrame:CreateFontString()
SendMailErrorText:SetTextColor(1, 0, 0)
nextSession.ApplyMailTheme()
assert(not originalBackground:IsShown() and not MailFrame.NineSlice:IsShown(), "old frame art hidden")
assert(MailFrame.TitleContainer.TitleText.font[2] == 13 and MailItem1Subject.font[2] == 11)
assert(MailItem1Sender.color[1] == 1 and MailItem1Sender.color[2] == 0.82, "unread color preserved")
assert(SendMailErrorText.color[1] == 1 and SendMailErrorText.color[2] == 0, "warning color preserved")
assert(icon.shown and coin.shown, "item and denomination icons preserved")
assert(itemButton.scripts.OnClick == clickHandler and SendMailMailButton.scripts.OnClick == clickHandler,
    "Blizzard click handlers preserved")
local themedCount = #frames
nextSession.ApplyMailTheme()
assert(#frames == themedCount and #themeHooks == 1, "theme application is idempotent")
tabArt:Show()
themeHooks[1]()
assert(not tabArt:IsShown(), "tab changes do not restore old tab art")
print("BlazeMail: all regression checks passed (Lua " .. _VERSION .. ")")
