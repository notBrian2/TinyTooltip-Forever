
local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local AFK = AFK
local DND = DND
local PVP = PVP
-- the tooltip's own PvP line says "PvP"; Forever's PVP string is "Player vs. Player"
local PVP_LINE = PVP_ENABLED or "PvP"
local LEVEL = LEVEL
local OFFLINE = FRIENDS_LIST_OFFLINE
local FACTION_HORDE = FACTION_HORDE
local FACTION_ALLIANCE = FACTION_ALLIANCE

local addon = TinyTooltip
local nosecret = select(2, ...).compat.nosecret

local function strip(text)
    return (text:gsub("%s+([|%x%s]+)<trim>", "%1"))
end

local function ColorBorder(tip, config, raw)
    if (config.coloredBorder and addon.colorfunc[config.coloredBorder]) then
        local r, g, b = addon.colorfunc[config.coloredBorder](raw)
        LibEvent:trigger("tooltip.style.border.color", tip, r, g, b)
    elseif (type(config.coloredBorder) == "string" and config.coloredBorder ~= "default") then
        local r, g, b = addon:GetRGBColor(config.coloredBorder)
        if (r and g and b) then
            LibEvent:trigger("tooltip.style.border.color", tip, r, g, b)
        end
    else
        LibEvent:trigger("tooltip.style.border.color", tip, unpack(addon.db.general.borderColor))
    end
end

local function ColorBackground(tip, config, raw)
    local bg = config.background
    if not bg then return end
    if (bg.colorfunc == "default" or bg.colorfunc == "" or bg.colorfunc == "inherit") then
        local r, g, b, a = unpack(addon.db.general.background)
        a = tonumber(bg.alpha) or a  -- older versions saved the slider value as a string
        LibEvent:trigger("tooltip.style.background", tip, r, g, b, a)
        return
    end
    if (addon.colorfunc[bg.colorfunc]) then
        local r, g, b = addon.colorfunc[bg.colorfunc](raw)
        local a = tonumber(bg.alpha) or 0.8
        LibEvent:trigger("tooltip.style.background", tip, r, g, b, a)
    end
end

local function GrayForDead(tip, config, unit)
    if (config.grayForDead and UnitIsDeadOrGhost(unit)) then
        local line, text
        LibEvent:trigger("tooltip.style.border.color", tip, 0.6, 0.6, 0.6)
        LibEvent:trigger("tooltip.style.background", tip, 0.1, 0.1, 0.1)
        for i = 1, tip:NumLines() do
            line = _G[tip:GetName() .. "TextLeft" .. i]
            text = nosecret(line:GetText())
            if (text) then
                line:SetTextColor(0.7, 0.7, 0.7)
                line:SetText((text:gsub("|cff%x%x%x%x%x%x", "|cffaaaaaa")))
            end
        end
    end
end

local function ShowBigFactionIcon(tip, config, raw)
    if (config.elements.factionBig and config.elements.factionBig.enable and tip.BigFactionIcon and (raw.factionGroup=="Alliance" or raw.factionGroup == "Horde")) then
        tip.BigFactionIcon:Show()
        tip.BigFactionIcon:SetTexture("Interface\\Timer\\".. raw.factionGroup .."-Logo")
        tip:Show()
        tip:SetMinimumWidth(tip:GetWidth() + 20)
    end
end

