--[[
    Misc module — Anti-AFK, FPS cap, chat spam, anti-fling, freecam.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local VirtualUser      = game:GetService("VirtualUser")
local TextChatService  = game:GetService("TextChatService")
local StarterGui       = game:GetService("StarterGui")

local M = {}

local conns = {}
local alive = false

local function getHum()
    local lp = Players.LocalPlayer
    local c = lp and lp.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ---------- Chat send (legacy + new chat) ----------

local function sendChat(message)
    -- TextChatService (new chat)
    local ok = pcall(function()
        local channels = TextChatService:FindFirstChild("TextChannels")
        local general = channels and channels:FindFirstChild("RBXGeneral")
        if general then general:SendAsync(message); return end
        error("no general channel")
    end)
    if ok then return end
    -- Legacy chat
    pcall(function()
        local chatEvents = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
        if chatEvents then
            chatEvents.SayMessageRequest:FireServer(message, "All")
        end
    end)
end

function M.Build(tab, ctx)
    alive = true
    local Notify = ctx.Notify

    -- ---------- Anti-AFK ----------
    local afkSec = tab:AddSection("Anti-AFK")
    local antiAfk = false
    afkSec:AddToggle("Enabled", true, function(v)
        antiAfk = v
        Notify:Send("Anti-AFK", v and "Enabled — won't get idle-kicked." or "Disabled", 2)
    end)
    local lp = Players.LocalPlayer
    if lp then
        conns.afk = lp.Idled:Connect(function()
            if not antiAfk then return end
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
    end

    -- ---------- FPS cap ----------
    local fpsSec = tab:AddSection("Framerate")
    fpsSec:AddSlider("FPS cap", 30, 1000, 240, function(v)
        if setfpscap then pcall(setfpscap, v) end
    end)
    fpsSec:AddButton("Apply 240", function() if setfpscap then pcall(setfpscap, 240) end end)
    fpsSec:AddButton("Apply 999", function() if setfpscap then pcall(setfpscap, 999) end end)

    -- ---------- Anti-fling ----------
    local antifSec = tab:AddSection("Anti-Fling")
    local antiFling = false
    antifSec:AddToggle("Enabled", false, function(v)
        antiFling = v
    end)
    conns.antiFling = RunService.Heartbeat:Connect(function()
        if not antiFling then return end
        local lp = Players.LocalPlayer
        local char = lp and lp.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                if p.AssemblyAngularVelocity.Magnitude > 50 then
                    p.AssemblyAngularVelocity = Vector3.zero
                end
                if p.AssemblyLinearVelocity.Magnitude > 200 then
                    p.AssemblyLinearVelocity = Vector3.zero
                end
            end
        end
    end)

    -- ---------- Chat spam ----------
    local chatSec = tab:AddSection("Chat")
    local chatMsg = ""
    local chatDelay = 2
    local chatEnabled = false
    chatSec:AddTextBox("Message", "type a message...", function(v) chatMsg = v end)
    chatSec:AddSlider("Delay (sec)", 1, 30, 2, function(v) chatDelay = v end)
    chatSec:AddToggle("Spam enabled", false, function(v) chatEnabled = v end)
    chatSec:AddButton("Send once", function()
        if chatMsg ~= "" then sendChat(chatMsg) end
    end)
    task.spawn(function()
        while alive do
            task.wait(0.1)
            if chatEnabled and chatMsg ~= "" then
                sendChat(chatMsg)
                task.wait(chatDelay)
            end
        end
    end)

    -- ---------- Freecam ----------
    local freeSec = tab:AddSection("Freecam")
    local freecamOn = false
    local origSubject
    local freecamPart

    local function setFreecam(v)
        freecamOn = v
        local cam = Workspace.CurrentCamera
        if not cam then return end
        if v then
            origSubject = cam.CameraSubject
            if not freecamPart then
                freecamPart = Instance.new("Part")
                freecamPart.Anchored = true
                freecamPart.CanCollide = false
                freecamPart.Transparency = 1
                freecamPart.Size = Vector3.new(1, 1, 1)
                freecamPart.CFrame = cam.CFrame
                freecamPart.Parent = Workspace
            end
            cam.CameraType = Enum.CameraType.Custom
            cam.CameraSubject = freecamPart
        else
            cam.CameraSubject = origSubject or getHum()
            if freecamPart then freecamPart:Destroy(); freecamPart = nil end
        end
    end

    freeSec:AddToggle("Enabled (RightShift)", false, setFreecam)
    freeSec:AddKeybind("Toggle key", Enum.KeyCode.RightShift, function()
        setFreecam(not freecamOn)
    end)
    conns.freecam = RunService.RenderStepped:Connect(function()
        if not freecamOn or not freecamPart then return end
        local cam = Workspace.CurrentCamera
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then dir = dir - Vector3.new(0, 1, 0) end
        local speed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4 or 1
        freecamPart.CFrame = freecamPart.CFrame + dir * speed
    end)

    -- ---------- Notifications test ----------
    local devSec = tab:AddSection("Dev")
    devSec:AddButton("Test notification", function()
        Notify:Send("Hello", "Notifications working.", 3)
    end)
    devSec:AddButton("Unload ROGBLOX", function()
        if _G.ROGBLOX and _G.ROGBLOX.Unload then _G.ROGBLOX.Unload() end
    end)
end

function M.Unload()
    alive = false
    for _, c in pairs(conns) do
        if c.Disconnect then pcall(function() c:Disconnect() end) end
    end
    conns = {}
end

return M
