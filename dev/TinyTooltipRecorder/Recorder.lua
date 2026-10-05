-------------------------------------
-- TinyTooltip Recorder (dev only, never shipped)
-- Logs what GameTooltip and TinyTooltip do into TinyTooltipRecordDB, so a play session can be
-- analysed offline instead of through screenshots: the client's raw tooltip lines and their
-- data types, TinyTooltip's final lines, owner/anchor/points, SetWorldCursor, FadeOut, Hide,
-- every Show and who called it, and the tooltip's shown/alpha state over time.
-- A small panel walks through a checklist and switches TinyTooltip's Position for some steps;
-- the original Position settings are put back on Finish, on logout, and after a crash.
-- /ttrec opens the panel.
-------------------------------------

local issecret = issecretvalue or function() return false end
local GetNow = GetTimePreciseSec or GetTime
local MAX_EVENTS = 40000

local rec            -- the current session table (inside TinyTooltipRecordDB.sessions)
local recording = false
local step = 0
local t0 = 0
local fading = false
local cur            -- the tooltip build being recorded
local lastBuildKey, lastBuild

-------------------------------------
-- values that may be secret or frames
-------------------------------------

local function S(v)
    if (v == nil) then return nil end
    if (issecret(v)) then return "<secret>" end
    local t = type(v)
    if (t == "string" or t == "number" or t == "boolean") then return v end
    if (t == "table" and v.GetDebugName) then
        local ok, name = pcall(v.GetDebugName, v)
        if (ok and name and not issecret(name)) then return name end
        return "<frame>"
    end
    return tostring(v)
end

local function R(v)
    v = S(v)
    if (type(v) == "number") then return floor(v * 10 + 0.5) / 10 end
    return v
end

local function Now()
    return floor((GetNow() - t0) * 1000 + 0.5) / 1000
end

-- the first caller outside this file and outside C: "TinyTooltip/Unit.lua:174"
local function Caller()
    local stack = debugstack(2, 10, 0) or ""
    for line in stack:gmatch("[^\n]+") do
        if (not line:find("TinyTooltipRecorder", 1, true) and not line:find("^%[C%]")) then
            local file, num = line:match("AddOns/(.-)\"%]:(%d+)")
            if (file) then return file .. ":" .. num end
            file, num = line:match("AddOns\\(.-)\"%]:(%d+)")
            if (file) then return file:gsub("\\", "/") .. ":" .. num end
            return (line:sub(1, 80))
        end
    end
end

