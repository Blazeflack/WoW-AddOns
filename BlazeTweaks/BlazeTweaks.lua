-- BlazeTweaks.lua

local function TweakCombinedBags()
    local frame = ContainerFrameCombinedBags
    if not frame then
        return
    end

    local settingPosition = false

    local function SetPosition()
        if settingPosition then
            return
        end

        settingPosition = true

        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1400, 130)

        settingPosition = false
    end

    -- Initial position
    SetPosition()

    -- Override Blizzard re-anchoring immediately
    hooksecurefunc(frame, "SetPoint", function()
        if not settingPosition then
            SetPosition()
        end
    end)
end

local function TweakChatHistory()
    BlazeTweaksDB = BlazeTweaksDB or {}
    BlazeTweaksDB.chatHistory = BlazeTweaksDB.chatHistory or {}

    local history = BlazeTweaksDB.chatHistory
    local historyIndex = 0
    local draft = ""
    local maxHistory = 100

    local function AddToHistory(text)
        if type(text) ~= "string" or text == "" then
            return
        end

        -- Avoid consecutive duplicates
        if history[#history] ~= text then
            table.insert(history, text)

            if #history > maxHistory then
                table.remove(history, 1)
            end
        end

        historyIndex = 0
        draft = ""
    end

    local function OnKeyDown(self, key)
        -- Leave Blizzard's existing Alt+Up/Down behavior untouched
        if IsAltKeyDown() then
            return
        end

        if key == "UP" then
            if #history == 0 then
                return
            end

            if historyIndex == 0 then
                draft = self:GetText() or ""
            end

            if historyIndex < #history then
                historyIndex = historyIndex + 1
            end

            local text = history[#history - historyIndex + 1]

            self:SetText(text)
            self:SetCursorPosition(#text)

        elseif key == "DOWN" then
            if historyIndex == 0 then
                return
            end

            if historyIndex > 1 then
                historyIndex = historyIndex - 1

                local text = history[#history - historyIndex + 1]

                self:SetText(text)
                self:SetCursorPosition(#text)
            else
                historyIndex = 0

                self:SetText(draft)
                self:SetCursorPosition(#draft)
            end
        end
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame" .. i .. "EditBox"]

        if editBox then
            hooksecurefunc(editBox, "AddHistoryLine", function(_, text)
                AddToHistory(text)
            end)

            editBox:HookScript("OnKeyDown", OnKeyDown)

            editBox:HookScript("OnTextChanged", function(self, userInput)
                if userInput then
                    historyIndex = 0
                    draft = self:GetText() or ""
                end
            end)
        end
    end
end

local function TweakAutoOpenClam()
    local DEBUG = false

    local CLAMS = {
        [5523] = "Small Barnacled Clam",
        [5524] = "Thick-shelled Clam",
        [7973] = "Big-mouth Clam",
    }

    local frame = CreateFrame("Frame")

    -- ITEM_PUSH gives us an icon rather than an item ID,
    -- so build a set of valid clam icons.
    local clamIcons = {}

    for itemID in pairs(CLAMS) do
        local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)

        if icon then
            clamIcons[icon] = true
        end
    end

    local lastClamCount = 0
    local pendingClamPush = false
    local queuedClams = 0
    local openingClam = false

    local function DebugPrint(...)
        if DEBUG then
            print("|cff00ff00BlazeTweaks Clam:|r", ...)
        end
    end

    local function GetClamCount()
        local count = 0

        for bag = 0, 4 do
            local numSlots = C_Container.GetContainerNumSlots(bag)

            for slot = 1, numSlots do
                local itemID = C_Container.GetContainerItemID(bag, slot)

                if itemID and CLAMS[itemID] then
                    local info = C_Container.GetContainerItemInfo(bag, slot)

                    if info then
                        count = count + info.stackCount
                    end
                end
            end
        end

        return count
    end

    local function GetNormalBagFreeSlots()
        local freeSlots = 0

        for bag = 0, 4 do
            local free, bagType = C_Container.GetContainerNumFreeSlots(bag)

            DebugPrint(
                "Bag",
                bag,
                "free:",
                tostring(free),
                "bagType:",
                tostring(bagType)
            )

            -- bagType 0 = normal unrestricted bag.
            -- Quivers / ammo pouches have another bag type.
            if bagType == 0 then
                freeSlots = freeSlots + free
            end
        end

        DebugPrint("Total normal free slots:", freeSlots)

        return freeSlots
    end

    local function IsLootOpen()
        return LootFrame and LootFrame:IsShown()
    end

    local TryOpenNextClam

    TryOpenNextClam = function()
        if queuedClams <= 0 then
            return
        end

        if openingClam then
            DebugPrint(
                "Not opening:",
                "already waiting for previous clam.",
                "queued:",
                queuedClams
            )
            return
        end

        if IsLootOpen() then
            DebugPrint(
                "Not opening:",
                "loot window is currently open.",
                "queued:",
                queuedClams
            )
            return
        end

        local freeSlots = GetNormalBagFreeSlots()

        if freeSlots < 1 then
            DebugPrint(
                "Not opening:",
                "no free slots in normal bags.",
                "queued:",
                queuedClams
            )
            return
        end

        for bag = 0, 4 do
            local numSlots = C_Container.GetContainerNumSlots(bag)

            for slot = 1, numSlots do
                local itemID = C_Container.GetContainerItemID(bag, slot)

                if itemID and CLAMS[itemID] then
                    DebugPrint(
                        "Opening clam:",
                        CLAMS[itemID],
                        "itemID:",
                        itemID,
                        "bag:",
                        bag,
                        "slot:",
                        slot,
                        "queued:",
                        queuedClams
                    )

                    openingClam = true

                    C_Container.UseContainerItem(bag, slot)

                    -- If the result has not yet been confirmed,
                    -- allow another attempt later.
                    C_Timer.After(0.5, function()
                        if openingClam then
                            openingClam = false

                            DebugPrint(
                                "Open attempt not yet confirmed.",
                                "Clam remains queued:",
                                queuedClams
                            )
                        end
                    end)

                    return
                end
            end
        end

        DebugPrint(
            "Could not find a supported clam despite queuedClams:",
            queuedClams
        )
    end

    -- Existing clams at login/reload are deliberately not queued.
    lastClamCount = GetClamCount()

    DebugPrint(
        "Initialized.",
        "initial clam count:",
        lastClamCount
    )

    frame:RegisterEvent("ITEM_PUSH")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("LOOT_CLOSED")

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "ITEM_PUSH" then
            local bagSlot, iconFileID = ...

            DebugPrint(
                "ITEM_PUSH",
                "bagSlot:",
                tostring(bagSlot),
                "icon:",
                tostring(iconFileID)
            )

            if clamIcons[iconFileID] then
                DebugPrint("ITEM_PUSH icon matches supported clam.")

                pendingClamPush = true
            end

        elseif event == "LOOT_CLOSED" then
            DebugPrint(
                "LOOT_CLOSED",
                "queued:",
                queuedClams
            )

            -- Give Blizzard one frame to finish closing the loot UI.
            C_Timer.After(0, function()
                TryOpenNextClam()
            end)

        elseif event == "BAG_UPDATE_DELAYED" then
            local currentClamCount = GetClamCount()
            local difference = currentClamCount - lastClamCount

            DebugPrint(
                "BAG_UPDATE_DELAYED",
                "previous:",
                lastClamCount,
                "current:",
                currentClamCount,
                "difference:",
                difference,
                "pendingPush:",
                tostring(pendingClamPush),
                "queued:",
                queuedClams,
                "opening:",
                tostring(openingClam)
            )

            ------------------------------------------------------------
            -- New supported clam(s) appeared
            ------------------------------------------------------------

            if difference > 0 and pendingClamPush then
                queuedClams = queuedClams + difference
                pendingClamPush = false

                DebugPrint(
                    "Added",
                    difference,
                    "clam(s) to queue.",
                    "Queued:",
                    queuedClams
                )
            end

            ------------------------------------------------------------
            -- Supported clam(s) disappeared
            ------------------------------------------------------------

            if difference < 0 then
                local removed = -difference

                if queuedClams > 0 then
                    local completed = math.min(removed, queuedClams)

                    queuedClams = queuedClams - completed

                    DebugPrint(
                        completed,
                        "queued clam(s) removed.",
                        "Remaining:",
                        queuedClams
                    )
                end

                openingClam = false
            end

            lastClamCount = currentClamCount

            ------------------------------------------------------------
            -- Try the next queued clam
            ------------------------------------------------------------

            if queuedClams > 0 then
                C_Timer.After(0, function()
                    TryOpenNextClam()
                end)
            end
        end
    end)
end

local function TweakChatCopy()
    local copyFrame
    local copyEditBox
    local measureText

    local function CleanChatText(text)
        if not text then
            return ""
        end

        -- Remove textures/icons
        text = text:gsub("|T.-|t", "")
        text = text:gsub("|A.-|a", "")

        -- Convert hyperlinks to their visible text
        text = text:gsub("|H.-|h(.-)|h", "%1")

        -- Remove color codes
        text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
        text = text:gsub("|r", "")

        return text
    end

    local function CreateCopyFrame()
        if copyFrame then
            return
        end

        copyFrame = CreateFrame(
            "Frame",
            "BlazeTweaksChatCopyFrame",
            UIParent,
            "BackdropTemplate"
        )

        copyFrame:SetSize(750, 500)
        copyFrame:SetPoint("CENTER")
        copyFrame:SetFrameStrata("DIALOG")
        copyFrame:SetClampedToScreen(true)
        copyFrame:SetMovable(true)
        copyFrame:EnableMouse(true)
        copyFrame:RegisterForDrag("LeftButton")

        copyFrame:SetScript("OnDragStart", function(self)
            self:StartMoving()
        end)

        copyFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
        end)

        copyFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = {
                left = 11,
                right = 12,
                top = 12,
                bottom = 11,
            },
        })

        copyFrame:SetBackdropColor(0, 0, 0, 1)

        -- Title
        copyFrame.title = copyFrame:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormalLarge"
        )

        copyFrame.title:SetPoint("TOPLEFT", 18, -16)
        copyFrame.title:SetText("BlazeTweaks - Chat Copy")

        -- Hint
        copyFrame.hint = copyFrame:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlightSmall"
        )

        copyFrame.hint:SetPoint("TOPRIGHT", -45, -19)
        copyFrame.hint:SetText("Ctrl+C to copy")

        -- Close button
        local closeButton = CreateFrame(
            "Button",
            nil,
            copyFrame,
            "UIPanelCloseButton"
        )

        closeButton:SetPoint("TOPRIGHT", -5, -5)

        -- Scroll frame
        local scrollFrame = CreateFrame(
            "ScrollFrame",
            nil,
            copyFrame,
            "UIPanelScrollFrameTemplate"
        )

        scrollFrame:SetPoint("TOPLEFT", 18, -45)
        scrollFrame:SetPoint("BOTTOMRIGHT", -35, 18)

        -- Copyable text box
        copyEditBox = CreateFrame(
            "EditBox",
            nil,
            scrollFrame
        )

        copyEditBox:SetMultiLine(true)
        copyEditBox:SetAutoFocus(false)
        copyEditBox:SetFontObject(ChatFontNormal)
        copyEditBox:SetWidth(685)
        copyEditBox:SetHeight(1)
        copyEditBox:SetMaxLetters(0)

        copyEditBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            copyFrame:Hide()
        end)

        scrollFrame:SetScrollChild(copyEditBox)

        -- Hidden FontString used to calculate the required EditBox height
        measureText = copyFrame:CreateFontString(
            nil,
            "ARTWORK",
            "ChatFontNormal"
        )

        measureText:SetWidth(685)
        measureText:SetWordWrap(true)
        measureText:Hide()

        copyFrame:Hide()

        -- Allows Escape to close the window
        table.insert(UISpecialFrames, "BlazeTweaksChatCopyFrame")
    end

    local function ShowChatCopy(chatFrame)
        CreateCopyFrame()

        local lines = {}
        local numMessages = chatFrame:GetNumMessages()

        for i = 1, numMessages do
            local text = chatFrame:GetMessageInfo(i)

            if text then
                lines[#lines + 1] = CleanChatText(text)
            end
        end

        local fullText = table.concat(lines, "\n")

        copyFrame.title:SetText(
            "BlazeTweaks - " .. (chatFrame:GetName() or "Chat")
        )

        copyEditBox:SetText(fullText)

        -- Resize edit box to fit the complete text
        measureText:SetText(fullText)

        local textHeight = measureText:GetStringHeight()

        copyEditBox:SetHeight(
            math.max(textHeight + 20, 430)
        )

        copyFrame:Show()

        -- Start at the bottom of the chat
        C_Timer.After(0, function()
            local parent = copyEditBox:GetParent()

            if parent and parent.SetVerticalScroll then
                parent:SetVerticalScroll(
                    math.max(
                        0,
                        copyEditBox:GetHeight() - parent:GetHeight()
                    )
                )
            end

            -- Select everything automatically
            copyEditBox:SetFocus()
            copyEditBox:HighlightText()
        end)
    end

    local function AddCopyButton(chatFrame)
        if chatFrame.BlazeTweaksCopyButton then
            return
        end

        local button = CreateFrame(
            "Button",
            nil,
            chatFrame,
            "UIPanelButtonTemplate"
        )

        button:SetSize(22, 20)
        button:SetPoint(
            "TOPRIGHT",
            chatFrame,
            "TOPRIGHT",
            10,
            -2
        )

        button:SetText("C")
        button:SetFrameLevel(chatFrame:GetFrameLevel() + 10)

        button:SetScript("OnClick", function()
            ShowChatCopy(chatFrame)
        end)

        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Copy Chat")
            GameTooltip:AddLine(
                "Open this chat window in a copyable text box.",
                1,
                1,
                1
            )
            GameTooltip:Show()
        end)

        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        chatFrame.BlazeTweaksCopyButton = button
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]

        if chatFrame then
            AddCopyButton(chatFrame)
        end
    end
