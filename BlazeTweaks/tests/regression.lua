-- Run from the repository root with Lua 5.1 (not loaded by the addon's TOC).
local frames, timers, now, inventory, uses, selections, addon, combat, shift, freeSlots
local gossipOptions, quests, hooks
local missingItems, loadRequests
local function NewFrame(name)
    local f = { events = {}, scripts = {}, shown = false, name = name }
    function f:RegisterEvent(event) self.events[event] = true end
    function f:UnregisterEvent(event) self.events[event] = nil end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(event, callback) self.scripts[event] = callback end
    function f:GetName() return self.name end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetText(text) self.text = text end
    function f:GetText() return self.text or "" end
    function f:GetNumLines()
        local _, lines = self:GetText():gsub("\n", "")
        return lines + 1
    end
    function f:SetChecked(value) self.checked = value end
    function f:GetChecked() return self.checked end
    function f:CreateFontString() return NewFrame() end
    function f:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
    function f:CreateTexture() return NewFrame() end
    function f:SetTexture(texture) self.texture = texture end
    function f:SetSize(width, height) self.width, self.height = width, height end
    function f:SetHeight(height) self.height = height end
    function f:GetHeight() return self.height end
    function f:SetPoint(...) self.point = { ... } end
    function f:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
    function f:SetValue(value)
        self.value = math.max(self.minimum, math.min(self.maximum, value))
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, self.value) end
    end
    function f:GetThumbTexture()
        if not self.thumb then self.thumb = NewFrame() end
        return self.thumb
    end
    function f:SetFocus() self.focused = true end
    function f:ClearFocus() self.focused = false end
    function f:SetBlinkSpeed(speed) self.blinkSpeed = speed end
    function f:Enable() self.disabled = false end
    function f:Disable() self.disabled = true end
    function f:GetVerticalScroll() return self.scroll or 0 end
    function f:GetVerticalScrollRange() return 10000 end
    function f:SetVerticalScroll(offset) self.scroll = offset end
    function f:SetOwner(owner) self.owner = owner end
    function f:SetHyperlink(link) self.link = link end
    local noop = function() end
    for _, method in ipairs({ "SetFrameStrata", "SetClampedToScreen",
        "SetMovable", "EnableMouse", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
        "SetBackdrop", "SetBackdropColor", "SetWidth", "SetMultiLine",
        "SetAutoFocus", "SetFontObject", "SetMaxLetters", "SetScrollChild",
        "SetJustifyH", "SetTextInsets", "SetNumeric", "SetWordWrap", "SetClipsChildren",
        "AddLine", "SetColorTexture", "SetOrientation", "SetValueStep", "SetThumbTexture",
        "EnableMouseWheel", "UpdateScrollChildRect", "SetBackdropBorderColor",
        "SetFont", "SetTextColor", "SetShadowOffset", "SetNormalFontObject",
        "SetHighlightFontObject", "SetDisabledFontObject", "SetNormalTexture",
        "SetPushedTexture", "SetDisabledTexture", "SetHighlightTexture",
        "SetCheckedTexture" }) do f[method] = noop end
    return f
end

local function Fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] then frame.scripts.OnEvent(frame, event, ...) end
    end
end

local function Advance(seconds)
    local target, iterations = now + seconds, 0
    while true do
        local nextIndex
        for index, timer in ipairs(timers) do
            if timer.time <= target and (not nextIndex or timer.time < timers[nextIndex].time) then
                nextIndex = index
            end
        end
        if not nextIndex then break end
        local timer = table.remove(timers, nextIndex)
        now = timer.time
        timer.callback()
        iterations = iterations + 1
        assert(iterations < 200, "unbounded timer loop")
    end
    now = target
end

local function Item(slot, id, guid, count, locked)
    inventory[slot] = { itemID = id, guid = guid, stackCount = count or 1, isLocked = locked or false }
end

