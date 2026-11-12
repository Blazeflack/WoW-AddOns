local _, addon = ...
addon.mailWindowGap = 5
addon.mailWindowTopPadding = 8
local accent = { r = 0.706, g = 0.604, b = 0.420 }
addon.accent = accent
local panels, buttons = {}, {}
local hookedTabs = false

-- Freeze the active theme until reload: the custom mailbox layout is not
-- safely reversible while Blizzard's mail frames are already in use.
function addon.InitializeTheme()
    if BlazeMailDB.theme ~= "blizzard" then BlazeMailDB.theme = "blaze" end
    addon.activeTheme = BlazeMailDB.theme
end

function addon.IsBlizzardTheme()
    return addon.activeTheme == "blizzard"
end

local function InboxColors()
    for index = 1, 7 do
        local expiry = _G["MailItem" .. index .. "ExpireTime"]
        if expiry then expiry:SetNormalFontObject(addon.GetFonts().small) end
    end
end

local function HideTextures(frame)
    local textures = {}
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            region:Hide()
            textures[#textures + 1] = region
        end
    end
    return textures
end

local function Text(region, font, light)
    if not region then return end
    -- Change size/face without discarding Blizzard's read/unread, error or
    -- disabled colors. Static labels can explicitly opt into light text.
    local file, size, flags = font:GetFont()
    region:SetFont(file, size, flags)
    if light then region:SetTextColor(0.933, 0.910, 0.863) end
end

local function Labels(frame, font, light)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("FontString") then Text(region, font, light) end
    end
end

local function Panel(frame, r, g, b)
    if not frame then return end
    if panels[frame] then return end
    panels[frame] = true
    HideTextures(frame)
    if frame.NineSlice then frame.NineSlice:Hide() end
    local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    local window = frame == MailFrame or frame == OpenMailFrame
    if window then
        -- Keep Blizzard's content anchors available for expanding attachment rows.
        local topPadding, bottomPadding = addon.mailWindowTopPadding, 6
        fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, topPadding)
        fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -bottomPadding)
        frame:SetHitRectInsets(0, 0, -topPadding, -bottomPadding)
    else
        fill:SetAllPoints()
    end
    fill:SetColorTexture(r or 0.157, g or 0.125, b or 0.094, 1)
    if not window then return end
    for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", true },
        { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local line = frame:CreateTexture(nil, "BORDER")
        line:SetPoint(edge[1], fill, edge[1])
        line:SetPoint(edge[2], fill, edge[2])
        if edge[3] then line:SetHeight(1) else line:SetWidth(1) end
        line:SetColorTexture(0.408, 0.318, 0.227, 1)
    end
end

local function Button(button, fonts)
    if not button or buttons[button] then return end
    local original = HideTextures(button)
    local state = { original = original }
    buttons[button] = state
    button:SetNormalFontObject(fonts.small)
    button:SetHighlightFontObject(fonts.small)
    button:SetDisabledFontObject(fonts.disabled)
    local function Texture(layer, r, g, b, a)
        local texture = button:CreateTexture(nil, layer)
        texture:SetAllPoints()
        texture:SetColorTexture(r, g, b, a)
        return texture
    end
    state.normal = Texture("BACKGROUND", 0.224, 0.173, 0.129, 1)
    button:SetNormalTexture(state.normal)
    button:SetPushedTexture(Texture("BACKGROUND", 0.29, 0.22, 0.15, 1))
    button:SetDisabledTexture(Texture("BACKGROUND", 0.18, 0.145, 0.11, 1))
    button:SetHighlightTexture(Texture("HIGHLIGHT", 0.706, 0.604, 0.420, 0.15))
end

local function Window(frame, fonts)
    if not frame then return end
    Panel(frame)
    if frame.Inset then frame.Inset:Hide() end
    if frame.PortraitContainer then frame.PortraitContainer:Hide() end
    if frame.TitleContainer then
        Text(frame.TitleContainer.TitleText, fonts.normal, true)
    end
    Button(frame.CloseButton, fonts)
    if frame.CloseButton then frame.CloseButton:SetText("X") end
end

local function UpdateTabs()
    local selected = SendMailFrame and SendMailFrame:IsShown() and 2 or 1
    for index = 1, 2 do
        local tab = _G["MailFrameTab" .. index]
        local state = tab and buttons[tab]
        if state then
            -- PanelTemplates changes the visibility of the original tab art.
            for _, texture in ipairs(state.original) do texture:Hide() end
            local fonts = addon.GetFonts()
            tab:SetNormalFontObject(fonts.small)
            tab:SetDisabledFontObject(index == selected and fonts.small or fonts.disabled)
            Labels(tab, fonts.small, true)
            if tab.Text then
                tab.Text:ClearAllPoints()
                tab.Text:SetPoint("CENTER", tab, "CENTER", 0, 0)
            end
            if state.indicator then state.indicator:SetShown(index == selected) end
            state.normal:SetColorTexture(index == selected and 0.29 or 0.224,
                index == selected and 0.22 or 0.173, index == selected and 0.15 or 0.129, 1)
        end
    end
end

local function Place(frame, parent, point, x, y, width, height)
    frame:ClearAllPoints()
    frame:SetPoint(point, parent, point, x, y)
    frame:SetSize(width, height)
end

local function LayoutMailbox(fonts)
    local width = 390
    MailFrame:SetWidth(width)
    if OpenMailFrame then
        OpenMailFrame:ClearAllPoints()
        OpenMailFrame:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", addon.mailWindowGap, 0)
        for _, label in pairs({ OpenMailSenderLabel, OpenMailSubjectLabel }) do
            label:ClearAllPoints()
            label:SetPoint("TOPRIGHT", OpenMailFrame, "TOPLEFT", 58,
                label == OpenMailSenderLabel and -33 or -55)
        end
        if OpenMailSender and OpenMailSender.Name then OpenMailSender.Name:SetWordWrap(false) end
        if OpenMailFrame.CloseButton then Place(OpenMailFrame.CloseButton, OpenMailFrame, "TOPRIGHT", -12, -3, 24, 23) end
        if OpenMailCancelButton then Place(OpenMailCancelButton, OpenMailFrame, "BOTTOMRIGHT", -12, 6, 68, 24) end
        if OpenMailDeleteButton then Place(OpenMailDeleteButton, OpenMailFrame, "BOTTOMRIGHT", -86, 6, 76, 24) end
        if OpenMailReplyButton then Place(OpenMailReplyButton, OpenMailFrame, "BOTTOMRIGHT", -168, 6, 68, 24) end
    end
    if MailFrame.TitleContainer then MailFrame.TitleContainer:Hide() end
    if MailFrame.CloseButton then
        Place(MailFrame.CloseButton, MailFrame, "TOPRIGHT", -12, -3, 24, 23)
    end
    for i = 1, 2 do
        local tab = _G["MailFrameTab" .. i]
        if tab then
            Place(tab, MailFrame, "TOPLEFT", 12 + (i - 1) * 82, -2, 80, 25)
            local indicator = tab:CreateTexture(nil, "OVERLAY")
            indicator:SetPoint("BOTTOMLEFT")
            indicator:SetPoint("BOTTOMRIGHT")
            indicator:SetHeight(2)
            indicator:SetColorTexture(accent.r, accent.g, accent.b, 1)
            buttons[tab].indicator = indicator
        end
    end
    if InboxFrame then
        if MailItem1 then
            MailItem1:ClearAllPoints()
            MailItem1:SetPoint("TOPLEFT", InboxFrame, "TOPLEFT", 12, -50)
        end
        for i = 1, 7 do
            local row = _G["MailItem" .. i]
            if row then row:SetWidth(width - 24) end
        end
        if OpenAllMail then Place(OpenAllMail, InboxFrame, "BOTTOM", 0, 10, 116, 24) end
        if InboxCurrentPage then
            InboxCurrentPage:ClearAllPoints()
            InboxCurrentPage:SetPoint("TOPRIGHT", InboxFrame, "TOPRIGHT", -12, -32)
        end
        for _, action in ipairs({ {"PrevPageButton", "BOTTOMLEFT", 12, "<"},
            {"NextPageButton", "BOTTOMRIGHT", -12, ">"} }) do
            local button = InboxFrame[action[1]]
            if button then
                for _, region in ipairs({ button:GetRegions() }) do
                    if region:IsObjectType("FontString") then region:Hide() end
                end
                Button(button, fonts)
                button:SetText(action[4])
                Place(button, InboxFrame, action[2], action[3], 10, 32, 22)
            end
        end
    end
    if SendMailNameEditBox then
        Place(SendMailNameEditBox, SendMailFrame, "TOPLEFT", 64, -35, 162, 21)
        SendMailNameEditBox:SetTextInsets(5, 5, 0, 0)
    end
    if SendMailSubjectEditBox then
        Place(SendMailSubjectEditBox, SendMailFrame, "TOPLEFT", 64, -61, width - 76, 21)
        SendMailSubjectEditBox:SetTextInsets(5, 5, 0, 0)
    end
    if SendMailScrollFrame then
        SendMailScrollFrame:ClearAllPoints()
        SendMailScrollFrame:SetPoint("TOPLEFT", SendMailFrame, "TOPLEFT", 12, -91)
        SendMailScrollFrame:SetWidth(width - 48)
    end
    if SendMailScrollChildFrame then SendMailScrollChildFrame:SetWidth(width - 48) end
    if SendMailBodyEditBox then SendMailBodyEditBox:SetWidth(width - 88) end
    for _, name in ipairs({ "SendMailMoneyGold", "SendMailMoneySilver", "SendMailMoneyCopper" }) do
        local box = _G[name]
        if box then
            for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
                local art = _G[name .. suffix]
                if art then art:Hide() end
            end
            local fill = box:CreateTexture(nil, "BACKGROUND", nil, -8)
            fill:SetAllPoints()
            fill:SetColorTexture(0.224, 0.173, 0.129, 1)
        end
    end
    for _, radio in pairs({ SendMailSendMoneyButton, SendMailCODButton }) do
        local base, mark = radio:GetNormalTexture(), radio:GetCheckedTexture()
        if base and mark then
            base:ClearAllPoints()
            base:SetPoint("CENTER")
            base:SetSize(13, 13)
            base:SetColorTexture(0.12, 0.09, 0.07, 1)
            mark:ClearAllPoints()
            mark:SetPoint("CENTER")
            mark:SetSize(7, 7)
            mark:SetColorTexture(accent.r, accent.g, accent.b, 1)
        end
    end
    for _, scroll in pairs({ SendMailScrollFrame, OpenMailScrollFrame }) do
        local track = scroll.ScrollBar and scroll.ScrollBar.Track
        if track and track.Thumb and track.Thumb.CreateTexture then
            HideTextures(track)
            HideTextures(track.Thumb)
            local rail = track:CreateTexture(nil, "BACKGROUND")
            rail:SetAllPoints()
            rail:SetColorTexture(0.12, 0.09, 0.07, 1)
            local grip = track.Thumb:CreateTexture(nil, "ARTWORK")
            grip:SetAllPoints()
            grip:SetColorTexture(0.706, 0.604, 0.420, 1)
        end
    end
    if SendMailCancelButton then Place(SendMailCancelButton, SendMailFrame, "BOTTOMRIGHT", -12, 6, 68, 24) end
    if SendMailMailButton then Place(SendMailMailButton, SendMailFrame, "BOTTOMRIGHT", -86, 6, 80, 24) end
    for _, owner in pairs({ SendMailFrame, OpenMailFrame }) do
        -- The right halves of the ornamental separators are unnamed textures.
        for _, region in ipairs({ owner:GetRegions() }) do
            if region:IsObjectType("Texture") then
                local _, anchor = region:GetPoint(1)
                if anchor and (anchor == SendMailHorizontalBarLeft or anchor == SendMailHorizontalBarLeft2
                    or anchor == OpenMailHorizontalBarLeft) then region:Hide() end
            end
        end
    end
    for _, slot in ipairs(SendMailFrame.SendMailAttachments or {}) do
        for _, region in ipairs({ slot:GetRegions() }) do
            if region:IsObjectType("Texture") and region:GetDrawLayer() == "BACKGROUND"
                and region ~= slot:GetNormalTexture() then
                region:Hide()
            end
        end
        local outline = slot:CreateTexture(nil, "BACKGROUND", nil, -8)
        outline:SetPoint("TOPLEFT", slot, "TOPLEFT", -1, 1)
        outline:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 1, -1)
        outline:SetColorTexture(0.29, 0.23, 0.17, 1)
        local fill = slot:CreateTexture(nil, "BACKGROUND", nil, -7)
        fill:SetAllPoints(slot)
        fill:SetColorTexture(0.19, 0.15, 0.11, 1)
    end