end

local function TweakQuickKeybindSlashCommand()
    SLASH_BLAZETWEAKSQUICKKEYBIND1 = "/kb"

    SlashCmdList["BLAZETWEAKSQUICKKEYBIND"] = function()
        if InCombatLockdown() then
            print("|cff00ff00BlazeTweaks:|r Quick Keybind kan ikke åbnes i combat.")
            return
        end

        -- Blizzard_QuickKeybind is loaded on demand,
        -- so make sure it is available first.
        if not C_AddOns.IsAddOnLoaded("Blizzard_QuickKeybind") then
            local loaded, reason = C_AddOns.LoadAddOn("Blizzard_QuickKeybind")

            if not loaded then
                print(
                    "|cff00ff00BlazeTweaks:|r Kunne ikke loade Blizzard_QuickKeybind:",
                    tostring(reason)
                )
                return
            end
        end

        if QuickKeybindFrame then
            QuickKeybindFrame:Show()
        else
            print("|cff00ff00BlazeTweaks:|r QuickKeybindFrame blev ikke fundet.")
        end
    end
end

local function TweakAutoGossip()
    local DEBUG = false

    local AUTO_GOSSIP = {
        [132050] = "Bank",
        [132057] = "Taxi",
        [132060] = "Vendor",
    }

    local skipCurrentGossip = false
    local dialogueFrame = _G["DUIQuestFrame"]
    local usingDialogueUI = dialogueFrame ~= nil

    local function DebugPrint(...)
        if DEBUG then
            print("|cff00ff00BlazeTweaks Gossip:|r", ...)
        end
    end

    local function HandleGossip()
        local options = C_GossipInfo.GetOptions() or {}
        local availableQuests = C_GossipInfo.GetAvailableQuests() or {}
        local activeQuests = C_GossipInfo.GetActiveQuests() or {}

        DebugPrint(
            "Checking gossip.",
            "options:", #options,
            "available quests:", #availableQuests,
            "active quests:", #activeQuests,
            "Shift bypass:", tostring(skipCurrentGossip)
        )

        -- Holding Shift when the NPC was opened disables auto-selection.
        --
        -- Also check the current Shift state in case DialogueUI's OnShow
        -- happens before our GOSSIP_SHOW handler during the same frame.
        if skipCurrentGossip or IsShiftKeyDown() then
            DebugPrint("Skipping: Shift bypass is active.")
            return
        end

        -- Only automate NPCs with exactly one gossip option.
        if #options ~= 1 then
            DebugPrint(
                "Skipping: gossip option count is",
                #options,
                "instead of 1."
            )
            return
        end

        -- Don't interfere with NPCs that also have quests.
        if #availableQuests > 0 or #activeQuests > 0 then
            DebugPrint("Skipping: NPC has quest options.")
            return
        end

        local option = options[1]

        if not option then
            return
        end

        local autoType = AUTO_GOSSIP[option.icon]

        if not autoType then
            DebugPrint(
                "Skipping:",
                tostring(option.name),
                "icon:",
                tostring(option.icon),
                "is not enabled for auto-selection."
            )
            return
        end

        if not option.orderIndex then
            DebugPrint("Skipping: option has no orderIndex.")
            return
        end

        DebugPrint(
            "Automatically selecting:",
            autoType,
            tostring(option.name),
            "orderIndex:",
            tostring(option.orderIndex)
        )

        C_GossipInfo.SelectOptionByIndex(option.orderIndex)
    end

    ------------------------------------------------------------
    -- Track gossip state and Shift bypass
    ------------------------------------------------------------

    local eventFrame = CreateFrame("Frame")

    eventFrame:RegisterEvent("GOSSIP_SHOW")
    eventFrame:RegisterEvent("GOSSIP_CLOSED")

    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "GOSSIP_SHOW" then
            -- Remember whether Shift was held when this gossip opened.
            skipCurrentGossip = IsShiftKeyDown()

            DebugPrint(
                "GOSSIP_SHOW",
                "Shift bypass:",
                tostring(skipCurrentGossip)
            )

            -- Without DialogueUI, handle gossip directly from the event.
            if not usingDialogueUI then
                HandleGossip()
            end

        elseif event == "GOSSIP_CLOSED" then
            DebugPrint("GOSSIP_CLOSED")

            skipCurrentGossip = false
        end
    end)

    ------------------------------------------------------------
    -- DialogueUI integration
    ------------------------------------------------------------

    if usingDialogueUI then
        DebugPrint(
            "DialogueUI detected. Using DUIQuestFrame OnShow hook."
        )

        dialogueFrame:HookScript("OnShow", function(self)
            -- DUIQuestFrame is also used for quests and other
            -- interaction types. Only process actual gossip.
            if self.handler ~= "HandleGossip" then
                return
            end

            DebugPrint("DUIQuestFrame shown for gossip.")

            HandleGossip()
        end)

    else
        ------------------------------------------------------------
        -- Standard Blizzard gossip UI
        ------------------------------------------------------------

        DebugPrint(
            "DialogueUI not detected. Using GOSSIP_SHOW directly."
        )
    end
