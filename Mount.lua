
local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local LibSchedule = LibStub:GetLibrary("LibSchedule.7000")

local mounts = {}
local compat = select(2, ...).compat

if (not C_MountJournal) then return end

local function GetAllMountSource()
    local mountIDs = C_MountJournal.GetMountIDs()
    local _, spellID, isCollected, source
    if (not mountIDs or #mountIDs == 0) then return end
    for i, mountID in ipairs(mountIDs) do
        _, spellID, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        _, _, source = C_MountJournal.GetMountInfoExtraByID(mountID)
        if (spellID) then mounts[spellID] = {
            source = source,
            isCollected = isCollected,
        } end
    end
    if (next(mounts)) then return true end
end

LibEvent:attachEvent("VARIABLES_LOADED", function()
    LibSchedule:AddTask({
        identity = "GetAllMountSource",
        elasped  = 10,
        begined  = GetTime() + 10,
        expired  = GetTime() + 100,
        override = true,
        onExecute = GetAllMountSource,
    })
end)

compat.AddTooltipPostCall("UnitAura", nil, function(self, data)
    if (self ~= GameTooltip or not data) then return end
    local spellID = compat.nosecret(data.id)
    if (spellID and mounts[spellID]) then
        self:AddLine(" ")
        if (mounts[spellID].isCollected) then
            self:AddDoubleLine(mounts[spellID].source, COLLECTED, 1, 1, 1, 0.1, 1, 0.1)
        else
            self:AddLine(mounts[spellID].source, 1, 1, 1)
        end
        self:Show()
    end
end)
