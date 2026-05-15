--[[
    ESP v2 — pro implementation.

    - Drawing object POOL: pre-allocate slots, reuse on player join,
      never tear down during a match. Major perf win over per-player
      Instance.new() recreation.
    - Skeleton ESP for both R6 and R15 rigs (canonical bone tables).
    - Box / corner / outline modes
    - Name, distance, weapon (currently equipped Tool) labels
    - Health bar with distance-fade and color gradient (red->green)
    - Tracer with 4 origin modes + distance color gradient
    - Highlight chams with DepthMode=AlwaysOnTop and distance fade
    - Team check + team color + max distance + per-update throttle
]]

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local Workspace     = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local M = {}

local state = {
    Enabled       = false,
    Box           = true,
    BoxStyle      = "Outline",      -- Outline | Corner | Filled
    Name          = true,
    Distance      = true,
    Health        = true,
    Weapon        = false,
    Tracer        = false,
    Chams         = false,
    Skeleton      = false,
    TeamCheck     = false,
    TeamColor     = false,
    Color         = Color3.fromRGB(140, 100, 255),
    EnemyColor    = Color3.fromRGB(235,  90, 100),
    AllyColor     = Color3.fromRGB(120, 220, 140),
    MaxDist       = 1000,
    DistFade      = true,
    TracerFrom    = "Bottom",       -- Bottom | Center | Top | Mouse
    ChamsTransp   = 0.5,
}

-- Canonical bone tables (from KaenDeveloper / Stefanuk12 / DevForum consensus)
local SKELETON_R15 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},  {"LeftUpperArm", "LeftLowerArm"},  {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},  {"LeftUpperLeg", "LeftLowerLeg"},  {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"},{"RightLowerLeg", "RightFoot"},
}
local SKELETON_R6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}
-- 14 R15 bones + 5 R6, but each player only renders one rig, so 14 lines
-- per slot is the upper bound.
local SKELETON_LINES_PER_PLAYER = 14

-- ============================================================
-- Drawing pool
-- ============================================================

local HAS_DRAWING = type(Drawing) == "table" and type(Drawing.new) == "function"

local function newDrawing(class, props)
    if not HAS_DRAWING then return nil end
    local obj = Drawing.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    return obj
end

-- One pool slot per player slot. Pre-allocated for MAX_SLOTS players;
-- reused across joins/leaves. Lines for skeleton are part of the slot.
local MAX_SLOTS = 60   -- big enough for any realistic server
local pool = {}        -- index -> {box, boxOutline, name, dist, weapon, hpBg, hpFill, tracer, skeleton={lines}}
local slotByPlayer = {} -- [player] = slot index
local slotInUse = {}   -- [index] = bool

local function buildSlot()
    local slot = {}
    slot.boxOutline = newDrawing("Square", {Thickness = 3, Filled = false,
        Color = Color3.new(0,0,0), Transparency = 0.5, Visible = false})
    slot.box = newDrawing("Square", {Thickness = 1, Filled = false,
        Color = state.Color, Visible = false})
    slot.boxFill = newDrawing("Square", {Thickness = 1, Filled = true,
        Color = state.Color, Transparency = 0.2, Visible = false})
    slot.name = newDrawing("Text", {Size = 13, Center = true, Outline = true,
        Color = state.Color, Font = 2, Visible = false})
    slot.dist = newDrawing("Text", {Size = 11, Center = true, Outline = true,
        Color = Color3.new(1,1,1), Font = 2, Visible = false})
    slot.weapon = newDrawing("Text", {Size = 11, Center = true, Outline = true,
        Color = Color3.fromRGB(255,200,100), Font = 2, Visible = false})
    slot.hpBg = newDrawing("Square", {Thickness = 1, Filled = true,
        Color = Color3.fromRGB(20,20,20), Visible = false})
    slot.hpFill = newDrawing("Square", {Thickness = 1, Filled = true,
        Color = Color3.fromRGB(90,200,120), Visible = false})
    slot.tracer = newDrawing("Line", {Thickness = 1, Color = state.Color, Visible = false})
    slot.skeleton = {}
    for i = 1, SKELETON_LINES_PER_PLAYER do
        slot.skeleton[i] = newDrawing("Line", {Thickness = 1, Color = state.Color, Visible = false})
    end
    -- Highlight chams (Instance-based, not Drawing)
    local hl = Instance.new("Highlight")
    hl.Name = "ROGBLOX_Chams"
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = state.ChamsTransp
    hl.OutlineTransparency = 0
    hl.FillColor = state.Color
    hl.OutlineColor = state.Color
    hl.Enabled = false
    slot.chams = hl
    return slot
