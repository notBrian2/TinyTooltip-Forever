
local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltip
local compat = select(2, ...).compat
local GetItemInfo = compat.GetItemInfo
local GetItemQualityColor = compat.GetItemQualityColor

local function ColorBorder(tip, r, g, b)
    if (addon.db.item.coloredItemBorder) then
        LibEvent:trigger("tooltip.style.border.color", tip, r, g, b)
    else
        LibEvent:trigger("tooltip.style.border.color", tip, unpack(addon.db.general.borderColor))
    end
end

local function ItemIcon(tip, link)
    if (addon.db.item.showItemIcon) then
        local texture = select(10, GetItemInfo(link))
        local text = compat.nosecret(addon:GetLine(tip,1):GetText())
        if (texture and text and not strfind(text, "^|T")) then
            addon:GetLine(tip,1):SetFormattedText("|T%s:16:16:0:0:32:32:2:30:2:30|t %s", texture, text)
        end
    end
end

local function ItemStackCount(tip, link)
    if (addon.db.item.showStackCount) then
        local stackCount = select(8, GetItemInfo(link))
        local text = compat.nosecret(addon:GetLine(tip,1):GetText())
        if (text and stackCount and stackCount > 1) then
            addon:GetLine(tip,1):SetText(text .. format(" |cff00eeee/%s|r", stackCount))
        end
    end
end

LibEvent:attachTrigger("tooltip:item", function(self, tip, link)
    local quality = select(3, GetItemInfo(link)) or 0
    local r, g, b = GetItemQualityColor(quality)
    ColorBorder(tip, r, g, b)
    ItemStackCount(tip, link)
    ItemIcon(tip, link)
end)

if (EmbeddedItemTooltip_OnTooltipSetItem) then hooksecurefunc("EmbeddedItemTooltip_OnTooltipSetItem", function(self)
    local tip = self:GetParent()
    if (not tip or tip:GetObjectType() ~= "GameTooltip") then return end
    local r, g, b = self.IconBorder:GetVertexColor()
    ColorBorder(tip, r, g, b)
end) end