local function Push(e, collapseKey)
    if (not recording) then return end
    local events = rec.events
    local last = events[#events]
    if (collapseKey and last and last.ck == collapseKey) then
        last.n = (last.n or 1) + 1
        last.t2 = Now()
        return last
    end
    e.t = e.t or Now()
    e.step = step
    e.ck = collapseKey
    events[#events + 1] = e
    if (#events >= MAX_EVENTS) then
        recording = false
        print("|cffff6600TinyTooltip Recorder:|r event limit reached, recording stopped. Type /reload to save it.")
    end
    return e
end

local function Lines()
    local lines = {}
    for i = 1, GameTooltip:NumLines() do
        local left = _G["GameTooltipTextLeft" .. i]
        local right = _G["GameTooltipTextRight" .. i]
        local r = right and right:IsShown() and S(right:GetText()) or nil
        lines[i] = { S(left:GetText()), r, (not left:IsShown()) or nil }
    end
    return lines
end

local function LinesKey(lines)
    local parts = {}
    for i, l in ipairs(lines) do parts[i] = tostring(l[1]) .. "|" .. tostring(l[2]) .. "|" .. tostring(l[3]) end
    return table.concat(parts, "\n")
end

local function Point()
    local p, relTo, relP, x, y = GameTooltip:GetPoint(1)
    if (not p) then return nil end
    return { S(p), S(relTo), S(relP), R(x), R(y) }
end

local function Focus()
    local foci = GetMouseFoci and GetMouseFoci()
    return foci and S(foci[1])
end

-------------------------------------
-- TinyTooltip settings: snapshot, Position switching, restore
-------------------------------------

local function Copy(v, depth)
    if (type(v) ~= "table") then
        local t = type(v)
        if (t == "string" or t == "number" or t == "boolean") then return v end
        return nil
    end
    if (depth > 8) then return nil end
    local out = {}
    for k, val in pairs(v) do
        if (type(k) == "string" or type(k) == "number") then out[k] = Copy(val, depth + 1) end
    end
    return out
end

local ANCHOR_PATHS = { "general", "player", "npc" }
local function AnchorTable(which)
    local db = TinyTooltip and TinyTooltip.db
    if (not db) then return end
    if (which == "general") then return db.general and db.general.anchor end
    return db.unit and db.unit[which] and db.unit[which].anchor
end

local function SaveAnchors()
    local saved = {}
    for _, which in ipairs(ANCHOR_PATHS) do
        local t = AnchorTable(which)
        if (t) then saved[which] = Copy(t, 0) end
    end
    TinyTooltipRecordDB.restore = saved
end

local function RestoreAnchors()
    local saved = TinyTooltipRecordDB and TinyTooltipRecordDB.restore
    if (not saved) then return end
    for which, values in pairs(saved) do
        local t = AnchorTable(which)
        if (t) then
            wipe(t)
            for k, v in pairs(values) do t[k] = v end
        end
    end
    TinyTooltipRecordDB.restore = nil
end

-- Put every Position on `mode` (player and NPC inherit the general one).
local function ApplyMode(mode)
    local g, p, n = AnchorTable("general"), AnchorTable("player"), AnchorTable("npc")
    local saved = TinyTooltipRecordDB.restore
    if (not (g and p and n and saved)) then return end
    for which, values in pairs(saved) do
        local t = AnchorTable(which)
        wipe(t)
        for k, v in pairs(values) do t[k] = v end
    end
    if (not mode) then return end
    g.position, p.position, n.position = mode, "inherit", "inherit"
    -- a Static box that was never placed: put it somewhere visible, like a placed one
    if (mode == "static" and g.x == nil) then
        g.p, g.x, g.y = "BOTTOMRIGHT", -300, 300
    end
end

-------------------------------------
-- checklist
-------------------------------------

local HOVER = "1. Hover an NPC in the world for 2 seconds, then move the mouse to empty ground and wait 3 seconds.\n" ..
              "2. The same with a player (yourself is fine).\n" ..
              "3. Hover your player frame or target frame, then move off it and wait 3 seconds.\n" ..
              "If a tooltip stays up, flickers or looks wrong, click Mark Problem."

local STEPS = {
    { title = "Your Own Settings", mode = nil, text =
        "Your normal Position settings.\n" .. HOVER .. "\n" ..
        "4. Also hover a nameplate, a bag item, an action button and a world object (mailbox, herb, chest), moving off each and waiting 3 seconds." },
    { title = "Position: Default",            mode = "default",           text = HOVER },
    { title = "Position: Cursor Right",       mode = "cursorRight",       text = HOVER },
    { title = "Position: Cursor",             mode = "cursor",            text = HOVER },
    { title = "Position: Static",             mode = "static",            text = HOVER .. "\n(The tooltip should sit lower right, away from the corner.)" },
    { title = "Position: Default Bottom Left", mode = "defaultBottomLeft", text = HOVER },
    { title = "Special Units", mode = nil, text =
        "Your normal settings again. Hover whichever of these you can find, 2 seconds each:\n" ..
        "a player flagged for PvP, an elite or rare NPC, a dead mob, a critter or pet, a guard, " ..
        "a player in a guild, a player of the other faction." },
    { title = "Items And IDs", mode = nil, text =
        "Hover a bag item, an equipped item, an action button and a buff on your player frame. " ..
        "Then do the same while holding Shift (TinyTooltip shows IDs with Shift)." },
    { title = "Combat", mode = nil, text =
        "Fight a mob. While in combat, hover it, your target frame and another unit, moving off each. " ..
        "Then let the mob die and hover its corpse." },
}

-------------------------------------
-- panel
-------------------------------------

local panel

local function UpdatePanel()
    if (not panel) then return end
    if (not recording and step == 0) then
        panel.title:SetText("TinyTooltip Recorder")
        panel.body:SetText("Records what tooltips do while you follow " .. #STEPS .. " short steps (about 20 minutes). " ..
            "Some steps switch TinyTooltip's Position; your own settings come back when you click Finish.\n\n" ..
            "Click Start Recording to begin.")
        panel.back:Hide(); panel.mark:Hide(); panel.finish:Hide()
        panel.next:SetText("Start Recording")
    elseif (not recording) then
        panel.title:SetText("Recording Finished")
        panel.body:SetText("Your Position settings are back to normal.\nType /reload to save the recording, then tell Claude it's done.")
        panel.back:Hide(); panel.mark:Hide(); panel.finish:Hide()
        panel.next:SetText("Close")
    else
        local s = STEPS[step]
        panel.title:SetText(format("Step %d of %d: %s", step, #STEPS, s.title))
        panel.body:SetText(s.text)
        panel.back:Show(); panel.mark:Show(); panel.finish:Show()
        panel.back:SetEnabled(step > 1)
        panel.next:SetText(step < #STEPS and "Next Step" or "Finish")
    end
    panel:SetHeight(panel.body:GetStringHeight() + 96)
end

local function GoStep(n)
    step = n
    ApplyMode(STEPS[n].mode)
    Push({ ev = "step", title = STEPS[n].title, mode = STEPS[n].mode or "own" })
    UpdatePanel()
end

local function Start()
    TinyTooltipRecordDB.sessions = TinyTooltipRecordDB.sessions or {}
    t0 = GetNow()
    local build, buildNum, buildDate, iface = GetBuildInfo()
    rec = {
        started = date("%Y-%m-%d %H:%M:%S"),
        client = { build, buildNum, buildDate, iface },
        ttVersion = C_AddOns and C_AddOns.GetAddOnMetadata("TinyTooltip", "Version"),
        settings = Copy(TinyTooltip.db, 0),
        addons = {},
        events = {},
    }
    if (C_AddOns and C_AddOns.GetNumAddOns) then
        for i = 1, C_AddOns.GetNumAddOns() do
            local name = C_AddOns.GetAddOnInfo(i)
            if (name and C_AddOns.IsAddOnLoaded(i)) then tinsert(rec.addons, name) end
        end
    end
    tinsert(TinyTooltipRecordDB.sessions, rec)
    SaveAnchors()
    recording = true
    lastBuildKey, lastBuild, cur = nil, nil, nil
    GoStep(1)
end

local function Finish()
    if (recording) then Push({ ev = "finish" }) end
    RestoreAnchors()
    recording = false
    if (rec) then rec.finished = date("%Y-%m-%d %H:%M:%S") end
    UpdatePanel()
end

local function MakeButton(text, width, onClick)
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function CreatePanel()
    panel = CreateFrame("Frame", "TinyTooltipRecorderPanel", UIParent, "BackdropTemplate")
    panel:SetSize(400, 200)
    panel:SetPoint("TOP", UIParent, "TOP", 0, -120)
    panel:SetFrameStrata("DIALOG")
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    panel:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
    panel:SetBackdropBorderColor(0.3, 0.6, 1, 0.9)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 12, -10)
    panel.title:SetPoint("TOPRIGHT", -12, -10)
    panel.title:SetJustifyH("LEFT")
    panel.body = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.body:SetPoint("TOPLEFT", 12, -36)
    panel.body:SetWidth(376)
    panel.body:SetJustifyH("LEFT")
    panel.body:SetJustifyV("TOP")
    panel.body:SetSpacing(2)
    panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.status:SetPoint("BOTTOMLEFT", 12, 38)
    panel.back = MakeButton("Back", 70, function() if (step > 1) then GoStep(step - 1) end end)
    panel.back:SetPoint("BOTTOMLEFT", 10, 10)
    panel.next = MakeButton("Next Step", 110, function()
        if (not recording and step == 0) then Start()
        elseif (not recording) then panel:Hide()
        elseif (step < #STEPS) then GoStep(step + 1)
        else Finish() end
    end)
    panel.next:SetPoint("LEFT", panel.back, "RIGHT", 6, 0)
    panel.mark = MakeButton("Mark Problem", 110, function()
        Push({ ev = "mark", shown = GameTooltip:IsShown(), alpha = R(GameTooltip:GetAlpha()), lines = Lines(),
               owner = S(GameTooltip:GetOwner()), anchor = S(GameTooltip:GetAnchorType()), point = Point(), focus = Focus() })
        print("|cff00ccffTinyTooltip Recorder:|r problem marked.")
    end)
    panel.mark:SetPoint("LEFT", panel.next, "RIGHT", 6, 0)
    panel.finish = MakeButton("Finish", 70, Finish)
    panel.finish:SetPoint("BOTTOMRIGHT", -10, 10)
    panel:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if (self.elapsed < 0.5) then return end
        self.elapsed = 0
        self.status:SetText(recording and format("Recording: %d events", #rec.events) or "")
    end)
    UpdatePanel()
end

-------------------------------------
-- tooltip hooks
-------------------------------------

local function UnitContext(e)
    local ok, _, unit = pcall(GameTooltip.GetUnit, GameTooltip)
    if (not ok or not unit) then return end
    e.unit = S(unit)
    if (issecret(unit)) then return end
    e.isPlayer   = S(UnitIsPlayer(unit))
    e.inParty    = S(UnitInParty(unit))
    e.inRaid     = S(UnitInRaid(unit))
    e.connected  = S(UnitIsConnected(unit))
    e.classif    = S(UnitClassification(unit))
    e.dead       = S(UnitIsDeadOrGhost(unit))
    e.isMouseover = S(UnitIsUnit(unit, "mouseover"))
    e.pvp        = S(UnitIsPVP(unit))
    e.tinyRows   = GameTooltip.tinyUnitRows
end

local function FinishBuild(b)
    if (b.done) then return end
    b.done = true
    b.final = Lines()
    b.point = Point()
    b.alpha = R(GameTooltip:GetAlpha())
    UnitContext(b)
    local key = tostring(b.dtype) .. "#" .. tostring(b.owner) .. "#" .. tostring(b.unit) .. "#" ..
                LinesKey(b.raw) .. "#" .. LinesKey(b.final)
    if (key == lastBuildKey and lastBuild) then
        lastBuild.repeats = (lastBuild.repeats or 1) + 1
        lastBuild.t2 = Now()
        return
    end
    lastBuildKey = key
    lastBuild = Push(b)
    -- lines that change after the build (TinyTooltip's OnUpdate clean-up, late client lines)
    C_Timer.After(0.5, function()
        if (not recording or not GameTooltip:IsShown() or cur) then return end
        local later = Lines()
        if (LinesKey(later) ~= LinesKey(b.final)) then
            Push({ ev = "late", ref = b.t, lines = later })
        end
    end)
end

local function Hook()
    if (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPreCall) then
        TooltipDataProcessor.AddTooltipPreCall(TooltipDataProcessor.AllTypes, function(tip, data)
            if (not recording or tip ~= GameTooltip) then return end
            if (cur and not cur.done) then FinishBuild(cur) end
            cur = { ev = "build", dtype = S(data and data.type), raw = {},
                    owner = S(tip:GetOwner()), anchor = S(tip:GetAnchorType()), focus = Focus(), fading = fading or nil }
        end)
        TooltipDataProcessor.AddLinePostCall(TooltipDataProcessor.AllTypes, function(tip, lineData)
            if (not recording or tip ~= GameTooltip or not cur or cur.done) then return end
            cur.raw[#cur.raw + 1] = { S(lineData.leftText), S(lineData.rightText), S(lineData.type) }
        end)
    end

    hooksecurefunc(GameTooltip, "Show", function(self)
        if (not recording) then return end
        if (cur and not cur.done) then
            -- finish at the next frame, after every post-call and OnUpdate clean-up has run
            if (not cur.scheduled) then
                cur.scheduled = true
                local b = cur
                C_Timer.After(0, function()
                    FinishBuild(b)
                    if (cur == b) then cur = nil end
                end)
            end
            return
        end
        local caller = Caller() or "?"
        Push({ ev = fading and "show-during-fade" or "show", caller = caller }, "show#" .. caller .. tostring(fading))
    end)

    hooksecurefunc(GameTooltip, "Hide", function(self)
        local caller = Caller() or "?"
        Push({ ev = "hide", caller = caller, shown = self:IsShown() }, "hide#" .. caller)
    end)

    hooksecurefunc(GameTooltip, "SetOwner", function(self, owner, anchor, x, y)
        local o, a = S(owner), S(anchor)
        Push({ ev = "owner", owner = o, anchor = a, x = R(x), y = R(y), caller = Caller() },
             "owner#" .. tostring(o) .. tostring(a))
    end)

    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tip, parent)
        if (tip ~= GameTooltip) then return end
        Push({ ev = "defanchor", parent = S(parent), anchor = S(tip:GetAnchorType()), point = Point() })
    end)

    if (GameTooltip.SetWorldCursor) then
        hooksecurefunc(GameTooltip, "SetWorldCursor", function(self, anchorType)
            local a = S(anchorType)
            Push({ ev = "worldcursor", anchorType = a }, "wc#" .. tostring(a))
        end)
    end

    if (GameTooltip.FadeOut) then
        hooksecurefunc(GameTooltip, "FadeOut", function(self)
            fading = true
            Push({ ev = "fadeout", caller = Caller(), alpha = R(self:GetAlpha()), shown = self:IsShown() })
        end)
    end

    if (GameTooltip.ClearHandlerInfo) then
        hooksecurefunc(GameTooltip, "ClearHandlerInfo", function(self)
            Push({ ev = "clearinfo" }, "clearinfo")
        end)
    end

    GameTooltip:HookScript("OnShow", function(self)
        Push({ ev = "onshow", alpha = R(self:GetAlpha()) })
    end)
    GameTooltip:HookScript("OnHide", function(self)
        fading = false
        Push({ ev = "onhide" })
    end)

    -- shown / alpha / mouseover / owner, logged when any of them changes
    local sampler = CreateFrame("Frame")
    local lastState
    sampler:SetScript("OnUpdate", function()
        if (not recording) then return end
        local shown = GameTooltip:IsShown()
        local alpha = R(GameTooltip:GetAlpha())
        local mo = UnitExists("mouseover")
        mo = S(mo)
        local owner = S(GameTooltip:GetOwner())
        local anchor = S(GameTooltip:GetAnchorType())
        local state = tostring(shown) .. tostring(alpha) .. tostring(mo) .. tostring(owner) .. tostring(anchor)
        if (state ~= lastState) then
            lastState = state
            Push({ ev = "state", shown = shown, alpha = alpha, mouseover = mo, owner = owner, anchor = anchor,
                   lines = GameTooltip:NumLines(), fading = fading or nil })
        end
    end)
end

-------------------------------------
-- events and slash command
-------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("PLAYER_LOGOUT")
loader:RegisterEvent("PLAYER_REGEN_DISABLED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:SetScript("OnEvent", function(self, event, arg1)
    if (event == "ADDON_LOADED" and arg1 == "TinyTooltipRecorder") then
        TinyTooltipRecordDB = TinyTooltipRecordDB or {}
        Hook()
    elseif (event == "PLAYER_ENTERING_WORLD") then
        -- a session that ended in a crash or /reload: put the Position settings back
        if (TinyTooltipRecordDB.restore and not recording and TinyTooltip and TinyTooltip.db) then
            RestoreAnchors()
            print("|cff00ccffTinyTooltip Recorder:|r restored your Position settings from an unfinished recording.")
        end
    elseif (event == "PLAYER_LOGOUT") then
        if (recording) then
            Push({ ev = "logout" })
            if (rec) then rec.finished = rec.finished or "logout" end
        end
        RestoreAnchors()
    elseif (event == "PLAYER_REGEN_DISABLED") then
        Push({ ev = "combat", on = true })
    elseif (event == "PLAYER_REGEN_ENABLED") then
        Push({ ev = "combat", on = false })
    end
end)

SLASH_TINYTOOLTIPRECORDER1 = "/ttrec"
SlashCmdList.TINYTOOLTIPRECORDER = function(msg)
    msg = strtrim(strlower(msg or ""))
    if (msg == "stop" or msg == "finish") then
        Finish()
    elseif (msg:sub(1, 4) == "note") then
        Push({ ev = "note", text = strtrim(msg:sub(5)) })
        print("|cff00ccffTinyTooltip Recorder:|r note saved.")
    else
        if (not panel) then CreatePanel() end
        panel:SetShown(not panel:IsShown() or not recording)
        UpdatePanel()
    end
end
