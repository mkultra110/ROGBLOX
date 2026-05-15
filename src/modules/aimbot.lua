--[[
    Aimbot — professional implementation.

    Target selection modes:
        Crosshair      — closest screen distance to viewport center
        Mouse          — closest screen distance to current mouse position
        Distance       — closest in 3D space to local player
        LowestHP       — lowest current health (within FOV)

    Per-part priority list — first part found on target wins.
    Prediction — leads the target using its assembly velocity.
    Visibility — Workspace:Raycast verifies line of sight.
    Smoothing — Linear / Sine / Exponential interpolation curve.
    Auto-switch — abandons target when dead / out of FOV / lost LOS.
    Friend list — comma-separated names that are never targeted.
    Trigger bot — fires when crosshair is on a player and gates by delay.

    Publishes M.LockedTarget for the HUD module to render the panel.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")

local M = {}

local state = {
    Enabled        = false,
    Held           = false,
    HoldMode       = true,
    HoldButton     = Enum.UserInputType.MouseButton2,
    Mode           = "Crosshair",           -- Crosshair | Mouse | Distance | LowestHP
    Parts          = {"Head", "HumanoidRootPart", "UpperTorso"},
    FOV            = 120,
    MaxDistance    = 1000,
    CheckTeam      = false,
    CheckLOS       = true,
    AutoSwitch     = true,
    SmoothCurve    = "Sine",                -- Linear | Sine | Exponential
    Smoothness     = 0.35,
    Prediction     = 0.16,                  -- seconds of lead
    SnapLine       = false,
    ShowFOV        = true,
    FOVColor       = Color3.fromRGB(140, 100, 255),
    FOVFilled      = false,
    Sticky         = true,                  -- stays on a target until lost
    FriendList     = {},                    -- [name] = true
    TriggerBot     = false,
    TriggerDelay   = 0.05,
    TriggerWindow  = 6,                     -- pixels from center
}

M.LockedTarget = nil
local conns = {}
local fov, fovOutline, snapLine

-- ---------- Helpers ----------

local function getLocalChar()
    local lp = Players.LocalPlayer
    return lp and lp.Character
end

local function isAlive(plr)
    local c = plr and plr.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function sameTeam(plr)
    local lp = Players.LocalPlayer
    if not (lp and lp.Team and plr.Team) then return false end
    return lp.Team == plr.Team
end

local function isFriend(plr)
    return state.FriendList[plr.Name] or state.FriendList[plr.DisplayName]
end

local function getTargetPart(plr)
    local char = plr.Character
    if not char then return nil end
    for _, name in ipairs(state.Parts) do
        local p = char:FindFirstChild(name)
        if p then return p end
    end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
end

local function hasLOS(target)
    local cam = Workspace.CurrentCamera
    if not (cam and target) then return false end
    local origin = cam.CFrame.Position
    local dir = (target.Position - origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {getLocalChar()}
    if cam then table.insert(ignore, cam) end
    params.FilterDescendantsInstances = ignore
    local result = Workspace:Raycast(origin, dir, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(target.Parent)
end

local function predict(part)
    if state.Prediction <= 0 then return part.Position end
    local vel = part.AssemblyLinearVelocity
    return part.Position + vel * state.Prediction
end

local function screenOf(point)
    local cam = Workspace.CurrentCamera
    local p, on = cam:WorldToViewportPoint(point)
    return Vector2.new(p.X, p.Y), on, p.Z
end

local function viewportCenter()
    local cam = Workspace.CurrentCamera
    local v = cam.ViewportSize
    return Vector2.new(v.X / 2, v.Y / 2)
end

local function mousePos()
    return UserInputService:GetMouseLocation()
end

local function curveAlpha(rawAlpha)
    local a = math.clamp(1 - state.Smoothness, 0.01, 1)
    rawAlpha = math.clamp(rawAlpha, 0, 1) * a
    if state.SmoothCurve == "Sine" then
        return math.sin(rawAlpha * math.pi / 2)
    elseif state.SmoothCurve == "Exponential" then
        return 1 - math.exp(-5 * rawAlpha)
    end
    return rawAlpha
end

-- ---------- Target selection ----------

local function findTarget()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local me = getLocalChar()
    local myRoot = me and me:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local origin
    if state.Mode == "Crosshair" then origin = viewportCenter()
    elseif state.Mode == "Mouse" then origin = mousePos()
    end

    local bestTarget, bestScore
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer and isAlive(plr)
        and not (state.CheckTeam and sameTeam(plr))
        and not isFriend(plr) then
            local part = getTargetPart(plr)
            if part then
                local screenP, onScreen = screenOf(part.Position)
                local distance = (part.Position - myRoot.Position).Magnitude
                if distance <= state.MaxDistance and (onScreen or state.Mode == "Distance") then
                    local score
                    if state.Mode == "Distance" then
                        score = distance
                    elseif state.Mode == "LowestHP" then
                        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                        local screenDist = onScreen and (screenP - viewportCenter()).Magnitude or math.huge
                        if screenDist <= state.FOV then
                            score = hum and hum.Health or math.huge
                        end
                    else
                        local screenDist = (screenP - origin).Magnitude
                        if screenDist <= state.FOV then score = screenDist end
                    end
                    if score and (not bestScore or score < bestScore) then
                        if not state.CheckLOS or hasLOS(part) then
                            bestTarget = plr
                            bestScore = score
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

-- ---------- Target tracking ----------

local function isTargetStillValid(plr)
    if not (plr and isAlive(plr)) then return false end
    if state.CheckTeam and sameTeam(plr) then return false end
    if isFriend(plr) then return false end
    local part = getTargetPart(plr)
    if not part then return false end
    if state.CheckLOS and not hasLOS(part) then return false end
    local screenP, onScreen = screenOf(part.Position)
    if not onScreen then return false end
    if state.Mode == "Crosshair" then
        local d = (screenP - viewportCenter()).Magnitude
        if d > state.FOV then return false end
    elseif state.Mode == "Mouse" then
        local d = (screenP - mousePos()).Magnitude
        if d > state.FOV then return false end
    end
    return true
end

-- ---------- Drawing setup ----------

local function buildFOV()
    if not (Drawing and Drawing.new) then return end
    if fov then return end
    fovOutline = Drawing.new("Circle")
    fovOutline.Thickness = 3
    fovOutline.Color = Color3.new(0, 0, 0)
    fovOutline.Transparency = 0.5
    fovOutline.NumSides = 80
    fovOutline.Filled = false
    fovOutline.Visible = false

    fov = Drawing.new("Circle")
    fov.Thickness = 1
    fov.Color = state.FOVColor
    fov.NumSides = 80
    fov.Filled = false
    fov.Visible = false

    snapLine = Drawing.new("Line")
    snapLine.Color = state.FOVColor
    snapLine.Thickness = 1
    snapLine.Visible = false
end

local function updateFOV()
    if not fov then return end
    local center = viewportCenter()
    fov.Position = center
    fov.Radius = state.FOV
    fov.Color = state.FOVColor
    fov.Filled = state.FOVFilled
    fov.Transparency = state.FOVFilled and 0.2 or 1
    fov.Visible = state.ShowFOV and (state.Enabled or (state.HoldMode and state.Held))
    fovOutline.Position = center
    fovOutline.Radius = state.FOV
    fovOutline.Visible = fov.Visible and not state.FOVFilled
end

local function clearFOV()
    for _, obj in ipairs({fov, fovOutline, snapLine}) do
        if obj then pcall(function() obj:Remove() end) end
    end
    fov, fovOutline, snapLine = nil, nil, nil
end

-- ---------- Aim step ----------

local function aimStep()
    if not state.Enabled then M.LockedTarget = nil; return end
    if state.HoldMode and not state.Held then M.LockedTarget = nil; return end

    local target = M.LockedTarget
    if state.Sticky and target and isTargetStillValid(target) then
        -- stay on it
    else
        target = findTarget()
    end
    M.LockedTarget = target

    if not target then
        if snapLine then snapLine.Visible = false end
        return
    end

    local part = getTargetPart(target)
    if not part then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end

    local aimPos = predict(part)
    local goal = CFrame.new(cam.CFrame.Position, aimPos)
    local alpha = curveAlpha(1)
    if alpha >= 0.999 then
        cam.CFrame = goal
    else
        cam.CFrame = cam.CFrame:Lerp(goal, alpha)
    end

    if state.SnapLine and snapLine then
        local screenP = screenOf(aimPos)
        snapLine.From = viewportCenter()
        snapLine.To = screenP
        snapLine.Color = state.FOVColor
        snapLine.Visible = true
    elseif snapLine then
        snapLine.Visible = false
    end
end

-- ---------- Trigger bot ----------

local triggerCooldown = 0
local function triggerStep()
    if not state.TriggerBot then return end
    if tick() < triggerCooldown then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local center = viewportCenter()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer and isAlive(plr)
        and not (state.CheckTeam and sameTeam(plr))
        and not isFriend(plr) then
            local part = getTargetPart(plr)
            if part then
                local screenP, onScreen = screenOf(part.Position)
                if onScreen and (screenP - center).Magnitude <= state.TriggerWindow then
                    if not state.CheckLOS or hasLOS(part) then
                        pcall(function()
                            if mouse1press and mouse1release then
                                mouse1press(); task.wait(state.TriggerDelay); mouse1release()
                            elseif mouse1click then mouse1click() end
                        end)
                        triggerCooldown = tick() + 0.15
                        return
                    end
                end
            end
        end
    end
end

-- ---------- Build UI ----------

function M.Build(tab, ctx)
    buildFOV()

    local main = tab:AddSection("Aimbot")
    main:AddToggle("Enabled", false, function(v) state.Enabled = v end)
    main:AddToggle("Hold to aim", true, function(v) state.HoldMode = v end)
    main:AddDropdown("Hold button", {"MouseButton2","MouseButton1","E","Q"}, "MouseButton2", function(v)
        if v == "MouseButton1" then state.HoldButton = Enum.UserInputType.MouseButton1
        elseif v == "MouseButton2" then state.HoldButton = Enum.UserInputType.MouseButton2
        elseif v == "E" then state.HoldButton = Enum.KeyCode.E
        elseif v == "Q" then state.HoldButton = Enum.KeyCode.Q end
    end)
    main:AddDropdown("Target mode", {"Crosshair","Mouse","Distance","LowestHP"}, "Crosshair", function(v) state.Mode = v end)
    main:AddDropdown("Target parts", {"Head","Neck","UpperTorso","Torso","HumanoidRootPart","LowerTorso"},
                     {"Head","HumanoidRootPart","UpperTorso"}, function(v)
        local list = {}
        for k, on in pairs(v) do if on then table.insert(list, k) end end
        if #list > 0 then state.Parts = list end
    end, {Multi = true})
    main:AddSlider("FOV (radius)", 10, 800, 120, function(v) state.FOV = v end)
    main:AddSlider("Max distance (m)", 50, 5000, 1000, function(v) state.MaxDistance = v end)
    main:AddDivider()

    local aim = tab:AddSection("Smoothing & Prediction")
    aim:AddDropdown("Smoothing curve", {"Linear","Sine","Exponential"}, "Sine", function(v) state.SmoothCurve = v end)
    aim:AddSlider("Smoothness", 0, 0.95, 0.35, function(v) state.Smoothness = v end, {Decimals = 2})
    aim:AddSlider("Prediction (s)", 0, 0.6, 0.16, function(v) state.Prediction = v end, {Decimals = 2})
    aim:AddToggle("Sticky lock", true, function(v) state.Sticky = v end)
    aim:AddToggle("Auto-switch on lost", true, function(v) state.AutoSwitch = v end)

    local checks = tab:AddSection("Filters")
    checks:AddToggle("Team check", false, function(v) state.CheckTeam = v end)
    checks:AddToggle("Wall check (LOS)", true, function(v) state.CheckLOS = v end)
    checks:AddTextBox("Friend list (comma-sep)", "Alice, Bob", function(v)
        state.FriendList = {}
        for name in string.gmatch(v, "[^,]+") do
            local trimmed = name:match("^%s*(.-)%s*$")
            if trimmed ~= "" then state.FriendList[trimmed] = true end
        end
    end)

    local visuals = tab:AddSection("Visuals")
    visuals:AddToggle("Show FOV circle", true, function(v) state.ShowFOV = v end)
    visuals:AddToggle("FOV filled", false, function(v) state.FOVFilled = v end)
    visuals:AddColorPicker("FOV color", Color3.fromRGB(140,100,255), function(v) state.FOVColor = v end)
    visuals:AddToggle("Snap line to target", false, function(v) state.SnapLine = v end)

    local trig = tab:AddSection("Trigger Bot")
    trig:AddToggle("Enabled", false, function(v) state.TriggerBot = v end)
    trig:AddSlider("Window (px)", 1, 50, 6, function(v) state.TriggerWindow = v end)
    trig:AddSlider("Press delay (ms)", 0, 500, 50, function(v) state.TriggerDelay = v / 1000 end)

    -- input
    conns.inputDown = UserInputService.InputBegan:Connect(function(input, processed)
        if input.UserInputType == state.HoldButton or input.KeyCode == state.HoldButton then
            state.Held = true
        end
    end)
    conns.inputUp = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == state.HoldButton or input.KeyCode == state.HoldButton then
            state.Held = false
        end
    end)

    -- main render loop
    conns.render = RunService.RenderStepped:Connect(function()
        updateFOV()
        aimStep()
        triggerStep()
    end)
end

function M.Unload()
    for _, c in pairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    clearFOV()
    state.Enabled = false
    M.LockedTarget = nil
end

M.State = state
return M
