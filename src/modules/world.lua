--[[
    World module — Lighting overrides, fullbright, no-fog, time, FOV unlock,
    third-person zoom unlock, item ESP, chat logger.
]]

local Lighting     = game:GetService("Lighting")
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local StarterPlayer= game:GetService("StarterPlayer")

local M = {}
local state = {
    Fullbright = false,
    NoFog      = false,
    LockTime   = false,
    TimeOfDay  = 12,
    FOV        = 70,
    UnlockFOV  = false,
    UnlockZoom = false,
    ItemESP    = false,
    ItemKeyword = "",
    ChatLog    = false,
}

local saved
local function snapshot()
    if saved then return end
    saved = {
        Ambient = Lighting.Ambient,
        Bright = Lighting.Brightness,
        ColorShift_Top = Lighting.ColorShift_Top,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        FogColor = Lighting.FogColor,
        ZoomMin = StarterPlayer.CameraMinZoomDistance,
        ZoomMax = StarterPlayer.CameraMaxZoomDistance,
    }
end

local function restore()
    if not saved then return end
    Lighting.Ambient = saved.Ambient
    Lighting.Brightness = saved.Bright
    Lighting.ColorShift_Top = saved.ColorShift_Top
    Lighting.ColorShift_Bottom = saved.ColorShift_Bottom
    Lighting.OutdoorAmbient = saved.OutdoorAmbient
    Lighting.ClockTime = saved.ClockTime
    Lighting.FogEnd = saved.FogEnd
    Lighting.FogStart = saved.FogStart
    Lighting.FogColor = saved.FogColor
    pcall(function()
        StarterPlayer.CameraMinZoomDistance = saved.ZoomMin
        StarterPlayer.CameraMaxZoomDistance = saved.ZoomMax
    end)
end

local conns = {}

local function applyLighting()
    if state.Fullbright then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
        Lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    end
    if state.NoFog then
        Lighting.FogEnd = 1e9
        Lighting.FogStart = 1e9
    end
    if state.LockTime then
        Lighting.ClockTime = state.TimeOfDay
    end
end

local function applyFOV()
    local cam = Workspace.CurrentCamera
    if cam and state.UnlockFOV then
        cam.FieldOfView = state.FOV
    end
end

local function applyZoom()
    if state.UnlockZoom then
        local lp = Players.LocalPlayer
        pcall(function()
            StarterPlayer.CameraMinZoomDistance = 0.5
            StarterPlayer.CameraMaxZoomDistance = 1000
            if lp then
                lp.CameraMinZoomDistance = 0.5
                lp.CameraMaxZoomDistance = 1000
            end
        end)
    end
end

-- ---------- Item ESP ----------

local itemTags = {}
local function clearItemTags()
    for _, bb in pairs(itemTags) do bb:Destroy() end
    itemTags = {}
end

local function scanItems()
    if not state.ItemESP then clearItemTags(); return end
    local needle = state.ItemKeyword:lower()
    local seen = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") or obj:IsA("Model") then
            local name = obj.Name:lower()
            if needle ~= "" and name:find(needle, 1, true) then
                seen[obj] = true
                if not itemTags[obj] then
                    local part = obj:IsA("Tool") and obj:FindFirstChildOfClass("Part") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if part then
                        local bb = Instance.new("BillboardGui")
                        bb.AlwaysOnTop = true
                        bb.Size = UDim2.new(0, 100, 0, 20)
                        bb.StudsOffset = Vector3.new(0, 2, 0)
                        bb.Adornee = part
                        bb.Parent = part
                        local t = Instance.new("TextLabel")
                        t.BackgroundTransparency = 1
                        t.Size = UDim2.new(1, 0, 1, 0)
                        t.Font = Enum.Font.GothamBold
                        t.Text = obj.Name
                        t.TextColor3 = Color3.fromRGB(255, 200, 80)
                        t.TextStrokeTransparency = 0
                        t.TextSize = 13
                        t.Parent = bb
                        itemTags[obj] = bb
                    end
                end
            end
        end
    end
    for obj, bb in pairs(itemTags) do
        if not seen[obj] then bb:Destroy(); itemTags[obj] = nil end
    end
end

-- ---------- Chat logger ----------