end

local function TweakCombatLog()
	local frame = ChatFrame2
	if not frame then
		return
	end

	if frame.isDocked then
		FCF_UnDockFrame(frame)
	end

	frame:SetClampedToScreen(false)

	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -1000, -1000)

	frame:SetAlpha(0)
	--frame:Hide()

	if ChatFrame2Tab then
		ChatFrame2Tab:SetAlpha(0)
		--ChatFrame2Tab:Hide()
	end
end

------------------------------------------------------------
-- BlazeTweaks Settings
------------------------------------------------------------

local TWEAKS = {
    {
        key = "combinedBags",
        name = "Combined Bags position",
        func = TweakCombinedBags,
    },
    {
        key = "chatHistory",
        name = "Persistent chat history",
        func = TweakChatHistory,
    },
    {
        key = "autoOpenClams",
        name = "Auto-open clams",
        func = TweakAutoOpenClam,
    },
    {
        key = "chatCopy",
        name = "Chat copy button",
        func = TweakChatCopy,
    },
    {
        key = "quickKeybind",
        name = "/kb Quick Keybind",
        func = TweakQuickKeybindSlashCommand,
    },
    {
        key = "autoGossip",
        name = "Auto-select gossip",
        func = TweakAutoGossip,
    },
    {
        key = "combatLog",
        name = "Hide Combat Log",
        func = TweakCombatLog,
    },
}