local function NewAddon(charDB, sharedDB, dialogue)
    frames, timers, now, inventory, uses, selections = {}, {}, 0, {}, {}, {}
    combat, shift, freeSlots = false, false, 10
    gossipOptions, quests, hooks = {}, {}, 0
    missingItems, loadRequests = {}, {}
    BlazeTweaksCharDB, BlazeTweaksDB = charDB, sharedDB
    DUIQuestFrame = dialogue
    UIParent, ChatFontNormal, UISpecialFrames, SlashCmdList = {}, {}, {}, {}
    GameFontHighlight, GameFontHighlightSmall, GameFontDisableSmall = NewFrame(), NewFrame(), NewFrame()
    CreateFont = function() return NewFrame() end
    LootFrame = NewFrame()
    GameTooltip = NewFrame()
    MerchantFrame, BankFrame = NewFrame(), NewFrame()
    Enum = { GossipOptionStatus = { Available = 0 } }
    issecretvalue = function() return false end
    InCombatLockdown = function() return combat end
    IsShiftKeyDown = function() return shift end
    UnitName = function() return "Test" end
    GetRealmName = function() return "Realm" end
    CreateFrame = function(kind, name)
        local f = NewFrame(name)
        frames[#frames + 1] = f
        if name then _G[name] = f; _G[name .. "Text"] = NewFrame() end
        return f
    end
    hooksecurefunc = function(object, method, callback)
        local original = object[method]
        object[method] = function(...)
            local result = original(...)
            callback(...)
            return result
        end
        hooks = hooks + 1
    end
    C_Timer = { After = function(delay, callback)
        timers[#timers + 1] = { time = now + delay, callback = callback }
    end }
    ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
    C_Item = {
        GetItemGUID = function(location) return inventory[location.slot].guid end,
        GetItemInfo = function(id)
            if missingItems[id] then return nil end
            return "Item " .. id, "|Hitem:" .. id .. "|h[Item " .. id .. "]|h",
                1, 1, 1, "", "", 1, "", 134400
        end,
        RequestLoadItemDataByID = function(id) loadRequests[id] = (loadRequests[id] or 0) + 1 end,
    }
    C_Container = {
        GetContainerNumSlots = function(bag) return bag == 0 and 20 or 0 end,
        GetContainerItemInfo = function(_, slot) return inventory[slot] end,
        GetContainerNumFreeSlots = function() return freeSlots, 0 end,
        UseContainerItem = function(bag, slot)
            uses[#uses + 1] = { guid = inventory[slot].guid, time = now }
        end,
    }
    C_GossipInfo = {
        GetOptions = function() return gossipOptions end,
        GetAvailableQuests = function() return quests end,
        GetActiveQuests = function() return {} end,
        SelectOption = function(id) selections[#selections + 1] = id end,
        SelectOptionByIndex = function(id) selections[#selections + 1] = id end,
    }
    addon = {}
    for _, path in ipairs({ "Containers.lua", "Gossip.lua", "BlazeTweaks.lua" }) do
        assert(loadfile("BlazeTweaks/" .. path))("BlazeTweaks", addon)
    end
    Fire("PLAYER_LOGIN")
end

local tests = {}
function tests.item_insertion_order_survives_removal_and_reload()
    NewAddon(nil, { containerItems = { [90002] = true, [90001] = true },
        containerItemOrder = { 90002, 90002, 12345, 5523 } })
    SlashCmdList.BLAZETWEAKS()
    local ui = BlazeTweaksOptionsFrame
    assert(ui.rows[4].itemID == 90002 and ui.rows[5].itemID == 90001)
    ui.itemInput:SetText("858"); ui.addButton.scripts.OnClick()
    assert(ui.rows[6].itemID == 858, "new items must append even when their ID is lower")
    ui.rows[4].remove.scripts.OnClick()
    assert(ui.rows[4].itemID == 90001 and ui.rows[5].itemID == 858)
    ui.itemInput:SetText("90002"); ui.addButton.scripts.OnClick()
    assert(ui.rows[6].itemID == 90002, "removed and re-added items must append")
    local saved = addon.shared
    NewAddon(nil, saved)
    SlashCmdList.BLAZETWEAKS()
    ui = BlazeTweaksOptionsFrame
    assert(ui.rows[1].itemID == 5523 and ui.rows[4].itemID == 90001
        and ui.rows[5].itemID == 858 and ui.rows[6].itemID == 90002)
    NewAddon(nil, { containerItems = { [90002] = true, [90001] = true } })
    assert(addon.shared.containerItemOrder[1] == 90001 and addon.shared.containerItemOrder[2] == 90002)
end

function tests.item_feedback_expires_without_clearing_newer_messages()
    NewAddon()
    SlashCmdList.BLAZETWEAKS()
    local ui = BlazeTweaksOptionsFrame
    ui.itemInput:SetText("90001"); ui.addButton.scripts.OnClick()
    assert(ui.message:GetText() ~= "")
    Advance(2)
    ui.itemInput:SetText("90001"); ui.addButton.scripts.OnClick()
    local newerMessage = ui.message:GetText()
    Advance(3)
    assert(ui.message:GetText() == newerMessage, "old feedback timer must not clear a newer message")
    Advance(2)
    assert(ui.message:GetText() == "")
    missingItems[90002] = true
    ui.itemInput:SetText("90002"); ui.addButton.scripts.OnClick()
    Advance(5)
    assert(ui.message:GetText():find("timed out", 1, true), "lookup timeout feedback needs its own display time")
    Advance(5)
    assert(ui.message:GetText() == "")
end

function tests.defaults_and_saved_data()
    NewAddon()
    assert(BlazeTweaksCharDB.tweaks.autoOpenClams == false)
    assert(BlazeTweaksCharDB.tweaks.autoGossip == false)
    assert(addon.db.gossipTypes.bank and addon.db.gossipTypes.taxi and addon.db.gossipTypes.vendor)
    local oldHistory = { "keep legacy data" }
    NewAddon({ tweaks = { autoOpenClams = true, autoGossip = "invalid", chatCopy = true } },
        { chatHistory = oldHistory, containerItems = { [90001] = true, bad = true, [-1] = true } })
    assert(addon.db.tweaks.autoOpenClams and not addon.db.tweaks.autoGossip)
    assert(addon.shared.containerItems[90001] and not addon.shared.containerItems.bad)
    assert(addon.shared.chatHistory == oldHistory)
    NewAddon("invalid", 42)
    assert(type(addon.db) == "table" and type(addon.shared) == "table")
end

function tests.two_columns_and_conditional_scrollbar()
    local extras = {}
    for id = 90001, 90005 do extras[id] = true end
    NewAddon(nil, { containerItems = extras })
    SlashCmdList.BLAZETWEAKS()
    local ui = BlazeTweaksOptionsFrame
    assert(#ui.rows == 8 and not ui.listScrollbar:IsShown())
    assert(ui.rows[1].point[2] == 0 and ui.rows[2].point[2] > 0)
    assert(ui.rows[1].point[3] == ui.rows[2].point[3])
    assert(ui.rows[3].point[3] < ui.rows[1].point[3])
    ui.itemInput:SetText("90006"); ui.addButton.scripts.OnClick()
    assert(ui.listScrollbar:IsShown() and ui.listScrollbar.maximum > 0)
    ui.listScroll.scripts.OnMouseWheel(ui.listScroll, -1)
    assert(ui.listScroll:GetVerticalScroll() == ui.listScrollbar.maximum)
    ui.listScrollbar:SetValue(0)
    assert(ui.listScroll:GetVerticalScroll() == 0)
    ui.listScroll.scripts.OnMouseWheel(ui.listScroll, -1)
    ui.rows[9].remove.scripts.OnClick()
    assert(not ui.listScrollbar:IsShown() and ui.listScroll:GetVerticalScroll() == 0)
end

function tests.gossip_type_defaults_migration_and_live_changes()
    NewAddon({ gossipTypes = { bank = false, taxi = "invalid" } })
    assert(not addon.db.gossipTypes.bank and addon.db.gossipTypes.taxi and addon.db.gossipTypes.vendor)
    SlashCmdList.BLAZETWEAKS()
    local ui = BlazeTweaksOptionsFrame
    assert(not ui.gossipCheckboxes.bank:GetChecked() and ui.gossipCheckboxes.taxi:GetChecked())
    addon.Gossip:SetEnabled(true)
    for _, data in ipairs({ { "bank", 132050 }, { "taxi", 132057 }, { "vendor", 132060 } }) do
        local checkbox = ui.gossipCheckboxes[data[1]]
        checkbox:SetChecked(false); checkbox.scripts.OnClick(checkbox)
        gossipOptions = { { gossipOptionID = 1, icon = data[2], status = 0 } }
        local before = #selections
        Fire("GOSSIP_SHOW"); Advance(0)
        assert(#selections == before, "disabled gossip type must be skipped")
        checkbox:SetChecked(true); checkbox.scripts.OnClick(checkbox)
        Fire("GOSSIP_SHOW"); Advance(0)
        assert(#selections == before + 1)
    end
    Fire("GOSSIP_SHOW")
    ui.gossipCheckboxes.vendor:SetChecked(false)
    ui.gossipCheckboxes.vendor.scripts.OnClick(ui.gossipCheckboxes.vendor)
    local before = #selections
    Advance(0)
    assert(#selections == before, "pending callbacks must use the current type setting")
    local saved = addon.db
    NewAddon(saved)
    assert(not addon.db.gossipTypes.vendor and addon.db.gossipTypes.bank)
    assert(not addon.db.tweaks.autoGossip, "type choices must not enable the main tweak")
end

function tests.live_gui_and_global_items()
    NewAddon()
    SlashCmdList.BLAZETWEAKS()
    local ui = BlazeTweaksOptionsFrame
    local check = ui.checkboxes.autoOpenClams
    check:SetChecked(true); check.scripts.OnClick(check)
    Item(1, 5523, "new"); Fire("BAG_UPDATE_DELAYED"); Advance(0)
    assert(#uses == 1)
    check:SetChecked(false); check.scripts.OnClick(check); Advance(4)
    assert(#uses == 1)
    ui.itemInput:SetText("90001"); ui.addButton.scripts.OnClick()
    ui.itemInput:SetText("90002"); ui.itemInput.scripts.OnEnterPressed()
    assert(addon.shared.containerItems[90001] and addon.shared.containerItems[90002])
    assert(not addon.db.containerItems and not addon.shared.containerItems[5523])
    local valid = addon.shared.containerItems
    ui.itemInput:SetText("90003 invalid"); ui.addButton.scripts.OnClick()
    assert(not valid[90003], "invalid input must not partially save")
    ui.itemInput:SetText("5523"); ui.addButton.scripts.OnClick()
    assert(not valid[5523], "hardcoded items must not become custom entries")
    NewAddon(nil, { containerItems = valid })
    assert(addon.shared.containerItems[90001] and not addon.db.tweaks.autoOpenClams)
end

function tests.item_rows_tooltips_and_removal()
    NewAddon(nil, { containerItems = { [90001] = true, [90002] = true } })
    SlashCmdList.BLAZETWEAKS()
    local ui = BlazeTweaksOptionsFrame
    assert(#ui.rows == 5)
    local fixed, custom = ui.rows[1], ui.rows[4]
    assert(fixed.itemID == 5523 and not fixed.remove:IsShown())
    assert(custom.itemID == 90001 and custom.remove:IsShown())
    custom.scripts.OnEnter(custom)
    assert(GameTooltip.owner == custom and GameTooltip.link:find("item:90001", 1, true))
    assert(custom.icon.texture == 134400 and custom.name.text:find("Item 90001", 1, true))
    custom.remove.scripts.OnClick()
    assert(not addon.shared.containerItems[90001] and addon.shared.containerItems[90002])
    assert(ui.rows[4].itemID == 90002 and not ui.rows[5]:IsShown())
    fixed.remove.scripts.OnClick()
    assert(addon.Containers.defaults[5523], "standard item removal must be guarded")
    ui.itemInput.scripts.OnMouseDown(ui.itemInput)
    assert(ui.itemInput.focused and ui.itemInput.blinkSpeed > 0)
end

function tests.uncached_item_validation_and_timeout()
    NewAddon()
    SlashCmdList.BLAZETWEAKS()
    local ui = BlazeTweaksOptionsFrame
    missingItems[90001] = true
    ui.itemInput:SetText("90001"); ui.addButton.scripts.OnClick()
    assert(loadRequests[90001] == 1 and not addon.shared.containerItems[90001])
    ui.addButton.scripts.OnClick()
    assert(loadRequests[90001] == 1, "a pending request must not be duplicated")
    missingItems[90001] = nil
    Fire("ITEM_DATA_LOAD_RESULT", 90001, true)
    assert(addon.shared.containerItems[90001] and ui.itemInput:GetText() == "")
    missingItems[90002] = true
    ui.itemInput:SetText("90002"); ui.addButton.scripts.OnClick()
    Fire("ITEM_DATA_LOAD_RESULT", 90002, false)
    assert(not addon.shared.containerItems[90002] and not ui.addButton.disabled)
    missingItems[90003] = true
    ui.itemInput:SetText("90003"); ui.addButton.scripts.OnClick()
    Advance(5)
    assert(not addon.shared.containerItems[90003] and not ui.addButton.disabled)
    missingItems[90003] = nil
    Fire("ITEM_DATA_LOAD_RESULT", 90003, true)
    assert(not addon.shared.containerItems[90003], "late results must not save a timed-out request")
end

function tests.saved_item_data_loads_and_hidden_input_stays_unfocused()
    NewAddon(nil, { containerItems = { [90001] = true } })
    missingItems[90001] = true
    SlashCmdList.BLAZETWEAKS()
    local ui = BlazeTweaksOptionsFrame
    assert(ui.rows[4].name.text == "Loading item...")
    missingItems[90001] = nil; Fire("ITEM_DATA_LOAD_RESULT", 90001, true)
    assert(ui.rows[4].name.text:find("Item 90001", 1, true))
    missingItems[90002] = true
    ui.itemInput:SetText("90002"); ui.addButton.scripts.OnClick()
    ui:Hide(); ui.scripts.OnHide()
    missingItems[90002] = nil; Fire("ITEM_DATA_LOAD_RESULT", 90002, true)
    assert(addon.shared.containerItems[90002] and not ui.itemInput.focused)
end

function tests.baseline_and_moving_items()
    NewAddon()
    Item(1, 5523, "old")
    addon.Containers:SetEnabled(true)
    inventory[2], inventory[1] = inventory[1], nil
    Fire("BAG_UPDATE_DELAYED"); Advance(0)
    assert(#uses == 0)
    Item(3, 5523, "new"); Fire("BAG_UPDATE_DELAYED"); Advance(0)
    assert(#uses == 1 and uses[1].guid == "new")
end

function tests.bounded_retries_and_disable()
    NewAddon()
    addon.Containers:SetEnabled(true)
    Item(1, 5523, "new"); Fire("BAG_UPDATE_DELAYED"); Advance(5)
    assert(#uses == 3, "failed opening must retry exactly three times")
    Fire("BAG_UPDATE_DELAYED"); Advance(5)
    assert(#uses == 3, "ordinary events must not restart exhausted retries")
    NewAddon()
    addon.Containers:SetEnabled(true)
    Item(1, 5523, "new"); Fire("BAG_UPDATE_DELAYED")
    addon.Containers:SetEnabled(false)
    addon.Containers:SetEnabled(true)
    Advance(5)
    assert(#uses == 0, "callbacks from the old generation must be inert")
end

function tests.loot_queue_and_stale_timeout()
    NewAddon()
    addon.Containers:SetEnabled(true)
    Item(1, 5523, "first"); Fire("BAG_UPDATE_DELAYED"); Advance(0)
    Fire("LOOT_OPENED", true, true)
    inventory[1] = nil
    Item(2, 5523, "second") -- Same total, but first was consumed by our attempt.
    Fire("BAG_UPDATE_DELAYED"); Advance(0.2)
    assert(#uses == 1)
    Fire("LOOT_CLOSED"); Advance(0)
    assert(#uses == 2 and uses[2].guid == "second")
    Advance(0.8) -- First timeout fires, second attempt must remain intact.
    assert(#uses == 2)
    Fire("BAG_UPDATE_DELAYED"); Advance(0)
    assert(#uses == 2)
end

function tests.locks_combat_space_and_custom_items()
    NewAddon(nil, { containerItems = { [90001] = true } })
    addon.Containers:SetEnabled(true)
    combat = true
    Item(1, 90001, "custom", 1, true)
    Fire("BAG_UPDATE_DELAYED"); Advance(0)
    assert(#uses == 0)
    combat = false; Fire("PLAYER_REGEN_ENABLED"); Advance(0)
    assert(#uses == 0)
    inventory[1].isLocked = false; freeSlots = 0
    Fire("ITEM_LOCK_CHANGED", 0, 1); Advance(0)
    assert(#uses == 0)
    freeSlots = 1; Fire("BAG_UPDATE_DELAYED"); Advance(0)
    assert(#uses == 1)
end

function tests.late_bag_update_after_long_loot_window()
    NewAddon()
    addon.Containers:SetEnabled(true)
    Item(1, 5523, "first"); Fire("BAG_UPDATE_DELAYED"); Advance(0)
    Fire("LOOT_OPENED", true, true); Advance(2)
    Fire("LOOT_CLOSED") -- Consumption isn't visible yet.
    Advance(0.1)
    inventory[1] = nil
    Item(2, 5523, "second")
    Fire("BAG_UPDATE_DELAYED"); Advance(0.4)
    assert(#uses == 2 and uses[2].guid == "second", "late inventory update must not stall the queue")
end

function tests.new_units_in_an_existing_stack()
    NewAddon()
    Item(1, 5523, "stack", 2)
    addon.Containers:SetEnabled(true)
    inventory[1].stackCount = 4
    Fire("BAG_UPDATE_DELAYED"); Advance(0)
    assert(#uses == 1)
    inventory[1].stackCount = 3
    Fire("BAG_UPDATE_DELAYED"); Advance(1.3)
    assert(#uses == 2)
    inventory[1].stackCount = 2
    Fire("BAG_UPDATE_DELAYED"); Advance(3)
    assert(#uses == 2, "units present before enabling must remain unopened")
end

function tests.queued_stack_merge()
    NewAddon()
    Item(1, 5523, "old", 2)
    addon.Containers:SetEnabled(true)
    freeSlots = 0
    Item(2, 5523, "queued", 2)
    Fire("BAG_UPDATE_DELAYED"); Advance(0)
    inventory[1].stackCount = 4; inventory[2] = nil
    Fire("BAG_UPDATE_DELAYED"); Advance(0)
    freeSlots = 1
    Fire("BAG_UPDATE_DELAYED"); Advance(0)
    assert(#uses == 1 and uses[1].guid == "old", "queued units must survive merging")
    inventory[1].stackCount = 3; Fire("BAG_UPDATE_DELAYED"); Advance(1.3)
    assert(#uses == 2)
    inventory[1].stackCount = 2; Fire("BAG_UPDATE_DELAYED"); Advance(3)
    assert(#uses == 2, "merging must not queue existing baseline units")
end

function tests.merchant_and_bank_pause()
    for _, events in ipairs({ { "MERCHANT_SHOW", "MERCHANT_CLOSED" },
        { "BANKFRAME_OPENED", "BANKFRAME_CLOSED" } }) do
        NewAddon()
        addon.Containers:SetEnabled(true)
        Fire(events[1])
        Item(1, 5523, "new"); Fire("BAG_UPDATE_DELAYED"); Advance(2)
        assert(#uses == 0, "must not use items at a merchant or bank")
        Fire(events[2]); Advance(0)
        assert(#uses == 1)
    end
    NewAddon()
    MerchantFrame:Show() -- Enabling during an existing merchant interaction.
    addon.Containers:SetEnabled(true)
    Item(1, 5523, "new"); Fire("BAG_UPDATE_DELAYED"); Advance(1)
    assert(#uses == 0)
    MerchantFrame:Hide(); Fire("MERCHANT_CLOSED"); Advance(0)
    assert(#uses == 1)
end

function tests.disabled_gossip_ignores_dialogue_hooks()
    local dialogue = { HandleGossip = function() end, ShowUI = function() end }
    NewAddon(nil, nil, dialogue)
    addon.Gossip:SetEnabled(true)
    gossipOptions = { { gossipOptionID = 1, icon = 132050, status = 0, orderIndex = 1 } }
    Fire("GOSSIP_SHOW")
    addon.Gossip:SetEnabled(false)
    dialogue:ShowUI("GOSSIP_SHOW"); dialogue:HandleGossip(); Advance(1)
    assert(#selections == 0)
end

local function GossipPage(id)
    gossipOptions = { { gossipOptionID = id, icon = 132050, status = 0, orderIndex = 1 } }
    Fire("GOSSIP_SHOW")
end

function tests.gossip_filters_and_live_disable()
    NewAddon()
    addon.Gossip:SetEnabled(true)
    shift = true; GossipPage(1); shift = false; Advance(0)
    assert(#selections == 0, "Shift at interaction start must be remembered")
    GossipPage(2); gossipOptions[1].status = 2; Advance(0)
    assert(#selections == 0)
    GossipPage(3); quests = { {} }; Advance(0)
    assert(#selections == 0)
    quests = {}; GossipPage(4); Advance(0)
    assert(#selections == 1 and selections[1] == 4)
    GossipPage(5); addon.Gossip:SetEnabled(false); Advance(0)
    assert(#selections == 1)
    addon.Gossip:SetEnabled(true); GossipPage(6); Fire("GOSSIP_CLOSED"); Advance(0)
    assert(#selections == 1)
end

function tests.dialogue_loading_and_visible_page_updates()
    local dialogue = { isGameLoading = true }
    function dialogue:HandleGossip() self.handler = "HandleGossip" end
    function dialogue:ShowUI(event)
        if self.isGameLoading then self.deferredEvent = event; return end
        self:HandleGossip()
    end
    NewAddon(nil, nil, dialogue)
    addon.Gossip:SetEnabled(true)
    GossipPage(1); dialogue:ShowUI("GOSSIP_SHOW"); Advance(4)
    assert(#selections == 0)
    dialogue.isGameLoading = nil
    dialogue:ShowUI(dialogue.deferredEvent); Advance(0)
    assert(#selections == 1)
    GossipPage(2); dialogue:ShowUI("GOSSIP_SHOW"); Advance(0)
    assert(#selections == 2 and selections[2] == 2)
    addon.Gossip:SetEnabled(false); addon.Gossip:SetEnabled(true)
    assert(hooks == 2, "re-enabling must not accumulate post-hooks")
end

local count = 0
for name, test in pairs(tests) do
    test()
    count = count + 1
    print("PASS " .. name)
end
print("Passed " .. count .. " regression scenarios (mock WoW API, Lua 5.1).")