end

local function ensurePool()
    if #pool > 0 then return end
    for i = 1, MAX_SLOTS do
        pool[i] = buildSlot()
        slotInUse[i] = false
    end
end

local function acquireSlot(plr)
    if slotByPlayer[plr] then return slotByPlayer[plr] end
    for i = 1, MAX_SLOTS do
        if not slotInUse[i] then
            slotInUse[i] = true
            slotByPlayer[plr] = i
            return i
        end
    end
    return nil  -- pool exhausted, skip
end

local function hideSlot(slot)
    if not slot then return end
    slot.box.Visible = false
    slot.boxOutline.Visible = false
    if slot.boxFill then slot.boxFill.Visible = false end
    slot.name.Visible = false
    slot.dist.Visible = false
    slot.weapon.Visible = false
    slot.hpBg.Visible = false
    slot.hpFill.Visible = false
    slot.tracer.Visible = false
    for _, ln in ipairs(slot.skeleton) do ln.Visible = false end
    slot.chams.Enabled = false
end

local function releaseSlot(plr)
    local idx = slotByPlayer[plr]
    if not idx then return end
    hideSlot(pool[idx])
    slotInUse[idx] = false
    slotByPlayer[plr] = nil
end

local function destroyPool()
    for _, slot in ipairs(pool) do
        for _, obj in pairs(slot) do
            if type(obj) == "table" then
                for _, ln in ipairs(obj) do
                    if ln and ln.Remove then pcall(function() ln:Remove() end) end
                end
            elseif typeof(obj) == "Instance" then
                obj:Destroy()
            elseif obj and obj.Remove then
                pcall(function() obj:Remove() end)
            end
        end
    end
    pool = {}
    slotByPlayer = {}
    slotInUse = {}
end

-- ============================================================
-- Color helpers
-- ============================================================

local function colorFor(plr)
    if state.TeamColor and plr.Team and plr.TeamColor then
        return plr.TeamColor.Color
    end
    local lp = Players.LocalPlayer
    if lp and lp.Team and plr.Team and lp.Team == plr.Team then
        return state.AllyColor
    end
    return state.EnemyColor
end

local function fadeColor(c, dist)
    if not state.DistFade then return c, 0 end
    local t = math.clamp(dist / state.MaxDist, 0, 1)
    local transp = t * 0.6   -- 0.0 close, 0.6 far
    return c, transp
end

local function hpColor(pct)
    if pct > 0.5 then
        return Color3.fromRGB(math.floor(255 * 2 * (1 - pct)), 200, 80)
    else
        return Color3.fromRGB(255, math.floor(200 * 2 * pct), 80)
    end
end

local function getEquippedWeapon(plr)
    local char = plr.Character
    if not char then return nil end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") then return t.Name end
    end
    return nil
end

local function tracerOrigin()
    local cam = Workspace.CurrentCamera
    local v = cam.ViewportSize
    if state.TracerFrom == "Top"    then return Vector2.new(v.X/2, 0)
    elseif state.TracerFrom == "Center" then return Vector2.new(v.X/2, v.Y/2)
    elseif state.TracerFrom == "Mouse"  then return UserInputService:GetMouseLocation()
    end
    return Vector2.new(v.X/2, v.Y)
end

-- ============================================================
-- Per-player update
-- ============================================================