------------------------------------------------------------
-- Settings state
------------------------------------------------------------

local loadedTweakStates = {}

local function InitializeTweakSettings()
    BlazeTweaksCharDB = BlazeTweaksCharDB or {}
    BlazeTweaksCharDB.tweaks = BlazeTweaksCharDB.tweaks or {}

    for _, tweak in ipairs(TWEAKS) do
        -- All tweaks are enabled by default.
        if BlazeTweaksCharDB.tweaks[tweak.key] == nil then
            BlazeTweaksCharDB.tweaks[tweak.key] = false
        end

        -- Remember the state that was active when this UI loaded.
        -- This lets us determine whether a reload is required.
        loadedTweakStates[tweak.key] =
            BlazeTweaksCharDB.tweaks[tweak.key]
    end
end

local function IsTweakEnabled(key)
    return BlazeTweaksCharDB
        and BlazeTweaksCharDB.tweaks
        and BlazeTweaksCharDB.tweaks[key] ~= false
end


------------------------------------------------------------
-- Settings GUI
------------------------------------------------------------

local optionsFrame
local reloadButton
local optionCheckboxes = {}

local function HasPendingChanges()
    if not BlazeTweaksCharDB or not BlazeTweaksCharDB.tweaks then
        return false
    end

    for _, tweak in ipairs(TWEAKS) do
        if BlazeTweaksCharDB.tweaks[tweak.key]
            ~= loadedTweakStates[tweak.key] then
            return true
        end
    end

    return false
