
local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltip

-- Mobs whose model is too big for the box: NPC ID -> camera pull-back (1 = normal).
local modelZoom = {
    [5523] = 2.0,   -- War Party Kodo
}

local function NpcID(unit)
    local guid = UnitGUID(unit)
    if (not guid or (issecretvalue and issecretvalue(guid))) then return end
    return tonumber((select(6, strsplit("-", guid))))
end

-- The model loads after SetUnit returns and can reset the camera, so this runs
-- again from OnModelLoaded.
local function ApplyZoom(model)
    if (model.SetCamDistanceScale) then
        model:SetCamDistanceScale(model.zoom or 1)
    end
end

LibEvent:attachTrigger("tooltip:init", function(self, tip)
    if (tip ~= GameTooltip) then return end
    if (not tip.model) then
        tip.model = CreateFrame("PlayerModel", nil, tip)
        tip.model:SetSize(100, 100)
        tip.model:SetFacing(-0.25)
        tip.model:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", 8, -16)
        tip.model:Hide()
        tip.model:SetScript("OnUpdate", function(self, elapsed)
            if (IsControlKeyDown() or IsAltKeyDown()) then
                self:SetFacing(self:GetFacing() + math.pi * elapsed)
            end
        end)
        if (tip.model:HasScript("OnModelLoaded")) then
            tip.model:HookScript("OnModelLoaded", ApplyZoom)
        end
    end
end)

-- Unit frames rebuild their tooltip several times a second (ClearLines, then the unit again).
-- Reloading the model each time reset its facing, so the ALT/CTRL spin jerked back to the start.
-- A rebuild for the same unit keeps the loaded model; the clear only takes effect if no unit
-- follows in the same frame.
local function ModelKey(unit)
    local guid = UnitGUID(unit)
    if (not guid or (issecretvalue and issecretvalue(guid))) then return end
    return guid
end

local function ShowModel(model, unit, zoom)
    model.stale = nil
    local key = ModelKey(unit)
    if (key and key == model.key and model:IsShown()) then return end
    model.key = key
    model.zoom = zoom
    model:SetUnit(unit)
    model:SetFacing(-0.25)
    ApplyZoom(model)
    model:Show()
end

local function ClearModel(model)
    model.stale, model.key = nil, nil
    model:ClearModel()
    model:Hide()
end

LibEvent:attachTrigger("tooltip:unit", function(self, tip, unit)
    if (tip ~= GameTooltip) then return end
    if (not UnitIsVisible(unit)) then return end
    if (addon.db.unit.player.showModel and UnitIsPlayer(unit)) then
        ShowModel(tip.model, unit, nil)
    elseif (addon.db.unit.npc.showModel and not UnitIsPlayer(unit)) then
        ShowModel(tip.model, unit, modelZoom[NpcID(unit)])
    else
        ClearModel(tip.model)
    end
end)

LibEvent:attachTrigger("tooltip:cleared", function(self, tip)
    if (tip ~= GameTooltip or not tip.model) then return end
    tip.model.stale = true
    C_Timer.After(0, function()
        if (tip.model.stale) then ClearModel(tip.model) end
    end)
end)

LibEvent:attachTrigger("tooltip:hide", function(self, tip)
    if (tip ~= GameTooltip or not tip.model) then return end
    ClearModel(tip.model)
end)
