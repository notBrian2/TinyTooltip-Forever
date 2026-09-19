local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltip
local compat = select(2, ...).compat
local nosecret = compat.nosecret

local function ParseHyperLink(link)
    local name, value = string.match(link or "", "|?H(%a+):(%d+):")
    if (name and value) then
        return name:gsub("^([a-z])", strupper), value
    end
end

local function ShowId(tooltip, name, value, noBlankLine)
    value = nosecret(value)
    if (not name or not value or (tooltip.IsForbidden and tooltip:IsForbidden())) then return end
    if (IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() or addon.db.general.alwaysShowIdInfo) then
        local line = addon:FindLine(tooltip, name)
        if (not line) then
            if (not noBlankLine) then tooltip:AddLine(" ") end
            tooltip:AddLine(format("%s: |cffffffff%s|r", name, value), 0, 1, 0.8)
            tooltip:Show()
        end
        LibEvent:trigger("tooltip.linkid", tooltip, name, value, noBlankLine)
    end
end

local function ShowLinkIdInfo(tooltip, link)
    link = nosecret(link) or (tooltip.GetItem and nosecret(select(2, tooltip:GetItem())))
    ShowId(tooltip, ParseHyperLink(link))
end

-- keystone
local function KeystoneAffixDescription(self, link)
    link = nosecret(link) or (self.GetItem and nosecret(select(2, self:GetItem())))
    local data, name, description, AffixID
    if (link and C_ChallengeMode and C_ChallengeMode.GetAffixInfo and strfind(link, "keystone:")) then
        link = link:gsub("|H(keystone:.-)|.+", "%1")
        data = {strsplit(":", link)}
        self:AddLine(" ")
        for i = 5, 8 do
            AffixID = tonumber(data[i])
            if (AffixID and AffixID > 0) then
                name, description = C_ChallengeMode.GetAffixInfo(AffixID)
                if (name and description) then
                    self:AddLine(format("|cffffcc33%s:|r%s", name, description), 0.1, 0.9, 0.1, true)
                end
            end
        end
        self:Show()
    end
end
-- Item (TooltipDataProcessor covers GameTooltip, ItemRef and shopping tooltips)
local itemTips = {}
for _, tip in ipairs({GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2, ItemRefShoppingTooltip1, ItemRefShoppingTooltip2}) do
    itemTips[tip] = true
end
compat.AddTooltipPostCall("Item", "OnTooltipSetItem", function(self)
    if (not itemTips[self]) then return end
    if (self == GameTooltip) then KeystoneAffixDescription(self) end
    ShowLinkIdInfo(self)
end)
hooksecurefunc(ItemRefTooltip, "SetHyperlink", KeystoneAffixDescription)
hooksecurefunc(GameTooltip, "SetHyperlink", ShowLinkIdInfo)
hooksecurefunc(ItemRefTooltip, "SetHyperlink", ShowLinkIdInfo)
hooksecurefunc("SetItemRef", function(link) ShowLinkIdInfo(ItemRefTooltip, link) end)

-- Spell / aura (the tooltip data carries the spell id)
local function ShowSpellId(self, data)
    if (self ~= GameTooltip or not data) then return end
    ShowId(self, "Spell", data.id)
end
compat.AddTooltipPostCall("Spell", nil, ShowSpellId)
compat.AddTooltipPostCall("UnitAura", nil, ShowSpellId)
if (GameTooltip.SetArtifactPowerByID) then
    hooksecurefunc(GameTooltip, "SetArtifactPowerByID", function(self, powerID)
        ShowId(self, "Power", powerID)
        ShowId(self, "Spell", C_ArtifactUI.GetPowerInfo(powerID).spellID, 1)
    end)
end

-- Quest
if (QuestMapLogTitleButton_OnEnter) then
    hooksecurefunc("QuestMapLogTitleButton_OnEnter", function(self)
        if (self.questID) then ShowId(GameTooltip, "Quest", self.questID) end
    end)
end

-- Achievement UI
local function ShowAchievementId(self)
    if ((IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() or addon.db.general.alwaysShowIdInfo) and self.id) then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, -32)
        GameTooltip:SetText("|cffffdd22Achievement:|r " .. self.id, 0, 1, 0.8)
        GameTooltip:Show()
    end
end

if (HybridScrollFrame_CreateButtons) then
    hooksecurefunc("HybridScrollFrame_CreateButtons", function(self, buttonTemplate)
        if (buttonTemplate == "StatTemplate") then
            for _, button in pairs(self.buttons) do
                button:HookScript("OnEnter", ShowAchievementId)
            end
        elseif (buttonTemplate == "AchievementTemplate") then
            for _, button in pairs(self.buttons) do
                button:HookScript("OnEnter", ShowAchievementId)
                button:HookScript("OnLeave", GameTooltip_Hide)
            end
        end
    end)
end
