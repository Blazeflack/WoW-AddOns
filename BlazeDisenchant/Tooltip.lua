local addonName, addon = ...

function addon.eligible(class, quality)
    return not issecretvalue(class) and not issecretvalue(quality)
        and addon.rows[class] and addon.rows[class][quality]
end

local function addEstimate(tooltip, data)
    if issecretvalue(data) or (data and issecretvalue(data.id)) then return end
    if data and tooltip.GetPrimaryTooltipData and tooltip:GetPrimaryTooltipData() ~= data then return end
    if not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    if issecretvalue(link) or not link then return end
    local _, _, quality, _, _, _, _, _, _, _, _, class = C_Item.GetItemInfo(link)
    local rows = addon.eligible(class, quality)
    if not rows then return end
    local level = C_Item.GetDetailedItemLevelInfo(link)
    if issecretvalue(level) or not level then return end

    for _, row in ipairs(rows) do
        if level >= row[1] and level <= row[2] then
            local materials, byID = {}, {}
            local weight = 0
            for i = 3, #row, 3 do
                local chance, count, id = row[i], row[i + 1], row[i + 2]
                weight = weight + chance
                local mat = byID[id]
                if not mat then
                    mat = { id = id, chance = 0, expected = 0, low = count, high = count }
                    materials[#materials + 1], byID[id] = mat, mat
                end
                mat.chance = mat.chance + chance
                mat.expected = mat.expected + chance * count / 100
                mat.low, mat.high = math.min(mat.low, count), math.max(mat.high, count)
            end
            local heading = weight == 100 and "Disenchant (Classic estimate)" or "Disenchant (Classic, normalized)"
            tooltip:AddLine(heading, 0.45, 0.85, 1)
            local api = Auctionator and Auctionator.API and Auctionator.API.v1
            local getPrice = api and api.GetAuctionPriceByItemID
            local total = 0
            for _, mat in ipairs(materials) do
                local name = C_Item.GetItemInfo(mat.id)
                if issecretvalue(name) or not name then name = "Item #" .. mat.id end
                local count = mat.low == mat.high and mat.low or mat.low .. "-" .. mat.high
                tooltip:AddDoubleLine(name, ("%.1f%%  x%s"):format(mat.chance * 100 / weight, count), 1, 1, 1, 1, 1, 1)
                local price = getPrice and getPrice(addonName, mat.id)
                if total and price then total = total + price * mat.expected else total = nil end
            end
            if total then
                local copper = math.floor(total * 100 / weight + 0.5)
                tooltip:AddDoubleLine("DE value (Auctionator)", ("%dg %ds %dc"):format(
                    math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100))
            end
            return
        end
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addEstimate)
else
    for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tooltip.HasScript and tooltip:HasScript("OnTooltipSetItem") then
            tooltip:HookScript("OnTooltipSetItem", function(tip) addEstimate(tip) end)
        end
    end
end