-- Blizzard's own unit lines (level, class, faction, creature type, PvP), compared without color
-- codes. Forever puts some of these on lines of their own, below the rows TinyTooltip writes.
local function IsDefaultUnitLine(text, defaults)
    text = strtrim((text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
    return defaults[text] or defaults[(text:match("^%((.+)%)$"))] or strfind(text, "^"..LEVEL) ~= nil
end

-- Hides every default unit line after the first `rows` lines. Returns true if any was hidden.
local function HideDefaultUnitLines(tip, rows, defaults)
    local hidden = false
    for i = rows + 1, tip:NumLines() do
        local line = _G[tip:GetName() .. "TextLeft" .. i]
        local text = nosecret(line:GetText())
        if (text and text ~= "" and IsDefaultUnitLine(text, defaults)) then
            line:SetText(nil)
            hidden = true
        end
    end
    return hidden
end

-- Remembers which lines TinyTooltip wrote and which default texts to hide below them,
-- so the OnUpdate check below can hide lines the client adds later.
local function SetDefaultUnitLines(tip, rows, ...)
    local defaults = tip.tinyUnitDefaults or {}
    wipe(defaults)
    defaults[PVP], defaults[PVP_LINE], defaults["PvP"] = true, true, true
    for i = 1, select("#", ...) do
        local text = nosecret((select(i, ...)))
        if (type(text) == "string" and text ~= "") then defaults[text] = true end
    end
    tip.tinyUnitRows, tip.tinyUnitDefaults = rows, defaults
    HideDefaultUnitLines(tip, rows, defaults)
end

local function PlayerCharacter(tip, unit, config, raw)
    local data = addon:GetUnitData(unit, config.elements, raw)
    addon:HideLines(tip, 2, 3)
    addon:HideLine(tip, "^"..LEVEL)
    addon:HideLine(tip, "^"..FACTION_ALLIANCE)
    addon:HideLine(tip, "^"..FACTION_HORDE)
    addon:HideLine(tip, "^"..PVP)
    for i, v in ipairs(data) do
        addon:GetLine(tip,i):SetText(strip(table.concat(v, " ")))
    end
    SetDefaultUnitLines(tip, #data, raw.className, FACTION_ALLIANCE, FACTION_HORDE)
    ColorBorder(tip, config, raw)
    ColorBackground(tip, config, raw)
    GrayForDead(tip, config, unit)
    ShowBigFactionIcon(tip, config, raw)
end

local function NonPlayerCharacter(tip, unit, config, raw)
    local levelLine = addon:FindLine(tip, "^"..LEVEL)
    local rows = 1
    if (levelLine or tip:NumLines() > 1) then
        local data = addon:GetUnitData(unit, config.elements, raw)
        local titleLine = addon:GetNpcTitle(tip)
        local increase = 0
        for i, v in ipairs(data) do
            if (i == 1) then
                addon:GetLine(tip,i):SetText(table.concat(v, " "))
            end
            if (i == 2) then
                if (config.elements.npcTitle.enable and titleLine) then
                    titleLine:SetText(addon:FormatData(titleLine:GetText(), config.elements.npcTitle, raw))
                    increase = 1
                end
                i = i + increase
                addon:GetLine(tip,i):SetText(table.concat(v, " "))
            elseif ( i > 2) then
                i = i + increase
                addon:GetLine(tip,i):SetText(table.concat(v, " "))
            end
        end
        rows = #data + increase
    end
    addon:HideLine(tip, "^"..LEVEL)
    addon:HideLine(tip, "^"..PVP)
    -- Forever shows the creature type (and classification) on a line of its own
    SetDefaultUnitLines(tip, rows, raw.creature, raw.classifBoss, raw.classifElite, raw.classifRare)
    ColorBorder(tip, config, raw)
    ColorBackground(tip, config, raw)
    GrayForDead(tip, config, unit)
    ShowBigFactionIcon(tip, config, raw)
end

-- In case the client adds default lines after the tooltip was built, check again on each tick.
LibEvent:attachTrigger("tooltip:cleared, tooltip:hide", function(self, tip)
    tip.tinyUnitRows = nil
end)

GameTooltip:HookScript("OnUpdate", function(self, elapsed)
    if (not self.tinyUnitRows or not self:GetUnit()) then return end
    self.tinyCleanupElapsed = (self.tinyCleanupElapsed or 0) + elapsed
    if (self.tinyCleanupElapsed < 0.2) then return end
    self.tinyCleanupElapsed = 0
    if (HideDefaultUnitLines(self, self.tinyUnitRows, self.tinyUnitDefaults)) then
        self:Show()
    end
end)

LibEvent:attachTrigger("tooltip:unit", function(self, tip, unit)
    tip.tinyUnitRows = nil
    local raw = addon:GetUnitInfo(unit)
    if (UnitIsPlayer(unit)) then
        PlayerCharacter(tip, unit, addon.db.unit.player, raw)
    else
        NonPlayerCharacter(tip, unit, addon.db.unit.npc, raw)
    end
end)

addon.ColorUnitBorder = ColorBorder
addon.ColorUnitBackground = ColorBackground
