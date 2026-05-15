--[[
    Aimbot module.
    Closest-to-crosshair targeting, FOV circle, optional LOS check,
    team check, head/torso priority, smoothing.
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local M = {}

local state = {
    Enabled = false,
    Held = false,
    HoldMode = false,
    FOV = 120,
    Smoothing = 0.25,
    TargetPart = "Head",
    CheckTeam = false,
    CheckLOS = true,
    ShowFOV = true,
    FOVColor = Color3.fromRGB(120, 90, 220),
    Key = Enum.UserInputType.MouseButton2,
}

local circle
local rsConn, inputBegan, inputEnded
local Players, Drawing

local function ensureCircle()
    if circle then return circle end
    circle = Drawing.new("Circle", {
        Radius = state.FOV,
        Thickness = 1,
        NumSides = 64,
        Color = state.FOVColor,
        Transparency = 1,
        Filled = false,
        Visible = false,
    })
    return circle
end

local function updateCircle()
    if not circle then return end
    local cam = Workspace.CurrentCamera
    local viewport = cam.ViewportSize
    circle.Position = Vector2.new(viewport.X / 2, viewport.Y / 2)
    circle.Radius = state.FOV
    circle.Color = state.FOVColor
    circle.Visible = state.ShowFOV and (state.Enabled or state.HoldMode)
end

local function aim()
    if not state.Enabled then return end
    if state.HoldMode and not state.Held then return end

    local cam = Workspace.CurrentCamera
    if not cam then return end
    local viewport = cam.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)

    local target = Players.ClosestToScreenPoint(center, {
        MaxFov = state.FOV,
        CheckTeam = state.CheckTeam,
        CheckLOS = state.CheckLOS,
        Part = state.TargetPart,
    })

    if not target then return end
    local part = target.Character and target.Character:FindFirstChild(state.TargetPart)
    if not part then return end

    local goal = CFrame.new(cam.CFrame.Position, part.Position)
    if state.Smoothing > 0 then
        cam.CFrame = cam.CFrame:Lerp(goal, 1 - state.Smoothing)
    else
        cam.CFrame = goal
    end
end

function M.Build(tab, ctx)
    Players = ctx.Players
    Drawing = ctx.Drawing
    ensureCircle()

    local main = tab:AddSection("Aimbot")
    main:AddToggle("Enabled", false, function(v)
        state.Enabled = v
        updateCircle()
    end)
    main:AddToggle("Hold to aim (right mouse)", false, function(v)
        state.HoldMode = v
    end)
    main:AddSlider("FOV", 20, 500, 120, function(v)
        state.FOV = v
        updateCircle()
    end)
    main:AddSlider("Smoothing", 0, 1, 0.25, function(v)
        state.Smoothing = v
    end)
    main:AddDropdown("Target part", {"Head", "HumanoidRootPart", "Torso", "UpperTorso"}, "Head", function(v)
        state.TargetPart = v
    end)
    main:AddToggle("Team check", false, function(v) state.CheckTeam = v end)
    main:AddToggle("Wall check (LOS)", true, function(v) state.CheckLOS = v end)

    local visuals = tab:AddSection("FOV Visual")
    visuals:AddToggle("Show FOV circle", true, function(v)
        state.ShowFOV = v
        updateCircle()
    end)
    visuals:AddSlider("Circle sides", 8, 128, 64, function(v)
        if circle then circle.NumSides = v end
    end)

    local triggerbot = tab:AddSection("Trigger Bot")
    local tbState = {Enabled = false, Delay = 0.05}
    triggerbot:AddToggle("Enabled", false, function(v) tbState.Enabled = v end)
    triggerbot:AddSlider("Delay (ms)", 0, 500, 50, function(v) tbState.Delay = v / 1000 end)

    rsConn = RunService.RenderStepped:Connect(function()
        updateCircle()
        aim()
        if tbState.Enabled then
            -- naive: shoot when crosshair is on player (mouse1click + release)
            local cam = Workspace.CurrentCamera
            local viewport = cam.ViewportSize
            local tgt = Players.ClosestToScreenPoint(
                Vector2.new(viewport.X/2, viewport.Y/2),
                {MaxFov = 6, CheckTeam = state.CheckTeam, CheckLOS = true, Part = state.TargetPart}
            )
            if tgt then
                pcall(function()
                    mouse1press(); task.wait(tbState.Delay); mouse1release()
                end)
            end
        end
    end)

    inputBegan = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == state.Key then
            state.Held = true
        end
    end)
    inputEnded = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == state.Key then
            state.Held = false
        end
    end)
end

function M.Unload()
    if rsConn then rsConn:Disconnect() end
    if inputBegan then inputBegan:Disconnect() end
    if inputEnded then inputEnded:Disconnect() end
    if circle and circle.Remove then pcall(function() circle:Remove() end) end
    circle = nil
end

M.State = state
return M
