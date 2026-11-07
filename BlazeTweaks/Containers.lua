local _, addon = ...
local Containers = {}
addon.Containers = Containers

Containers.defaults = {
    [5523] = true, -- Small Barnacled Clam
    [5524] = true, -- Thick-shelled Clam
    [7973] = true, -- Big-mouth Clam
}

local frame = CreateFrame("Frame")
local enabled = false
local generation = 0
local scheduled = false
local previous, previousTotals, pending = {}, {}, {}
local attempt
local lootOpen = false
local merchantOpen, bankOpen = false, false
local MAX_ATTEMPTS = 3
local TryOpenNext

local function Supported(itemID)
    return Containers.defaults[itemID] or addon.shared.containerItems[itemID]
end

local function Snapshot()
    local items, totals = {}, {}
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and not issecretvalue(info.itemID) and Supported(info.itemID)
                and not issecretvalue(info.stackCount) and not issecretvalue(info.isLocked) then
                -- ItemLocation is a UI-source helper, so also check for it on enable.
                local guid = C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag, slot))
                if not issecretvalue(guid) and guid then
                    items[guid] = {
                        itemID = info.itemID, count = info.stackCount,
                        bag = bag, slot = slot, locked = info.isLocked,
                    }
                    totals[info.itemID] = (totals[info.itemID] or 0) + info.stackCount
                end
            end
        end
    end
    return items, totals
end

local function Reconcile()
    local items, totals = Snapshot()
    local consumed = {}
    if attempt and not attempt.confirmed then
        local item = items[attempt.guid]
        if not item or item.count < attempt.count then
            attempt.confirmed = true
            consumed[attempt.itemID] = 1
            local entry = pending[attempt.guid]
            if entry then
                entry.remaining = math.max(0, entry.remaining - 1)
                entry.failures = 0
            end
        end
    end

    local transfers = {}
    for guid, entry in pairs(pending) do
        local item = items[guid]
        local old = previous[guid]
        local retained = item and math.min(entry.remaining, item.count) or 0
        if old and entry.remaining > retained then
            transfers[old.itemID] = (transfers[old.itemID] or 0) + entry.remaining - retained
        end
        if not item or entry.remaining <= 0 then
            pending[guid] = nil
        else
            entry.remaining = retained
        end
    end

    local additions = {}
    for id, count in pairs(totals) do
        -- Credit our confirmed consumption so a simultaneous new container isn't lost.
        additions[id] = math.max(0, count - (previousTotals[id] or 0) + (consumed[id] or 0))
    end
    for guid, item in pairs(items) do
        local old = previous[guid]
        local increase = math.max(0, item.count - (old and old.count or 0))
        -- Splitting/merging stacks can change a GUID without adding inventory.
        -- Carry only queued units to the growing stack, never the old baseline.
        local transferred = math.min(increase, transfers[item.itemID] or 0)
        local added = math.min(increase - transferred, additions[item.itemID] or 0)
        if transferred + added > 0 then
            local entry = pending[guid] or { remaining = 0, failures = 0 }
            entry.remaining = math.min(item.count, entry.remaining + transferred + added)
            pending[guid] = entry
            transfers[item.itemID] = (transfers[item.itemID] or 0) - transferred
            additions[item.itemID] = additions[item.itemID] - added
        end
    end
    previous, previousTotals = items, totals
end

local function Schedule(delay)
    if not enabled or scheduled then return end
    local currentGeneration = generation
    scheduled = true
    C_Timer.After(delay or 0, function()
        if not enabled or currentGeneration ~= generation then return end
        scheduled = false
        Reconcile()
        TryOpenNext()
    end)
end

local function HasFreeSlot()
    for bag = 0, 4 do
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        if family == 0 and free > 0 then return true end
    end
    return false
end

local function FinishAttempt(currentAttempt)
    Reconcile()
    attempt = nil
    local remaining = pending[currentAttempt.guid]
    if not currentAttempt.confirmed and remaining and remaining.failures >= MAX_ATTEMPTS then
        pending[currentAttempt.guid] = nil
        print("|cff00ff00BlazeTweaks:|r Kunne ikke åbne item " .. currentAttempt.itemID
            .. ". Automatisk åbning af dette item er stoppet indtil næste tilgang.")
    end
    Schedule(0.2)
end

TryOpenNext = function()
    if not enabled or attempt or InCombatLockdown() or lootOpen
        or merchantOpen or bankOpen
        or (MerchantFrame and MerchantFrame:IsShown())
        or (BankFrame and BankFrame:IsShown())
        or (LootFrame and LootFrame:IsShown()) or not next(pending) then return end
    if not HasFreeSlot() then return end

    for guid, entry in pairs(pending) do
        local item = previous[guid]
        if item and not item.locked then
            local currentAttempt = {
                guid = guid, itemID = item.itemID, count = item.count,
            }
            attempt = currentAttempt
            entry.failures = entry.failures + 1
            local currentGeneration = generation
            -- Bound retries, and never let an old timeout alter a newer attempt.
            C_Timer.After(1, function()
                if not enabled or currentGeneration ~= generation or attempt ~= currentAttempt then return end
                currentAttempt.expired = true
                if lootOpen then return end -- LOOT_CLOSED will resume the queue.
                FinishAttempt(currentAttempt)
            end)
            C_Container.UseContainerItem(item.bag, item.slot)
            return
        end
    end
end

function Containers:SetEnabled(state)
    enabled = false
    generation = generation + 1
    frame:UnregisterAllEvents()
    previous, previousTotals, pending = {}, {}, {}
    attempt, scheduled, lootOpen = nil, false, false
    merchantOpen, bankOpen = false, false
    if not state then return end
    if not ItemLocation or type(ItemLocation.CreateFromBagAndSlot) ~= "function"
        or not C_Item or type(C_Item.GetItemGUID) ~= "function"
        or type(issecretvalue) ~= "function" then
        print("|cff00ff00BlazeTweaks:|r Container-API mangler. Automatisk åbning kunne ikke startes.")
        return
    end
    enabled = true
    -- Items present at login, enable or list changes are deliberately not queued.
    previous, previousTotals = Snapshot()
    lootOpen = LootFrame and LootFrame:IsShown() or false
    merchantOpen = MerchantFrame and MerchantFrame:IsShown() or false
    bankOpen = BankFrame and BankFrame:IsShown() or false
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("ITEM_LOCK_CHANGED")
    frame:RegisterEvent("LOOT_OPENED")
    frame:RegisterEvent("LOOT_CLOSED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("MERCHANT_SHOW")
    frame:RegisterEvent("MERCHANT_CLOSED")
    frame:RegisterEvent("BANKFRAME_OPENED")
    frame:RegisterEvent("BANKFRAME_CLOSED")
end

frame:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        merchantOpen = true
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
    elseif event == "MERCHANT_CLOSED" then
        merchantOpen = false
        Schedule()
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
        Schedule()
    elseif event == "LOOT_OPENED" then
        lootOpen = true
    elseif event == "LOOT_CLOSED" then
        lootOpen = false
        -- Inventory updates may arrive just after this event.
        Reconcile()
        if attempt and attempt.confirmed then
            attempt = nil
        elseif attempt and attempt.expired then
            local currentAttempt, currentGeneration = attempt, generation
            C_Timer.After(0.2, function()
                if enabled and currentGeneration == generation and attempt == currentAttempt and not lootOpen then
                    FinishAttempt(currentAttempt)
                end
            end)
        end
        Schedule()
    else
        Schedule()
    end
end)
