
local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltip
local compat = select(2, ...).compat

local function ColorBorder(tip)
    if (addon.db.spell.borderColor) then
        LibEvent:trigger("tooltip.style.border.color", tip, unpack(addon.db.spell.borderColor))
    end
end

local function ColorBackground(tip)
    if (addon.db.spell.background) then
        LibEvent:trigger("tooltip.style.background", tip, unpack(addon.db.spell.background))
    end
end

local function SpellIcon(tip, id)
    if (addon.db.spell.showIcon) then
        id = id or (tip.GetSpell and compat.nosecret(select(2, tip:GetSpell())))
        local texture = id and compat.GetSpellTexture(id)
        local text = compat.nosecret(addon:GetLine(tip,1):GetText())
        if (texture and text and not strfind(text, "^|T")) then
            addon:GetLine(tip,1):SetFormattedText("|T%s:16:16:0:0:32:32:2:30:2:30|t %s", texture, text)
        end
    end
end

LibEvent:attachTrigger("tooltip:spell", function(self, tip, id)
    SpellIcon(tip, id)
    ColorBorder(tip)
    ColorBackground(tip)
end)