end

local function InboxRow(row, button, first, fonts)
    if panels[row] or not button then return end
    panels[row] = true
    HideTextures(row)
    local fill = row:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", 0, -1)
    fill:SetPoint("BOTTOMRIGHT", 0, 1)
    fill:SetColorTexture(0.224, 0.173, 0.129, 1)
    local empty
    if first then
        empty = InboxFrame:CreateFontString(nil, "OVERLAY")
        empty:SetFontObject(fonts.normal)
        empty:SetPoint("CENTER")
        empty:SetText("No mail on this page")
    end
    local function Update()
        local occupied = button:IsShown()
        fill:SetShown(occupied)
        if empty then empty:SetShown(not occupied) end
    end
    button:HookScript("OnShow", Update)
    button:HookScript("OnHide", Update)
    Update()
end

function addon.ApplyMailTheme()
    if addon.IsBlizzardTheme() then return end
    if not MailFrame or not SendMailFrame then return end
    local fonts = addon.GetFonts()
    Window(MailFrame, fonts)
    Window(OpenMailFrame, fonts)
    if SendMailMoneyInset then SendMailMoneyInset:Hide() end
    if SendMailMoneyBg then SendMailMoneyBg:Hide() end

    -- Only known decorative frames are stripped. Do not recursively traverse
    -- item buttons, money frames, lock overlays, tooltips or warning textures.
    for _, name in ipairs({ "InboxFrameBg", "SendStationeryBackgroundLeft",
        "SendStationeryBackgroundRight", "OpenStationeryBackgroundLeft",
        "OpenStationeryBackgroundRight", "SendMailHorizontalBarLeft",
        "SendMailHorizontalBarLeft2", "OpenMailHorizontalBarLeft" }) do
        if _G[name] then _G[name]:Hide() end
    end
    Panel(SendMailScrollFrame, 0.224, 0.173, 0.129)
    Panel(OpenMailScrollFrame, 0.224, 0.173, 0.129)

    for _, name in ipairs({ "SendMailNameEditBox", "SendMailSubjectEditBox" }) do
        local box = _G[name]
        if box then
            Panel(box, 0.224, 0.173, 0.129)
            box:SetFontObject(fonts.small)
            Labels(box, fonts.small, true)
        end
    end
    -- Money editboxes can own denomination coin icons; retain their textures.
    for _, name in ipairs({ "SendMailMoneyGold", "SendMailMoneySilver", "SendMailMoneyCopper" }) do
        if _G[name] then _G[name]:SetFontObject(fonts.small) end
    end
    if SendMailBodyEditBox then SendMailBodyEditBox:SetFontObject(fonts.small) end
    if OpenMailBodyText then
        for _, tag in ipairs({ "p", "h1", "h2", "h3" }) do
            OpenMailBodyText:SetFontObject(tag, tag == "p" and fonts.small or fonts.normal)
            OpenMailBodyText:SetTextColor(tag, 0.933, 0.910, 0.863)
        end
    end
    -- Auction invoices use separate FontStrings rather than the HTML mail body.
    for _, name in ipairs({ "OpenMailInvoiceFrame", "OpenMailTransactionAmountMoneyFrame",
        "OpenMailDepositMoneyFrame", "OpenMailHouseCutMoneyFrame", "OpenMailSalePriceMoneyFrame",
        "ConsortiumMailFrame" }) do
        Labels(_G[name], fonts.normal, true)
    end
    Labels(SendMailFrame, fonts.small)
    Labels(SendMailCostMoneyFrame, fonts.small, true)
    Labels(OpenMailFrame, fonts.small)
    Labels(OpenMailSender, fonts.normal, true)
    for _, name in ipairs({ "SendMailMoneyText", "SendMailSendMoneyButtonText",
        "SendMailCODButtonText", "InboxCurrentPage", "OpenMailSubject",
        "OpenMailSenderLabel", "OpenMailSubjectLabel" }) do
        Text(_G[name], fonts.small, true)
    end
    for _, name in ipairs({ "OpenAllMail", "SendMailMailButton", "SendMailCancelButton",
        "OpenMailCancelButton", "OpenMailDeleteButton", "OpenMailReplyButton",
        "OpenMailReportSpamButton", "MailFrameTab1", "MailFrameTab2" }) do
        Button(_G[name], fonts)
    end
    if InboxFrame then
        Labels(InboxFrame.PrevPageButton, fonts.small, true)
        Labels(InboxFrame.NextPageButton, fonts.small, true)
    end
    for index = 1, 7 do
        local name = "MailItem" .. index
        local row = _G[name]
        if row then
            InboxRow(row, _G[name .. "Button"], index == 1, fonts)
            Text(_G[name .. "Sender"], fonts.normal)
            Text(_G[name .. "Subject"], fonts.small)
            -- Expiry is a tooltip-enabled button, not a decorative texture.
            local expiry = _G[name .. "ExpireTime"]
            if expiry then expiry:SetNormalFontObject(fonts.small) end
        end
    end
    if not hookedTabs then
        LayoutMailbox(fonts)
        hookedTabs = true
        hooksecurefunc("MailFrameTab_OnClick", UpdateTabs)
        if InboxFrame and InboxFrame.Update then hooksecurefunc(InboxFrame, "Update", InboxColors) end
    end
    InboxColors()
    UpdateTabs()
end