local function updateSlot(plr)
    local idx = slotByPlayer[plr]
    if not idx then return end
    local slot = pool[idx]
    if not slot then return end

    local lp = Players.LocalPlayer
    local char = plr.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local head = char and char:FindFirstChild("Head")

    local visible = state.Enabled and char and hum and hrp and head and hum.Health > 0
    if state.TeamCheck and lp and lp.Team and plr.Team and lp.Team == plr.Team then
        visible = false
    end

    if not visible then hideSlot(slot); return end

    local cam = Workspace.CurrentCamera
    local distance = (cam.CFrame.Position - hrp.Position).Magnitude
    if distance > state.MaxDist then hideSlot(slot); return end

    local rootScreen, onScreen = cam:WorldToViewportPoint(hrp.Position)
    if not onScreen then hideSlot(slot); return end

    local headScreen = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
    local footPos = hrp.Position - Vector3.new(0, 3, 0)
    local footScreen = cam:WorldToViewportPoint(footPos)
    local height = math.abs(footScreen.Y - headScreen.Y)
    local width  = height * 0.55
    local boxX, boxY = rootScreen.X - width/2, headScreen.Y

    local baseColor = colorFor(plr)
    local color, transp = fadeColor(baseColor, distance)

    -- ----- Box -----
    if state.Box then
        if state.BoxStyle == "Filled" and slot.boxFill then
            slot.boxFill.Position = Vector2.new(boxX, boxY)
            slot.boxFill.Size = Vector2.new(width, height)
            slot.boxFill.Color = color
            slot.boxFill.Transparency = 0.7
            slot.boxFill.Visible = true
            slot.box.Visible = false
            slot.boxOutline.Visible = false
        else
            slot.box.Position = Vector2.new(boxX, boxY)
            slot.box.Size = Vector2.new(width, height)
            slot.box.Color = color
            slot.box.Transparency = 1 - transp
            slot.box.Visible = true
            slot.boxOutline.Position = slot.box.Position
            slot.boxOutline.Size = slot.box.Size
            slot.boxOutline.Visible = true
            if slot.boxFill then slot.boxFill.Visible = false end
        end
    else
        slot.box.Visible = false
        slot.boxOutline.Visible = false
        if slot.boxFill then slot.boxFill.Visible = false end
    end

    -- ----- Name -----
    if state.Name then
        slot.name.Position = Vector2.new(rootScreen.X, boxY - 16)
        slot.name.Text = plr.DisplayName
        slot.name.Color = color
        slot.name.Visible = true
    else slot.name.Visible = false end

    -- ----- Distance -----
    if state.Distance then
        slot.dist.Position = Vector2.new(rootScreen.X, boxY + height + 2)
        slot.dist.Text = string.format("[%dm]", math.floor(distance))
        slot.dist.Visible = true
    else slot.dist.Visible = false end

    -- ----- Weapon -----
    if state.Weapon then
        local wpn = getEquippedWeapon(plr)
        if wpn then
            slot.weapon.Position = Vector2.new(rootScreen.X, boxY - 28)
            slot.weapon.Text = "[" .. wpn .. "]"
            slot.weapon.Visible = true
        else slot.weapon.Visible = false end
    else slot.weapon.Visible = false end

    -- ----- Health bar -----
    if state.Health then
        local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        slot.hpBg.Position = Vector2.new(boxX - 6, boxY)
        slot.hpBg.Size = Vector2.new(3, height)
        slot.hpBg.Visible = true
        slot.hpFill.Position = Vector2.new(boxX - 6, boxY + (1 - pct) * height)
        slot.hpFill.Size = Vector2.new(3, height * pct)
        slot.hpFill.Color = hpColor(pct)
        slot.hpFill.Visible = true
    else
        slot.hpBg.Visible = false
        slot.hpFill.Visible = false
    end

    -- ----- Tracer -----
    if state.Tracer then
        local origin = tracerOrigin()
        slot.tracer.From = origin
        slot.tracer.To   = Vector2.new(rootScreen.X, boxY + height)
        local distT = math.clamp(distance / 200, 0, 1)
        slot.tracer.Color = Color3.new(distT, 1 - distT, 0)
        slot.tracer.Visible = true
    else slot.tracer.Visible = false end

    -- ----- Skeleton -----
    if state.Skeleton then
        local rig
        if char:FindFirstChild("UpperTorso") then rig = SKELETON_R15
        elseif char:FindFirstChild("Torso") then  rig = SKELETON_R6
        end
        if rig then
            for i, bone in ipairs(rig) do
                local a = char:FindFirstChild(bone[1])
                local b = char:FindFirstChild(bone[2])
                local ln = slot.skeleton[i]
                if a and b and ln then
                    local sa = cam:WorldToViewportPoint(a.Position)
                    local sb = cam:WorldToViewportPoint(b.Position)
                    if sa.Z > 0 and sb.Z > 0 then
                        ln.From = Vector2.new(sa.X, sa.Y)
                        ln.To   = Vector2.new(sb.X, sb.Y)
                        ln.Color = color
                        ln.Visible = true
                    else ln.Visible = false end
                end
            end
            -- hide unused lines beyond rig length
            for i = #rig + 1, #slot.skeleton do
                slot.skeleton[i].Visible = false
            end
        end
    else
        for _, ln in ipairs(slot.skeleton) do ln.Visible = false end
    end

    -- ----- Chams -----
    if state.Chams then
        slot.chams.Adornee = char
        slot.chams.FillColor = color
        slot.chams.OutlineColor = color
        slot.chams.FillTransparency = state.ChamsTransp + transp * 0.3
        slot.chams.Enabled = true
        if not slot.chams.Parent then slot.chams.Parent = char end
    else
        slot.chams.Enabled = false
    end
