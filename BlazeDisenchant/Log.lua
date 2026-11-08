local addonName, addon = ...
local frame = CreateFrame("Frame")
local attempt
local lastStatus = "No cast seen this session."
local _, build = GetBuildInfo()

local function finish(reason)
    lastStatus = reason
    attempt = nil
    addon.refreshLog()
end

-- Remember the physical copy while locked. Identical items have different GUIDs.
local function inspectSlot(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or issecretvalue(info.isLocked) or not info.isLocked then return end
    local link = info.hyperlink
    if issecretvalue(link) or not link then return end
    local id, _, _, _, _, class = C_Item.GetItemInfoInstant(link)
    if issecretvalue(id) or not id or not addon.eligible(class, info.quality) then return end
    local guid = C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag, slot))
    local level = C_Item.GetDetailedItemLevelInfo(link)
    if issecretvalue(guid) or not guid or issecretvalue(level) or not level then return end
    if attempt.source and attempt.source.guid ~= guid then attempt.ambiguous = true end
    attempt.source = { guid = guid, itemID = id, link = link, level = level,
        class = class, quality = info.quality, bag = bag, slot = slot }
end

local function beginCast(guid)
    attempt = { cast = guid }
    lastStatus = "Disenchant cast detected."
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do inspectSlot(bag, slot) end
    end
    local current = attempt
    C_Timer.After(12, function()
        if current == attempt and not current.opened then finish("Skipped: no confirmed item loot window.") end
    end)
end

local function readLoot()
    local result = {}
    local slots = GetNumLootItems()
    if issecretvalue(slots) or not slots or slots < 1 then return end
    for slot = 1, slots do
        local link = GetLootSlotLink(slot)
        local _, _, count = GetLootSlotInfo(slot)
        if issecretvalue(link) or not link or issecretvalue(count) or not count or count < 1 then return end
        local id = C_Item.GetItemInfoInstant(link)
        if issecretvalue(id) or not id then return end
        result[id] = (result[id] or 0) + count
    end
    return result
end

local function verify(current, retry)
    if attempt ~= current then return end
    local source = current.source
    if not source or current.ambiguous then return finish("Skipped: no unique locked source.") end
    if not current.success then return finish("Skipped: cast success not seen.") end
    if not current.opened then return finish("Skipped: loot window did not open.") end
    if not current.materials then return finish("Skipped: loot slots unreadable.") end
    local present = C_Item.IsItemGUIDInInventory(source.guid)
    if issecretvalue(present) or present ~= false then
        if retry then
            C_Timer.After(0.75, function() verify(current, false) end)
            return
        end
        return finish("Skipped: source consumption unconfirmed.")
    end
    local log = BlazeDisenchantDB.attempts
    log[#log + 1] = { time = GetServerTime(), build = build, itemID = source.itemID,
        link = source.link, itemLevel = source.level, classID = source.class,
        quality = source.quality, bag = source.bag, slot = source.slot, materials = current.materials }
    finish("Recorded #" .. #log .. ".")
end

frame:SetScript("OnEvent", function(_, event, first, second, third, fourth)
    if event == "ADDON_LOADED" then
        if first == addonName then
            BlazeDisenchantDB = BlazeDisenchantDB or {}
            BlazeDisenchantDB.attempts = BlazeDisenchantDB.attempts or {}
            frame:UnregisterEvent(event)
        end
    elseif event:match("^UNIT_SPELLCAST_") then
        local sent = event == "UNIT_SPELLCAST_SENT"
        local guid, spell = second, third
        if sent then guid, spell = third, fourth end
        if issecretvalue(first) or first ~= "player" or issecretvalue(spell)
            or spell ~= 13262 or issecretvalue(guid) or not guid then return end
        if sent or event == "UNIT_SPELLCAST_START" then
            if not attempt or attempt.cast ~= guid then beginCast(guid) end
        elseif attempt and attempt.cast == guid then
            if event == "UNIT_SPELLCAST_SUCCEEDED" then
                local current = attempt
                current.success = true
                C_Timer.After(2, function()
                    if attempt == current and not current.ready and not current.opened then
                        finish("Skipped: no loot after successful cast.")
                    end
                end)
            else finish("Cancelled or failed cast.") end
        end
    elseif attempt then
        if event == "ITEM_LOCKED" then
            if not issecretvalue(first) and not issecretvalue(second) and second
                and first and first >= 0 and first <= 4 then inspectSlot(first, second) end
        elseif event == "LOOT_READY" then
            if attempt.closed then return finish("Skipped: another loot window after close.") end
            attempt.ready = true
            attempt.materials = attempt.materials or readLoot()
        elseif event == "LOOT_OPENED" then
            -- isFromItem does not identify the disenchanted item. Match the
            -- successful cast and consumed inventory GUID in verify instead.
            if attempt.closed then return finish("Skipped: another loot window after close.") end
            attempt.opened = true
            attempt.materials = attempt.materials or readLoot()
        elseif event == "LOOT_CLOSED" then
            attempt.closed = true
            local current = attempt
            C_Timer.After(0, function() verify(current, true) end)
        end
    end
end)

for _, event in ipairs({ "ADDON_LOADED", "ITEM_LOCKED", "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED" }) do
    frame:RegisterEvent(event)
end
for _, event in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }) do
    frame:RegisterUnitEvent(event, "player")
end

function addon.getStatus() return lastStatus end

function addon.resetLog()
    wipe(BlazeDisenchantDB.attempts)
    lastStatus = "Log cleared."
    addon.refreshLog()
end

SLASH_BLAZEDISENCHANTLOG1 = "/bdelog"
SlashCmdList.BLAZEDISENCHANTLOG = function()
    local log = BlazeDisenchantDB.attempts
    print(("BlazeDisenchant: %d observations. %s"):format(#log, lastStatus))
    for i = math.max(1, #log - 4), #log do
        local entry, parts = log[i], {}
        for id, count in pairs(entry.materials) do
            local name = C_Item.GetItemInfo(id)
            if issecretvalue(name) or not name then name = "Item #" .. id end
            parts[#parts + 1] = count .. "x " .. name
        end
        print(("#%d %s (ilvl %d, bag %d/%d): %s"):format(i, entry.link, entry.itemLevel,
            entry.bag, entry.slot, table.concat(parts, ", ")))
    end
end