end

local function UpdateReloadButton()
    if not reloadButton then
        return
    end

    if HasPendingChanges() then
        reloadButton:Enable()
    else
        reloadButton:Disable()
    end
end

local function CreateBlazeTweaksOptions()
    if optionsFrame then
        return
    end

    optionsFrame = CreateFrame(
        "Frame",
        "BlazeTweaksOptionsFrame",
        UIParent,
        "BackdropTemplate"
    )

    optionsFrame:SetSize(400, 390)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetClampedToScreen(true)

    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")

    optionsFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    optionsFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    optionsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {
            left = 11,
            right = 12,
            top = 12,
            bottom = 11,
        },
    })

    optionsFrame:SetBackdropColor(0, 0, 0, 1)


    ------------------------------------------------------------
    -- Title
    ------------------------------------------------------------

    local title = optionsFrame:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalLarge"
    )

    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText("BlazeTweaks")


    ------------------------------------------------------------
    -- Character indicator
    ------------------------------------------------------------

    local characterText = optionsFrame:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )

    characterText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

    characterText:SetText(
        "Settings for: "
            .. UnitName("player")
            .. " - "
            .. GetRealmName()
    )


    ------------------------------------------------------------
    -- Close button
    ------------------------------------------------------------

    local closeButton = CreateFrame(
        "Button",
        nil,
        optionsFrame,
        "UIPanelCloseButton"
    )

    closeButton:SetPoint("TOPRIGHT", -5, -5)


    ------------------------------------------------------------
    -- Tweak checkboxes
    ------------------------------------------------------------

    local previousCheckbox

    for index, tweak in ipairs(TWEAKS) do
        local checkbox = CreateFrame(
            "CheckButton",
            "BlazeTweaksOption" .. index,
            optionsFrame,
            "UICheckButtonTemplate"
        )

        checkbox:SetSize(26, 26)

        if previousCheckbox then
            checkbox:SetPoint(
                "TOPLEFT",
                previousCheckbox,
                "BOTTOMLEFT",
                0,
                -8
            )
        else
            checkbox:SetPoint("TOPLEFT", 22, -75)
        end

        local label = _G[checkbox:GetName() .. "Text"]

        if label then
            label:SetText(tweak.name)
            label:SetFontObject("GameFontNormal")
        end

        checkbox:SetChecked(
            BlazeTweaksCharDB.tweaks[tweak.key]
        )

        checkbox:SetScript("OnClick", function(self)
            BlazeTweaksCharDB.tweaks[tweak.key] =
                self:GetChecked() and true or false

            UpdateReloadButton()
        end)

        optionCheckboxes[tweak.key] = checkbox
        previousCheckbox = checkbox
    end


    ------------------------------------------------------------
    -- Reload information
    ------------------------------------------------------------

    local reloadText = optionsFrame:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )

    reloadText:SetPoint("BOTTOMLEFT", 22, 55)
    reloadText:SetText(
        "Changes take effect after reloading the UI."
    )


    ------------------------------------------------------------
    -- Reload button
    ------------------------------------------------------------

    reloadButton = CreateFrame(
        "Button",
        nil,
        optionsFrame,
        "UIPanelButtonTemplate"
    )

    reloadButton:SetSize(110, 26)
    reloadButton:SetPoint("BOTTOMRIGHT", -20, 20)
    reloadButton:SetText("Reload UI")

    reloadButton:SetScript("OnClick", function()
        ReloadUI()
    end)

    reloadButton:Disable()


    ------------------------------------------------------------
    -- Close button
    ------------------------------------------------------------

    local bottomCloseButton = CreateFrame(
        "Button",
        nil,
        optionsFrame,
        "UIPanelButtonTemplate"
    )

    bottomCloseButton:SetSize(90, 26)
    bottomCloseButton:SetPoint(
        "RIGHT",
        reloadButton,
        "LEFT",
        -8,
        0
    )

    bottomCloseButton:SetText("Close")

    bottomCloseButton:SetScript("OnClick", function()
        optionsFrame:Hide()
    end)


    ------------------------------------------------------------
    -- Escape closes the window
    ------------------------------------------------------------

    table.insert(
        UISpecialFrames,
        "BlazeTweaksOptionsFrame"
    )

    optionsFrame:Hide()
end


local function ShowBlazeTweaksOptions()
    CreateBlazeTweaksOptions()

    -- Refresh checkbox states whenever the window is opened.
    for _, tweak in ipairs(TWEAKS) do
        local checkbox = optionCheckboxes[tweak.key]

        if checkbox then
            checkbox:SetChecked(
                BlazeTweaksCharDB.tweaks[tweak.key]
            )
        end
    end

    UpdateReloadButton()

    optionsFrame:Show()
end


------------------------------------------------------------
-- Slash commands
------------------------------------------------------------

SLASH_BLAZETWEAKS1 = "/bt"
SLASH_BLAZETWEAKS2 = "/blazetweaks"

SlashCmdList["BLAZETWEAKS"] = function()
    ShowBlazeTweaksOptions()
end


------------------------------------------------------------
-- Initialize BlazeTweaks
------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function()
    InitializeTweakSettings()

    C_Timer.After(0, function()
        for _, tweak in ipairs(TWEAKS) do
            if IsTweakEnabled(tweak.key) then
                tweak.func()
            end
        end
    end)
end)