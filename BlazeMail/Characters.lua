local _, addon = ...

local function IsReadable(value)
    return not issecretvalue or not issecretvalue(value)
end

-- Longest suffix first: RP PvP must not become ordinary PvP.
local rulesets = { "RP PvP", "RP", "PvP", "PvE" }
function addon.NormalizeRuleset(connectionName)
    if not IsReadable(connectionName) or type(connectionName) ~= "string" then return end
    connectionName = connectionName:match("^%s*(.-)%s*$")
    for _, ruleset in ipairs(rulesets) do
        if connectionName == ruleset or connectionName:sub(-(#ruleset + 1)) == " " .. ruleset then
            return ruleset
        end
    end
end

function addon.MigrateRulesets()
    -- Convert labels saved by earlier versions; live realm names use RP/RP PvP.
    local legacyRulesets = { ["Roleplay"] = "RP", ["PvP Roleplay"] = "RP PvP",
        ["Roleplay PvP"] = "RP PvP" }
    for _, character in pairs(BlazeMailDB.characters) do
        local ruleset = legacyRulesets[character.ruleset] or addon.NormalizeRuleset(character.ruleset)
        if ruleset then character.ruleset = ruleset end
    end
end

function addon.DiscoverCharacter()
    local firstName, surname = UnitNameUnmodified("player")
    local guid = UnitGUID("player")
    local _, class = UnitClass("player")
    local faction = UnitFactionGroup("player")
    local region = GetCurrentRegion()
    -- Example verified in game: "CAMWOW EU4 Realm 7 PvE". The numbered
    -- connection is not the ruleset; only its recognized suffix is relevant.
    local ruleset = GetRealmName()
    local values = { firstName, surname, guid, class, faction, region, ruleset }
    for i = 1, 7 do
        if not IsReadable(values[i]) then return end
    end
    ruleset = addon.NormalizeRuleset(ruleset)
    if not firstName or firstName == "" or not guid or not class
        or (faction ~= "Horde" and faction ~= "Alliance")
        or not region or not ruleset or ruleset == "" then
        return
    end

    -- Camelot's NameUtil confirms the second return is the surname. Some name
    -- paths can already include it in the first return; avoid duplicating it.
    local fullName = firstName
    if surname and surname ~= "" then
        local suffix = fullName:sub(-(#surname + 1))
        if suffix == "-" .. surname or suffix == " " .. surname then
            fullName = fullName:sub(1, -(#surname + 2))
        end
        fullName = fullName .. " " .. surname
    end
    -- Refresh identity without overwriting the user's favorite or note.
    local character = BlazeMailDB.characters[guid] or {}
    character.guid, character.name, character.class = guid, fullName, class
    character.faction, character.region, character.ruleset = faction, region, ruleset
    BlazeMailDB.characters[guid] = character
    addon.current = character
    return true
end

function addon.GetCharacters(manage, query)
    local entries = {}
    local current = addon.current
    query = (query or ""):match("^%s*(.-)%s*$"):lower()
    for id, character in pairs(BlazeMailDB.characters) do
        local eligible = manage or (current and id ~= current.guid
            and character.region == current.region
            and character.ruleset == current.ruleset
            and character.faction == current.faction)
        if eligible and (query == "" or character.name:lower():find(query, 1, true)) then
            entries[#entries + 1] = { id = id, character = character }
        end
    end
    table.sort(entries, function(a, b)
        local x, y = a.character, b.character
        if x.region ~= y.region then return x.region < y.region end
        if x.ruleset ~= y.ruleset then return x.ruleset < y.ruleset end
        if x.faction ~= y.faction then return x.faction < y.faction end
        local xFavorite, yFavorite = x.favorite == true, y.favorite == true
        if xFavorite ~= yFavorite then return xFavorite end
        if x.name ~= y.name then return x.name < y.name end
        return a.id < b.id
    end)
    return entries
end

function addon.ToggleFavorite(id)
    local character = BlazeMailDB.characters[id]
    if character then character.favorite = not character.favorite or nil end
end

function addon.SetNote(id, note)
    local character = BlazeMailDB.characters[id]
    if character then
        note = note:match("^%s*(.-)%s*$")
        character.note = note ~= "" and note or nil
    end
end

function addon.RemoveCharacter(id)
    BlazeMailDB.characters[id] = nil
end
