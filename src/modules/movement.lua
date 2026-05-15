--[[
    Movement module — walkspeed, jump, infinite jump, fly, noclip.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")

local M = {}
local state = {
    Speed       = 16,
    SpeedEnabled= false,
    Jump        = 50,
    JumpEnabled = false,
    InfJump     = false,
    Fly         = false,
    FlySpeed    = 50,
    Noclip      = false,
    Spinbot     = false,
    SpinSpeed   = 8,
}

local hooks = {}

local function getChar()
    local lp = Players.LocalPlayer
    return lp and lp.Character
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- ---------- Speed / Jump ----------

local function applySpeed()
    local hum = getHum()
    if hum then hum.WalkSpeed = state.SpeedEnabled and state.Speed or 16 end
end

local function applyJump()
    local hum = getHum()
    if not hum then return end
    if hum.UseJumpPower then
        hum.JumpPower = state.JumpEnabled and state.Jump or 50
    else
        hum.JumpHeight = state.JumpEnabled and (state.Jump / 4) or 7.2
    end
end

-- ---------- Infinite Jump ----------

local function startInfJump()
    if hooks.infJump then return end
    hooks.infJump = UserInputService.JumpRequest:Connect(function()
        if state.InfJump then
            local hum = getHum()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)
end

-- ---------- Fly ----------

local flyBV, flyBG, flyConn

local function startFly()
    local root = getRoot()
    local hum  = getHum()
    if not root or not hum then return end

    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = root

    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyBG.P = 1000
    flyBG.D = 50
    flyBG.CFrame = root.CFrame
    flyBG.Parent = root

    flyConn = RunService.RenderStepped:Connect(function()
        if not state.Fly then return end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            dir = dir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            dir = dir - Vector3.new(0, 1, 0)
        end
        if dir.Magnitude > 0 then dir = dir.Unit end
        flyBV.Velocity = dir * state.FlySpeed
        flyBG.CFrame = cam.CFrame
    end)
end

local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
end

-- ---------- Noclip ----------

local noclipConn
local function startNoclip()
    if noclipConn then return end
    noclipConn = RunService.Stepped:Connect(function()
        if not state.Noclip then return end
        local char = getChar()
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
end
local function stopNoclip() if noclipConn then noclipConn:Disconnect(); noclipConn = nil end end

-- ---------- Spinbot ----------

local spinConn
local function startSpin()
    if spinConn then return end
    spinConn = RunService.Heartbeat:Connect(function(dt)
        if not state.Spinbot then return end
        local root = getRoot()
        if root then
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(state.SpinSpeed * 60 * dt), 0)
        end
    end)
end
local function stopSpin() if spinConn then spinConn:Disconnect(); spinConn = nil end end

-- ---------- Re-apply on respawn ----------

local function bindChar()
    local lp = Players.LocalPlayer
    if not lp then return end
    if hooks.charAdded then hooks.charAdded:Disconnect() end
    hooks.charAdded = lp.CharacterAdded:Connect(function(char)
        char:WaitForChild("Humanoid")
        task.wait(0.2)
        applySpeed(); applyJump()
        if state.Fly then stopFly(); startFly() end
    end)
end

function M.Build(tab, ctx)
    bindChar()
    startInfJump()
    startNoclip()
    startSpin()

    local speedSec = tab:AddSection("Speed & Jump")
    speedSec:AddToggle("Walkspeed override", false, function(v) state.SpeedEnabled = v; applySpeed() end)
    speedSec:AddSlider("Walkspeed", 16, 500, 50, function(v) state.Speed = v; applySpeed() end)
    speedSec:AddToggle("Jump override", false, function(v) state.JumpEnabled = v; applyJump() end)
    speedSec:AddSlider("Jump power", 50, 500, 100, function(v) state.Jump = v; applyJump() end)
    speedSec:AddToggle("Infinite jump", false, function(v) state.InfJump = v end)

    local flySec = tab:AddSection("Fly")
    flySec:AddToggle("Enabled", false, function(v)
        state.Fly = v
        if v then startFly() else stopFly() end
    end)
    flySec:AddSlider("Fly speed", 10, 300, 50, function(v) state.FlySpeed = v end)

    local clipSec = tab:AddSection("Clip")
    clipSec:AddToggle("Noclip", false, function(v) state.Noclip = v end)

    local spinSec = tab:AddSection("Spinbot")
    spinSec:AddToggle("Enabled", false, function(v) state.Spinbot = v end)
    spinSec:AddSlider("Spin speed", 1, 60, 8, function(v) state.SpinSpeed = v end)
end

function M.Unload()
    for _, h in pairs(hooks) do
        if h.Disconnect then pcall(function() h:Disconnect() end) end
    end
    hooks = {}
    stopFly(); stopNoclip(); stopSpin()
    state.SpeedEnabled = false; applySpeed()
    state.JumpEnabled = false; applyJump()
end

M.State = state
return M