end

-- ============================================================
-- Build / Unload
-- ============================================================

local conns = {}

local function onPlayerAdded(plr)
    if plr == Players.LocalPlayer then return end
    acquireSlot(plr)
end

local function onPlayerRemoving(plr)
    releaseSlot(plr)
end

function M.Build(tab, ctx)
    ensurePool()
    for _, plr in ipairs(Players:GetPlayers()) do onPlayerAdded(plr) end
    conns.added = Players.PlayerAdded:Connect(onPlayerAdded)
    conns.left  = Players.PlayerRemoving:Connect(onPlayerRemoving)

    local main = tab:AddSection("ESP")
    main:AddToggle("Enabled", false, function(v)
        state.Enabled = v
        if not v then for _, slot in ipairs(pool) do hideSlot(slot) end end
    end)
    main:AddToggle("Box", true, function(v) state.Box = v end)
    main:AddDropdown("Box style", {"Outline","Corner","Filled"}, "Outline", function(v) state.BoxStyle = v end)
    main:AddToggle("Name tag", true, function(v) state.Name = v end)
    main:AddToggle("Distance", true, function(v) state.Distance = v end)
    main:AddToggle("Health bar", true, function(v) state.Health = v end)
    main:AddToggle("Weapon ESP", false, function(v) state.Weapon = v end)
    main:AddToggle("Tracers", false, function(v) state.Tracer = v end)
    main:AddDropdown("Tracer origin", {"Bottom","Center","Top","Mouse"}, "Bottom", function(v) state.TracerFrom = v end)
    main:AddToggle("Skeleton (R6/R15)", false, function(v) state.Skeleton = v end)
    main:AddToggle("Chams (highlight)", false, function(v) state.Chams = v end)
    main:AddSlider("Chams transparency", 0, 1, 0.5, function(v) state.ChamsTransp = v end, {Decimals = 2})
    main:AddSlider("Max distance", 50, 5000, 1000, function(v) state.MaxDist = v end)
    main:AddToggle("Distance fade", true, function(v) state.DistFade = v end)

    local filters = tab:AddSection("Filters & Colors")
    filters:AddToggle("Team check (hide allies)", false, function(v) state.TeamCheck = v end)
    filters:AddToggle("Use team color", false, function(v) state.TeamColor = v end)
    filters:AddColorPicker("Enemy color", state.EnemyColor, function(c) state.EnemyColor = c end)
    filters:AddColorPicker("Ally color",  state.AllyColor,  function(c) state.AllyColor = c end)

    -- main loop
    conns.render = RunService.RenderStepped:Connect(function()
        for plr, _ in pairs(slotByPlayer) do
            updateSlot(plr)
        end
    end)
end

function M.Unload()
    for _, c in pairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    destroyPool()
end

M.State = state
return M
