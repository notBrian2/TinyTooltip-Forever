
local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local LibSchedule = LibStub:GetLibrary("LibSchedule.7000")

local addon = TinyTooltip
local compat = select(2, ...).compat

-- The tooltip stays ANCHOR_NONE (as Blizzard leaves it) and this task moves it with the cursor.
-- ANCHOR_CURSOR made the engine re-place it on every rebuild, fighting this task (flicker), and
-- Blizzard only fades out a world tooltip it anchored itself, so ANCHOR_CURSOR ones never faded.
-- Stop once anything else re-anchors or re-owns the tooltip.
local function AnchorCursorOnExecute(self)
    if (not self.tip:IsShown()) then return true end
    if (self.tip.tinyAnchorGen ~= self.gen) then return true end
    if (self.tip:GetAnchorType() ~= "ANCHOR_NONE" or self.tip:GetOwner() ~= self.owner) then return true end
    local x, y = GetCursorPosition()
    self.tip:ClearAllPoints()
    self.tip:SetPoint(self.cp, UIParent, "BOTTOMLEFT", floor(x/self.scale+self.cx), floor(y/self.scale+self.cy))
end

local function AnchorCursor(tip, parent, cp, cx, cy)
    local x, y = GetCursorPosition()
    local scale = tip:GetEffectiveScale()
    cp, cx, cy = cp or "BOTTOM", cx or 0, cy or 20
    tip:ClearAllPoints()
    tip:SetPoint(cp, UIParent, "BOTTOMLEFT", floor(x/scale+cx), floor(y/scale+cy))
    LibSchedule:AddTask({
        identity = tostring(tip),
        elasped  = 0.01,
        expired  = math.huge,  -- runs until the tooltip hides or is re-anchored (it used to stop after 300 s)
        override = true,
        tip      = tip,
        cp       = cp,
        cx       = cx,
        cy       = cy,
        scale    = scale,
        gen      = tip.tinyAnchorGen,
        owner    = tip:GetOwner(),
        onExecute = AnchorCursorOnExecute,
    })
end

local function AnchorDefaultPosition(tip, parent, anchor, finally)
    if (finally) then
        LibEvent:trigger("tooltip.anchor.static", tip, parent, anchor.x, anchor.y)
    elseif (anchor.position == "inherit") then
        AnchorDefaultPosition(tip, parent, addon.db.general.anchor, true)
    else
        LibEvent:trigger("tooltip.anchor.static", tip, parent, anchor.x, anchor.y, anchor.p)
    end
end

-- "default <corner>": stay in Blizzard's tooltip area, pinned by that corner
local defaultCorners = {
    defaultTopLeft     = "TOPLEFT",
    defaultBottomLeft  = "BOTTOMLEFT",
    defaultTopRight    = "TOPRIGHT",
    defaultBottomRight = "BOTTOMRIGHT",
}

local function AnchorFrame(tip, parent, anchor, isUnitFrame, finally)
    if (not anchor) then return end
    if (anchor.hiddenInCombat and InCombatLockdown()) then
        return LibEvent:trigger("tooltip.anchor.none", tip, parent)
    end
    if (anchor.returnInCombat and InCombatLockdown()) then return AnchorDefaultPosition(tip, parent, anchor, finally) end
    if (anchor.returnOnUnitFrame and isUnitFrame) then return AnchorDefaultPosition(tip, parent, anchor, finally) end
    if (anchor.position == "cursorRight") then
        LibEvent:trigger("tooltip.anchor.cursor.right", tip, parent)
    elseif (anchor.position == "cursor") then
        LibEvent:trigger("tooltip.anchor.cursor", tip, parent)
        AnchorCursor(tip, parent, anchor.cp, anchor.cx, anchor.cy)
    elseif (anchor.position == "inherit" and not finally) then
        AnchorFrame(tip, parent, addon.db.general.anchor, isUnitFrame, true)
    elseif (anchor.position == "static") then
        LibEvent:trigger("tooltip.anchor.static", tip, parent, anchor.x, anchor.y, anchor.p)
    elseif (defaultCorners[anchor.position]) then
        LibEvent:trigger("tooltip.anchor.default.corner", tip, parent, defaultCorners[anchor.position])
    end
end

LibEvent:attachTrigger("tooltip:anchor", function(self, tip, parent)
    if (tip ~= GameTooltip) then return end
    tip.tinyAnchorGen = (tip.tinyAnchorGen or 0) + 1
    local unit
    local focus = compat.GetMouseFocus()
    local isUnitFrame = false
    if (focus and focus.unit) then
        unit = focus.unit
        isUnitFrame = true
    end
    if (not unit and focus and focus.GetAttribute) then
        unit = focus:GetAttribute("unit")
    end
    if (not unit) then
        unit = "mouseover"
    end
    if (compat.issecret(unit)) then unit = "mouseover" end
    if (UnitIsPlayer(unit)) then
        AnchorFrame(tip, parent, addon.db.unit.player.anchor, isUnitFrame)
    elseif (UnitExists(unit)) then
        AnchorFrame(tip, parent, addon.db.unit.npc.anchor, isUnitFrame)
    else
        AnchorFrame(tip, parent, addon.db.general.anchor, isUnitFrame)
    end
end)