local chatHookSetup = false
local chatHookSaved = {}    -- snapshot for restoration on Unload
local function setupChatLog()
    if chatHookSetup then return end
    chatHookSetup = true
    local function log(speaker, msg)
        if state.ChatLog then
            print(("[ROGBLOX chat] %s: %s"):format(speaker, msg))
        end
    end
    -- Legacy: connection-based, auto-cleans with our conns table
    pcall(function()
        local re = game:GetService("ReplicatedStorage"):WaitForChild("DefaultChatSystemChatEvents", 3)
        if re then
            conns.legacyChat = re.OnMessageDoneFiltering.OnClientEvent:Connect(function(data)
                log(data.FromSpeaker or "?", data.Message or "")
            end)
        end
    end)
    -- New TextChatService: we replace OnIncomingMessage; save the old
    -- handler so Unload can restore it (a chained game-side handler
    -- would otherwise stay clobbered).
    pcall(function()
        local tcs = game:GetService("TextChatService")
        chatHookSaved.prevOnIncoming = tcs.OnIncomingMessage
        chatHookSaved.tcs = tcs
        tcs.OnIncomingMessage = function(message)
            local props = Instance.new("TextChatMessageProperties")
            log(message.TextSource and message.TextSource.Name or "?", message.Text)
            return props
        end
    end)
end

function M.Build(tab, ctx)
    snapshot()
    setupChatLog()

    local lightSec = tab:AddSection("Lighting")
    lightSec:AddToggle("Fullbright", false, function(v)
        state.Fullbright = v
        -- When turning off, restore only the lighting properties we
        -- touched. Don't blanket-restore — that would clobber NoFog,
        -- LockTime, etc. if they're still on.
        if not v and saved then
            Lighting.Ambient        = saved.Ambient
            Lighting.Brightness     = saved.Bright
            Lighting.ColorShift_Top = saved.ColorShift_Top
            Lighting.ColorShift_Bottom = saved.ColorShift_Bottom
            Lighting.OutdoorAmbient = saved.OutdoorAmbient
        end
    end)
    lightSec:AddToggle("No fog", false, function(v)
        state.NoFog = v
        if not v and saved then
            Lighting.FogEnd   = saved.FogEnd
            Lighting.FogStart = saved.FogStart
            Lighting.FogColor = saved.FogColor
        end
    end)
    lightSec:AddToggle("Lock time", false, function(v) state.LockTime = v end)
    lightSec:AddSlider("Time of day", 0, 24, 12, function(v) state.TimeOfDay = v end)
    lightSec:AddButton("Restore defaults", function() restore() end)

    local camSec = tab:AddSection("Camera")
    camSec:AddToggle("Unlock FOV", false, function(v) state.UnlockFOV = v end)
    camSec:AddSlider("FOV", 30, 120, 70, function(v) state.FOV = v end)
    camSec:AddToggle("Unlock zoom", false, function(v) state.UnlockZoom = v applyZoom() end)

    local itemSec = tab:AddSection("Item ESP")
    itemSec:AddToggle("Enabled", false, function(v) state.ItemESP = v end)
    itemSec:AddTextBox("Keyword filter", "e.g. ammo, gun, key", function(v) state.ItemKeyword = v end)
    itemSec:AddButton("Rescan", function() scanItems() end)

    local chatSec = tab:AddSection("Chat Logger")
    chatSec:AddToggle("Log to console", false, function(v) state.ChatLog = v end)

    conns.light = RunService.Heartbeat:Connect(applyLighting)
    conns.fov = RunService.RenderStepped:Connect(applyFOV)
    conns.items = RunService.Heartbeat:Connect(function()
        if state.ItemESP and tick() % 1 < 0.04 then scanItems() end
    end)
end

function M.Unload()
    for _, c in pairs(conns) do if c.Disconnect then pcall(function() c:Disconnect() end) end end
    conns = {}
    clearItemTags()
    restore()
    if chatHookSetup and chatHookSaved.tcs then
        pcall(function()
            chatHookSaved.tcs.OnIncomingMessage = chatHookSaved.prevOnIncoming
        end)
        chatHookSetup = false
        chatHookSaved = {}
    end
end

M.State = state
return M
