
local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local DEAD = DEAD
local CopyTable = CopyTable

local addon = TinyTooltip
local compat = select(2, ...).compat
local issecret = compat.issecret

BigTipDB = {}
TinyTooltipCharacterDB = {}
local safecolor = addon.safecolor

-- The unit shown on GameTooltip (falls back to mouse focus / mouseover)
local function GetTooltipUnit()
    local unit = GameTooltip.GetUnit and select(2, GameTooltip:GetUnit())
    if (unit and not issecret(unit)) then return unit end
    local focus = compat.GetMouseFocus()
    if (focus and focus.unit and not issecret(focus.unit)) then return focus.unit end
    return "mouseover"
end

-- Health values are secret on this client: they are only passed straight to
-- widget/format APIs that accept secrets, never compared or computed on.
local function UpdateStatusBarText(self)
    local text = self.TextString
    if (self.forceHideText) then return text:Hide() end
    text:Show()
    local unit = GetTooltipUnit()
    if (not UnitExists(unit)) then return text:SetText("") end
    local maxhp = UnitHealthMax(unit)
    if (UnitIsDeadOrGhost(unit)) then
        text:SetFormattedText("|cff999999%s|r |cffffcc33<%s>|r", AbbreviateLargeNumbers(maxhp), DEAD)
    else
        text:SetFormattedText("%s / %s", AbbreviateLargeNumbers(UnitHealth(unit)), AbbreviateLargeNumbers(maxhp))
    end
end

local function ColorStatusBar(self, value)
    if (addon.db.general.statusbarColor == "auto") then
        local unit = GetTooltipUnit()
        if (addon:IsUnitRestricted(unit)) then return end
        local r, g, b
        if (UnitIsPlayer(unit)) then
            r, g, b = GetClassColor(select(2,UnitClass(unit)))
        else
            r, g, b = GameTooltip_UnitColor(unit)
            if (g == 0.6) then g = 0.9 end
            if (r==1 and g==1 and b==1) then r, g, b = 0, 0.9, 0.1 end
        end
        self:SetStatusBarColor(r, g, b)
    elseif (value and not issecret(value) and addon.db.general.statusbarColor == "smooth") then
        HealthBar_OnValueChanged(self, value, true)
    end
end

LibEvent:attachEvent("VARIABLES_LOADED", function()
    --CloseButton
    if (ItemRefCloseButton and not compat.IsAddOnLoaded("ElvUI")) then
        ItemRefCloseButton:SetSize(14, 14)
        ItemRefCloseButton:SetPoint("TOPRIGHT", -4, -4)
        ItemRefCloseButton:SetNormalTexture("Interface\\\Buttons\\UI-StopButton")
        ItemRefCloseButton:SetPushedTexture("Interface\\\Buttons\\UI-StopButton")
        ItemRefCloseButton:GetNormalTexture():SetVertexColor(0.9, 0.6, 0, 1.0)
    end
    --StatusBar
    local bar = GameTooltipStatusBar
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(1, 1, 1)
    bar.bg:SetVertexColor(0.2, 0.2, 0.2, 0.8)
    bar.TextString = bar:CreateFontString(nil, "OVERLAY")
    bar.TextString:SetPoint("CENTER")
    bar.TextString:SetFont(NumberFontNormal:GetFont(), 11, "THINOUTLINE")
    bar.capNumericDisplay = true
    bar.lockShow = 1
    bar:HookScript("OnShow", function(self)
        ColorStatusBar(self)
    end)
    bar:HookScript("OnValueChanged", function(self, hp)
        UpdateStatusBarText(self)
        ColorStatusBar(self, hp)
    end)
    bar:HookScript("OnShow", function(self)
        if (addon.db.general.statusbarHeight == 0) then
            self:Hide()
        end
    end)
    --Variable
    addon.db = addon:MergeVariable(addon.db, BigTipDB)
    if (addon.db.general.SavedVariablesPerCharacter) then
        local db = CopyTable(addon.db)
        addon.db = addon:MergeVariable(db, TinyTooltipCharacterDB)
    end
    LibEvent:trigger("tooltip:variables:loaded")
    --Init
    LibEvent:trigger("TINYTOOLTIP_GENERAL_INIT")
    --ShadowText
    GameTooltipHeaderText:SetShadowOffset(1, -1)
    GameTooltipHeaderText:SetShadowColor(0, 0, 0, 0.9)
    GameTooltipText:SetShadowOffset(1, -1)
    GameTooltipText:SetShadowColor(0, 0, 0, 0.9)
    Tooltip_Small:SetShadowOffset(1, -1)
    Tooltip_Small:SetShadowColor(0, 0, 0, 0.9)
end)

LibEvent:attachTrigger("tooltip:cleared, tooltip:hide", function(self, tip)
    LibEvent:trigger("tooltip.style.border.color", tip, unpack(addon.db.general.borderColor))
    LibEvent:trigger("tooltip.style.background", tip, unpack(addon.db.general.background))
    if (tip.BigFactionIcon) then tip.BigFactionIcon:Hide() end
    if tip.SetBackdrop then
        tip:SetBackdrop(nil)
    elseif tip.NineSlice then
        tip.NineSlice:Hide()
    end
end)

LibEvent:attachTrigger("tooltip:show", function(self, tip)
    if (tip ~= GameTooltip) then return end
    LibEvent:trigger("tooltip.statusbar.position", addon.db.general.statusbarPosition, addon.db.general.statusbarOffsetX, addon.db.general.statusbarOffsetY)
    local w = GameTooltipStatusBar.TextString:GetWidth()
    if (issecret(w)) then return end
    w = w + 10
    if (GameTooltipStatusBar:IsShown() and w > tip:GetWidth()) then
        tip:SetMinimumWidth(w+2)
        tip:Show()
    end
end)
