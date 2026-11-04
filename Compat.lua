-------------------------------------
-- WoW Forever (1.60, 12.x engine) compatibility
-- Kept in the addon namespace so no globals are added for other addons.
-------------------------------------

local _, ns = ...

local compat = {}
ns.compat = compat

-- Secret values: unit data can be hidden from addons in restricted situations
-- (instances, PvP combat). Addon code may not compare or index with them.
local issecretvalue = issecretvalue or function() return false end
compat.issecret = issecretvalue

-- Returns the value, or nil if it is a secret the addon cannot use.
function compat.nosecret(v)
    if (issecretvalue(v)) then return nil end
    return v
end

-- True if any of the values is secret.
function compat.anysecret(...)
    for i = 1, select("#", ...) do
        if (issecretvalue((select(i, ...)))) then return true end
    end
    return false
end

compat.GetMouseFocus = GetMouseFocus or function()
    local foci = GetMouseFoci and GetMouseFoci()
    return foci and foci[1]
end

-- Forever characters have surnames: UnitName returns (firstName, surname) instead of
-- (name, realm). Returns the display name (with surname) and the realm, if any.
compat.hasSurnames = (NameUtil and NameUtil.FormatUnitNameForDisplay) and true or false

function compat.UnitNameAndRealm(unit)
    local name, second = UnitName(unit)
    if (compat.hasSurnames) then
        return NameUtil.FormatUnitNameForDisplay(unit), nil
    end
    return name, second
end

compat.GetItemInfo =GetItemInfo or C_Item.GetItemInfo
compat.GetItemInfoInstant = GetItemInfoInstant or C_Item.GetItemInfoInstant
compat.GetItemQualityColor = GetItemQualityColor or C_Item.GetItemQualityColor
compat.GetSpellTexture = GetSpellTexture or (C_Spell and C_Spell.GetSpellTexture)
compat.IsAddOnLoaded = IsAddOnLoaded or C_AddOns.IsAddOnLoaded

-- Quest level for a quest in the log (0 if unknown).
function compat.GetQuestLevel(questID)
    questID = tonumber(questID)
    if (not questID) then return 0 end
    if (C_QuestLog and C_QuestLog.GetLogIndexForQuestID) then
        local index = C_QuestLog.GetLogIndexForQuestID(questID)
        local info = index and C_QuestLog.GetInfo(index)
        if (info and info.level) then return info.level end
    elseif (GetQuestLogIndexByID) then
        local index = GetQuestLogIndexByID(questID)
        if (index and index > 0) then return select(2, GetQuestLogTitle(index)) or 0 end
    end
    return 0
end

-- Level colours use the vanilla rules. Forever loads Blizzard's retail GetCreatureDifficultyColor,
-- whose yellow band reaches -4 and whose green range is too short (a L16 mob is gray at L22).
-- Gray level as in vanilla (Warcraft Wiki "Mob experience", cmangos-classic Formulas.h).
function compat.GetGrayLevel(playerLevel)
    if (playerLevel <= 5) then return 0 end
    if (playerLevel <= 39) then return playerLevel - 5 - math.floor(playerLevel / 10) end
    if (playerLevel <= 59) then return playerLevel - 1 - math.floor(playerLevel / 5) end
    return playerLevel - 9
end

-- Colour for a mob or quest of the given level, relative to the player.
function compat.GetDifficultyColor(level)
    local playerLevel = UnitLevel("player")
    local levelDiff = level - playerLevel
    if (levelDiff >= 5) then
        return QuestDifficultyColors["impossible"]
    elseif (levelDiff >= 3) then
        return QuestDifficultyColors["verydifficult"]
    elseif (levelDiff >= -2) then
        return QuestDifficultyColors["difficult"]
    elseif (level > compat.GetGrayLevel(playerLevel)) then
        return QuestDifficultyColors["standard"]
    else
        return QuestDifficultyColors["trivial"]
    end
end

-- Register a tooltip post-call; falls back to the legacy OnTooltipSet* script.
function compat.AddTooltipPostCall(dataType, legacyScript, func)
    if (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType and Enum.TooltipDataType[dataType]) then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType[dataType], func)
        return true
    end
    if (legacyScript and GameTooltip:HasScript(legacyScript)) then
        GameTooltip:HookScript(legacyScript, function(self) func(self) end)
    end
end

-- Settings panel (replaces InterfaceOptions_AddCategory)
compat.categories = {}

function compat.AddOptionsCategory(frame, parentFrame)
    if (Settings and Settings.RegisterCanvasLayoutCategory) then
        local category
        if (parentFrame) then
            category = Settings.RegisterCanvasLayoutSubcategory(compat.categories[parentFrame], frame, frame.name)
        else
            category = Settings.RegisterCanvasLayoutCategory(frame, frame.name)
            Settings.RegisterAddOnCategory(category)
        end
        compat.categories[frame] = category
    elseif (InterfaceOptions_AddCategory) then
        InterfaceOptions_AddCategory(frame)
    end
end

function compat.OpenOptionsCategory(frame)
    local category = compat.categories[frame]
    if (category and Settings and Settings.OpenToCategory) then
        Settings.OpenToCategory(category:GetID())
    elseif (InterfaceOptionsFrame_OpenToCategory) then
        InterfaceOptionsFrame_OpenToCategory(frame)
        InterfaceOptionsFrame_OpenToCategory(frame)
    end
end

compat.OptionsPanelWidth = (InterfaceOptionsFramePanelContainer and InterfaceOptionsFramePanelContainer:GetWidth()) or 620

-- SetFont only accepts real flags here; "NONE"/"NORMAL" mean no flags.
function compat.FontFlag(flag)
    if (flag == "NONE" or flag == "NORMAL") then return "" end
    return flag
end
