local _, addon = ...
local Gossip = {}
addon.Gossip = Gossip

local frame = CreateFrame("Frame")
local enabled = false
local revision = 0
local scheduled = false
local skip = false
local selected = false
local active = false
local hookedFrame
local AUTO_GOSSIP = {
    [132050] = "bank",
    [132057] = "taxi",
    [132060] = "vendor",
}

local function ScheduleSelection()
    if not enabled or not active or scheduled or selected then return end
    local currentRevision = revision
    scheduled = true
    C_Timer.After(0, function()
        if currentRevision ~= revision then return end
        scheduled = false
        if not enabled or not active or selected or skip or IsShiftKeyDown() then return end
        local dialogue = _G.DUIQuestFrame
        -- DialogueUI defers ShowUI while loading. Its post-hook wakes us later.
        if dialogue and dialogue.isGameLoading then return end

        local options = C_GossipInfo.GetOptions() or {}
        if #options ~= 1 or #(C_GossipInfo.GetAvailableQuests() or {}) > 0
            or #(C_GossipInfo.GetActiveQuests() or {}) > 0 then return end
        local option = options[1]
        local gossipType = AUTO_GOSSIP[option.icon]
        if not gossipType or not addon.db.gossipTypes[gossipType]
            or option.status ~= Enum.GossipOptionStatus.Available then return end
        selected = true -- The call may synchronously close gossip.
        if option.gossipOptionID then
            C_GossipInfo.SelectOption(option.gossipOptionID)
        elseif option.orderIndex then
            C_GossipInfo.SelectOptionByIndex(option.orderIndex)
        else
            selected = false
        end
    end)
end

local function HookDialogueUI()
    local dialogue = _G.DUIQuestFrame
    if not dialogue or dialogue == hookedFrame then return end
    if type(dialogue.ShowUI) ~= "function" or type(dialogue.HandleGossip) ~= "function" then return end
    hookedFrame = dialogue
    -- Post-hooks handle updates even when the window is already visible.
    -- Selection is deferred until the surrounding ShowUI has also returned.
    hooksecurefunc(dialogue, "ShowUI", function(_, event)
        if event == "GOSSIP_SHOW" then ScheduleSelection() end
    end)
    hooksecurefunc(dialogue, "HandleGossip", ScheduleSelection)
end

function Gossip:SetEnabled(state)
    enabled = state
    revision = revision + 1
    scheduled, skip, selected, active = false, false, false, false
    frame:UnregisterAllEvents()
    if enabled then
        HookDialogueUI()
        frame:RegisterEvent("ADDON_LOADED")
        frame:RegisterEvent("GOSSIP_SHOW")
        frame:RegisterEvent("GOSSIP_CLOSED")
    end
end

frame:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" then
        HookDialogueUI()
    elseif event == "GOSSIP_SHOW" then
        revision = revision + 1
        scheduled, selected, active = false, false, true
        skip = IsShiftKeyDown()
        HookDialogueUI()
        ScheduleSelection()
    elseif event == "GOSSIP_CLOSED" then
        revision = revision + 1
        scheduled, selected, active = false, false, false
    end
end)
