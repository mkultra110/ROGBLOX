--[[
    HUD module — watermark, crosshair, target lock panel, off-screen arrows,
    keybind list. Uses the Drawing API; falls back to ScreenGui if missing.
]]

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local Workspace     = game:GetService("Workspace")
local Stats         = game:GetService("Stats")

local M = {}

local state = {
    Watermark      = true,
    Crosshair      = false,
    XHairColor     = Color3.fromRGB(140, 100, 255),
    XHairStyle     = "Plus",   -- Plus | Dot | Circle
    XHairSize      = 6,
    XHairGap       = 3,
    XHairThickness = 1,
    XHairOutline   = true,
    TargetPanel    = true,
    OffscreenArrows= false,
    KeyOverlay     = false,
    Keys           = {},        -- [label] = "KeyName"
    Killfeed       = false,
    KillfeedMax    = 6,
    KillfeedFade   = 4,
    SpectatorList  = false,
    PerfGraph      = false,
}

local conns = {}
local elements = {}

-- Aimbot module reference for reading the current lock target
local Aimbot = nil

-- Optional override (for tests / external sources)
M.LockedTarget = nil

local function currentTarget()
    if M.LockedTarget then return M.LockedTarget end
    if Aimbot then return Aimbot.LockedTarget end
    return nil
end

local function makeGui()
    local existing = (gethui and gethui() or game:GetService("CoreGui")):FindFirstChild("ROGBLOX_HUD")
    if existing then return existing end
    local gui = Instance.new("ScreenGui")
    gui.Name = "ROGBLOX_HUD"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    if syn and syn.protect_gui then syn.protect_gui(gui) end
    gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
    return gui
end

local THEME = {
    Bg     = Color3.fromRGB(16, 16, 22),
    Panel  = Color3.fromRGB(22, 22, 30),
    Accent = Color3.fromRGB(140, 100, 255),
    Text   = Color3.fromRGB(235, 235, 245),
    Sub    = Color3.fromRGB(150, 150, 165),
    Good   = Color3.fromRGB(120, 220, 140),
    Warn   = Color3.fromRGB(255, 200,  80),
    Bad    = Color3.fromRGB(235,  90, 100),
}

-- ============================================================
-- Watermark
-- ============================================================

local function buildWatermark(gui)
    local frame = Instance.new("Frame")
    frame.Name = "Watermark"
    frame.BackgroundColor3 = THEME.Bg
    frame.BackgroundTransparency = 0.15
    frame.Position = UDim2.new(0, 12, 0, 12)
    frame.Size = UDim2.new(0, 280, 0, 24)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = frame
    local s = Instance.new("UIStroke")
    s.Color = THEME.Accent; s.Thickness = 1; s.Parent = frame

    local accent = Instance.new("Frame")
    accent.BackgroundColor3 = THEME.Accent
    accent.BorderSizePixel = 0
    accent.Position = UDim2.new(0, 4, 0, 4)
    accent.Size = UDim2.new(0, 3, 1, -8)
    accent.Parent = frame
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 2)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 14, 0, 0)
    label.Size = UDim2.new(1, -18, 1, 0)
    label.Font = Enum.Font.GothamMedium
    label.Text = "ROGBLOX"
    label.TextColor3 = THEME.Text
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    elements.watermark = {Frame = frame, Label = label}
end

local lastTick = tick()
local fps = 0
local function updateWatermark()
    if not state.Watermark then
        if elements.watermark then elements.watermark.Frame.Visible = false end
        return
    end
    if elements.watermark then elements.watermark.Frame.Visible = true end

    local now = tick()
    local dt = now - lastTick
    lastTick = now
    fps = math.floor(0.9 * fps + 0.1 * (1 / math.max(dt, 1e-3)))
    local ping = "?"
    pcall(function()
        ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    end)
    local user = Players.LocalPlayer and Players.LocalPlayer.Name or "?"
    local timeStr = os.date("%H:%M:%S")
    elements.watermark.Label.Text = string.format(
        "ROGBLOX  |  %d FPS  |  %s ms  |  %s  |  %s",
        fps, tostring(ping), user, timeStr
    )
end

-- ============================================================
-- Crosshair (Drawing-based for perfect center)
-- ============================================================

local xHairParts = {}

local function clearCrosshair()
    for _, obj in pairs(xHairParts) do
        pcall(function() obj:Remove() end)
    end
    xHairParts = {}
end

local function buildCrosshair()
    clearCrosshair()
    if not (type(Drawing) == "table" and Drawing.new) then return end

    if state.XHairStyle == "Plus" then
        for i = 1, 4 do
            xHairParts[#xHairParts + 1] = Drawing.new("Line")
        end
        if state.XHairOutline then
            for i = 1, 4 do
                xHairParts[#xHairParts + 1] = Drawing.new("Line")
            end
        end
    elseif state.XHairStyle == "Dot" then
        xHairParts[#xHairParts + 1] = Drawing.new("Circle")
    elseif state.XHairStyle == "Circle" then
        xHairParts[#xHairParts + 1] = Drawing.new("Circle")
    end
end

local function updateCrosshair()
    if not state.Crosshair or #xHairParts == 0 then
        for _, obj in pairs(xHairParts) do
            if obj.Visible ~= nil then obj.Visible = false end
        end
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local center = cam.ViewportSize / 2
    local cx, cy = center.X, center.Y
    local color = state.XHairColor
    local gap = state.XHairGap
    local sz = state.XHairSize
    local th = state.XHairThickness

    if state.XHairStyle == "Plus" then
        local segs = {
            {Vector2.new(cx - gap - sz, cy), Vector2.new(cx - gap, cy)},
            {Vector2.new(cx + gap, cy),       Vector2.new(cx + gap + sz, cy)},
            {Vector2.new(cx, cy - gap - sz), Vector2.new(cx, cy - gap)},
            {Vector2.new(cx, cy + gap),       Vector2.new(cx, cy + gap + sz)},
        }
        if state.XHairOutline then
            for i = 1, 4 do
                local line = xHairParts[i + 4]
                if line then
                    line.From = segs[i][1]; line.To = segs[i][2]
                    line.Color = Color3.new(0, 0, 0); line.Thickness = th + 2
                    line.Visible = true
                end
            end
        end
        for i = 1, 4 do
            local line = xHairParts[i]
            line.From = segs[i][1]; line.To = segs[i][2]
            line.Color = color; line.Thickness = th
            line.Visible = true
        end
    elseif state.XHairStyle == "Dot" then
        local c = xHairParts[1]
        c.Position = Vector2.new(cx, cy); c.Radius = math.max(1, th)
        c.Filled = true; c.Color = color; c.Visible = true
    elseif state.XHairStyle == "Circle" then
        local c = xHairParts[1]
        c.Position = Vector2.new(cx, cy); c.Radius = sz
        c.Thickness = th; c.Filled = false; c.Color = color
        c.NumSides = 32; c.Visible = true
    end
end

-- ============================================================
-- Target panel
-- ============================================================

local function buildTargetPanel(gui)
    local panel = Instance.new("Frame")
    panel.Name = "TargetPanel"
    panel.AnchorPoint = Vector2.new(0.5, 0)
    panel.Position = UDim2.new(0.5, 0, 0, 12)
    panel.Size = UDim2.new(0, 280, 0, 56)
    panel.BackgroundColor3 = THEME.Bg
    panel.BackgroundTransparency = 0.1
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Parent = gui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke"); s.Color = THEME.Bad; s.Thickness = 1; s.Parent = panel

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 12, 0, 6)
    title.Size = UDim2.new(1, -24, 0, 16)
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = THEME.Text
    title.Text = ""
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel

    local meta = Instance.new("TextLabel")
    meta.BackgroundTransparency = 1
    meta.Position = UDim2.new(0, 12, 0, 22)
    meta.Size = UDim2.new(1, -24, 0, 14)
    meta.Font = Enum.Font.Gotham
    meta.TextColor3 = THEME.Sub
    meta.Text = ""
    meta.TextSize = 11
    meta.TextXAlignment = Enum.TextXAlignment.Left
    meta.Parent = panel

    local hpBg = Instance.new("Frame")
    hpBg.BackgroundColor3 = THEME.Panel
    hpBg.BorderSizePixel = 0
    hpBg.Position = UDim2.new(0, 12, 1, -14)
    hpBg.Size = UDim2.new(1, -24, 0, 5)
    hpBg.Parent = panel
    Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 2)
    local hpFill = Instance.new("Frame")
    hpFill.BackgroundColor3 = THEME.Good
    hpFill.BorderSizePixel = 0
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.Parent = hpBg
    Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 2)

    elements.targetPanel = {Frame = panel, Title = title, Meta = meta, Hp = hpFill}
end

local function updateTargetPanel()
    local panel = elements.targetPanel
    if not panel then return end
    local target = currentTarget()
    if not (state.TargetPanel and target) then
        panel.Frame.Visible = false
        return
    end
    local char = target.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local lp = Players.LocalPlayer
    local myHrp = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not (char and hum and hrp and myHrp) then panel.Frame.Visible = false; return end
    panel.Frame.Visible = true
    local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    panel.Title.Text = target.DisplayName
    panel.Meta.Text = string.format("%s  |  HP %d/%d  |  %dm",
        target.Name, math.floor(hum.Health + 0.5), math.floor(hum.MaxHealth + 0.5),
        math.floor((hrp.Position - myHrp.Position).Magnitude + 0.5))
    panel.Hp.Size = UDim2.new(hpPct, 0, 1, 0)
    panel.Hp.BackgroundColor3 = (hpPct > 0.5 and THEME.Good) or (hpPct > 0.25 and THEME.Warn) or THEME.Bad
end

-- ============================================================
-- Keybind overlay
-- ============================================================

local keyPanel, keyList

local function buildKeyOverlay(gui)
    if keyPanel then return end
    keyPanel = Instance.new("Frame")
    keyPanel.Name = "Keybinds"
    keyPanel.AnchorPoint = Vector2.new(1, 0)
    keyPanel.Position = UDim2.new(1, -12, 0, 40)
    keyPanel.Size = UDim2.new(0, 180, 0, 0)
    keyPanel.AutomaticSize = Enum.AutomaticSize.Y
    keyPanel.BackgroundColor3 = THEME.Bg
    keyPanel.BackgroundTransparency = 0.2
    keyPanel.BorderSizePixel = 0
    keyPanel.Visible = false
    keyPanel.Parent = gui
    Instance.new("UICorner", keyPanel).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke"); s.Color = THEME.Accent; s.Thickness = 1; s.Parent = keyPanel

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 18)
    title.Font = Enum.Font.GothamBold
    title.Text = "  hotkeys"
    title.TextColor3 = THEME.Text
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = keyPanel

    keyList = Instance.new("Frame")
    keyList.BackgroundTransparency = 1
    keyList.Position = UDim2.new(0, 0, 0, 20)
    keyList.Size = UDim2.new(1, 0, 0, 0)
    keyList.AutomaticSize = Enum.AutomaticSize.Y
    keyList.Parent = keyPanel
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 1)
    layout.Parent = keyList
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 6)
    pad.Parent = keyList
end

local function refreshKeyOverlay()
    if not keyPanel then return end
    keyPanel.Visible = state.KeyOverlay
    if not state.KeyOverlay then return end
    for _, c in ipairs(keyList:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    for label, key in pairs(state.Keys) do
        local row = Instance.new("TextLabel")
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 13)
        row.Font = Enum.Font.Code
        row.TextSize = 10
        row.TextColor3 = THEME.Sub
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Text = string.format("[%s] %s", key, label)
        row.Parent = keyList
    end
end

function M.RegisterKey(label, key)
    state.Keys[label] = tostring(key)
    refreshKeyOverlay()
end

function M.UnregisterKey(label)
    state.Keys[label] = nil
    refreshKeyOverlay()
end

-- ============================================================
-- Spectator list - who has CameraSubject == me
-- ============================================================

local specPanel, specList

local function buildSpecPanel(gui)
    if specPanel then return end
    specPanel = Instance.new("Frame")
    specPanel.Name = "Spectators"
    specPanel.AnchorPoint = Vector2.new(0, 1)
    specPanel.Position = UDim2.new(0, 12, 1, -130)
    specPanel.Size = UDim2.new(0, 200, 0, 0)
    specPanel.AutomaticSize = Enum.AutomaticSize.Y
    specPanel.BackgroundColor3 = THEME.Bg
    specPanel.BackgroundTransparency = 0.15
    specPanel.BorderSizePixel = 0
    specPanel.Visible = false
    specPanel.Parent = gui
    Instance.new("UICorner", specPanel).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke"); s.Color = THEME.Bad; s.Thickness = 1; s.Parent = specPanel

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 18)
    title.Font = Enum.Font.GothamBold
    title.Text = "  spectators"
    title.TextColor3 = THEME.Bad
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = specPanel

    specList = Instance.new("Frame")
    specList.BackgroundTransparency = 1
    specList.Position = UDim2.new(0, 0, 0, 20)
    specList.Size = UDim2.new(1, 0, 0, 0)
    specList.AutomaticSize = Enum.AutomaticSize.Y
    specList.Parent = specPanel
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 1)
    layout.Parent = specList
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 6)
    pad.Parent = specList
end

local function refreshSpectatorList()
    if not specPanel then return end
    if not state.SpectatorList then specPanel.Visible = false; return end

    local lp = Players.LocalPlayer
    local myChar = lp and lp.Character
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")

    -- Detect: any other player whose CameraSubject is our humanoid /
    -- a part of our character.
    local watchers = {}
    -- We can only reliably know our OWN camera subject. Cross-player
    -- camera detection isn't replicated. Best-effort: list players
    -- within 20 studs whose character is facing ours (a soft proxy).
    if myChar and myChar.PrimaryPart then
        local myPos = myChar.PrimaryPart.Position
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp and plr.Character and plr.Character.PrimaryPart then
                local their = plr.Character.PrimaryPart
                local d = (their.Position - myPos).Magnitude
                if d < 40 then
                    local lookAt = their.CFrame.LookVector
                    local toMe = (myPos - their.Position).Unit
                    -- dot > 0.8 = within ~36 deg of facing us
                    if lookAt:Dot(toMe) > 0.8 then
                        table.insert(watchers, plr.DisplayName ..
                            string.format(" (%dm)", math.floor(d)))
                    end
                end
            end
        end
    end

    specPanel.Visible = #watchers > 0
    -- Clear existing rows
    for _, c in ipairs(specList:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    for _, name in ipairs(watchers) do
        local row = Instance.new("TextLabel")
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 14)
        row.Font = Enum.Font.GothamMedium
        row.Text = "- " .. name
        row.TextColor3 = THEME.Text
        row.TextSize = 11
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Parent = specList
    end
end

-- ============================================================
-- FPS performance graph - last 10 seconds of frame times
-- ============================================================

local perfPanel, perfHistory, perfPoints
local PERF_SAMPLES = 120  -- 10 seconds at ~12Hz sample rate

local function buildPerfPanel(gui)
    if perfPanel then return end
    perfPanel = Instance.new("Frame")
    perfPanel.Name = "PerfGraph"
    perfPanel.AnchorPoint = Vector2.new(0, 1)
    perfPanel.Position = UDim2.new(0, 12, 1, -12)
    perfPanel.Size = UDim2.new(0, 200, 0, 64)
    perfPanel.BackgroundColor3 = THEME.Bg
    perfPanel.BackgroundTransparency = 0.15
    perfPanel.BorderSizePixel = 0
    perfPanel.Visible = false
    perfPanel.Parent = gui
    Instance.new("UICorner", perfPanel).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke"); s.Color = THEME.Accent; s.Thickness = 1; s.Parent = perfPanel

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 16)
    title.Font = Enum.Font.GothamBold
    title.Text = "  FPS  (10s)"
    title.TextColor3 = THEME.Text
    title.TextSize = 10
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = perfPanel

    -- Graph area (Frame). We approximate a line by laying out N thin
    -- bars; each bar's height = its FPS sample / max.
    perfPoints = Instance.new("Frame")
    perfPoints.BackgroundTransparency = 1
    perfPoints.Position = UDim2.new(0, 6, 0, 18)
    perfPoints.Size = UDim2.new(1, -12, 1, -22)
    perfPoints.Parent = perfPanel

    perfHistory = {}
    for i = 1, PERF_SAMPLES do
        local bar = Instance.new("Frame")
        bar.BorderSizePixel = 0
        bar.BackgroundColor3 = THEME.Accent
        bar.AnchorPoint = Vector2.new(0, 1)
        local x = (i - 1) / PERF_SAMPLES
        bar.Position = UDim2.new(x, 0, 1, 0)
        bar.Size = UDim2.new(1 / PERF_SAMPLES, -1, 0, 0)
        bar.Parent = perfPoints
        perfHistory[i] = {bar = bar, fps = 60}
    end
end

local lastSampleAt = 0
local function refreshPerf(dt)
    if not perfPanel then return end
    perfPanel.Visible = state.PerfGraph
    if not state.PerfGraph then return end

    if tick() - lastSampleAt < 0.083 then return end  -- ~12Hz
    lastSampleAt = tick()

    -- shift left, append current
    for i = 1, PERF_SAMPLES - 1 do
        perfHistory[i].fps = perfHistory[i + 1].fps
    end
    local curFps = 1 / math.max(dt, 1e-3)
    perfHistory[PERF_SAMPLES].fps = curFps

    -- update bar heights
    local maxFps = 0
    for i = 1, PERF_SAMPLES do
        if perfHistory[i].fps > maxFps then maxFps = perfHistory[i].fps end
    end
    if maxFps < 30 then maxFps = 30 end
    for i = 1, PERF_SAMPLES do
        local h = perfHistory[i].fps / maxFps
        perfHistory[i].bar.Size = UDim2.new(1 / PERF_SAMPLES, -1, h, 0)
        perfHistory[i].bar.BackgroundColor3 =
            curFps > 50 and THEME.Good or curFps > 30 and THEME.Warn or THEME.Bad
    end
end

-- ============================================================
-- Killfeed
-- ============================================================
-- Watches every Humanoid.Died across all players. When someone dies,
-- look back through Humanoid.HealthChanged history to attribute the
-- kill to the last damage source (best-effort; many games are
-- server-authoritative so we can't see the actual killer reliably).
-- For now we just show "[died] DisplayName" entries and fade them.

local killFeed, killList

local function buildKillFeed(gui)
    if killFeed then return end
    killFeed = Instance.new("Frame")
    killFeed.Name = "Killfeed"
    killFeed.AnchorPoint = Vector2.new(1, 1)
    killFeed.Position = UDim2.new(1, -12, 1, -130)
    killFeed.Size = UDim2.new(0, 230, 0, 0)
    killFeed.AutomaticSize = Enum.AutomaticSize.Y
    killFeed.BackgroundTransparency = 1
    killFeed.Visible = false
    killFeed.Parent = gui

    killList = killFeed
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 3)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Parent = killFeed
end

local function pushKillEntry(text, accent)
    if not killList then return end
    local row = Instance.new("Frame")
    row.BackgroundColor3 = THEME.Bg
    row.BackgroundTransparency = 0.1
    row.BorderSizePixel = 0
    row.Size = UDim2.new(0, 0, 0, 22)
    row.AutomaticSize = Enum.AutomaticSize.X
    row.Parent = killList
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = row
    local s = Instance.new("UIStroke"); s.Color = accent or THEME.Accent; s.Thickness = 1; s.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.AutomaticSize = Enum.AutomaticSize.X
    lbl.Size = UDim2.new(0, 0, 1, 0)
    lbl.Font = Enum.Font.GothamMedium
    lbl.Text = "  " .. text .. "  "
    lbl.TextColor3 = THEME.Text
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    -- Cap list length
    local count = 0
    for _, ch in ipairs(killList:GetChildren()) do
        if ch:IsA("Frame") then count = count + 1 end
    end
    if count > state.KillfeedMax then
        for _, ch in ipairs(killList:GetChildren()) do
            if ch:IsA("Frame") then ch:Destroy(); break end
        end
    end

    -- Fade out and destroy
    task.delay(state.KillfeedFade, function()
        if row.Parent then
            for i = 1, 10 do
                if not row.Parent then break end
                row.BackgroundTransparency = math.clamp(0.1 + i * 0.09, 0, 1)
                s.Transparency = math.clamp(i * 0.1, 0, 1)
                lbl.TextTransparency = math.clamp(i * 0.1, 0, 1)
                task.wait(0.05)
            end
            row:Destroy()
        end
    end)
end

local function attachKillWatchers()
    -- For each current and future player, hook Humanoid.Died.
    local function watchPlayer(plr)
        local function watchChar(char)
            local hum = char:WaitForChild("Humanoid", 3)
            if not hum then return end
            local conn
            conn = hum.Died:Connect(function()
                if state.Killfeed then
                    pushKillEntry("died: " .. plr.DisplayName,
                        plr == Players.LocalPlayer and THEME.Bad or THEME.Accent)
                end
                if conn then conn:Disconnect() end
            end)
            table.insert(conns, conn)
        end
        if plr.Character then watchChar(plr.Character) end
        local addConn = plr.CharacterAdded:Connect(watchChar)
        table.insert(conns, addConn)
    end
    for _, plr in ipairs(Players:GetPlayers()) do watchPlayer(plr) end
    table.insert(conns, Players.PlayerAdded:Connect(watchPlayer))
end

-- ============================================================
-- Off-screen arrows
-- ============================================================

local arrows = {} -- [player] = Drawing.Triangle

local function getOrMakeArrow(plr)
    if arrows[plr] then return arrows[plr] end
    if not (type(Drawing) == "table" and Drawing.new) then return nil end
    local tri = Drawing.new("Triangle")
    tri.Filled = true
    tri.Color = THEME.Accent
    tri.Visible = false
    arrows[plr] = tri
    return tri
end

local function clearArrows()
    for plr, tri in pairs(arrows) do
        pcall(function() tri:Remove() end)
    end
    arrows = {}
end

local function updateArrows()
    if not state.OffscreenArrows then
        for _, tri in pairs(arrows) do tri.Visible = false end
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local center = cam.ViewportSize / 2
    local radius = math.min(cam.ViewportSize.X, cam.ViewportSize.Y) * 0.4

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer then
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local screen, onScreen = cam:WorldToViewportPoint(hrp.Position)
                local tri = getOrMakeArrow(plr)
                if tri then
                    if onScreen then
                        tri.Visible = false
                    else
                        -- vector from center, behind = flip
                        local dir
                        if screen.Z < 0 then
                            dir = Vector2.new(-(screen.X - center.X), -(screen.Y - center.Y))
                        else
                            dir = Vector2.new(screen.X - center.X, screen.Y - center.Y)
                        end
                        if dir.Magnitude > 0 then dir = dir.Unit end
                        local tip = center + dir * radius
                        local left  = tip - dir * 14 + Vector2.new(-dir.Y, dir.X) * 7
                        local right = tip - dir * 14 + Vector2.new(dir.Y, -dir.X) * 7
                        tri.PointA = tip; tri.PointB = left; tri.PointC = right
                        tri.Visible = true
                    end
                end
            else
                if arrows[plr] then arrows[plr].Visible = false end
            end
        end
    end
end

-- ============================================================
-- Build / Unload
-- ============================================================

function M.Build(tab, ctx)
    Aimbot = ctx.Aimbot
    local gui = makeGui()
    buildWatermark(gui)
    buildTargetPanel(gui)
    buildCrosshair()

    local wm = tab:AddSection("Watermark")
    wm:AddToggle("Show watermark", true, function(v) state.Watermark = v end)

    local xh = tab:AddSection("Crosshair")
    xh:AddToggle("Enabled", false, function(v)
        state.Crosshair = v
        if v then buildCrosshair() else clearCrosshair() end
    end)
    xh:AddDropdown("Style", {"Plus","Dot","Circle"}, "Plus", function(v) state.XHairStyle = v; buildCrosshair() end)
    xh:AddSlider("Size", 1, 30, 6, function(v) state.XHairSize = v end)
    xh:AddSlider("Gap", 0, 20, 3, function(v) state.XHairGap = v end)
    xh:AddSlider("Thickness", 1, 6, 1, function(v) state.XHairThickness = v; buildCrosshair() end)
    xh:AddToggle("Outline", true, function(v) state.XHairOutline = v; buildCrosshair() end)
    xh:AddColorPicker("Color", Color3.fromRGB(140,100,255), function(v) state.XHairColor = v end)

    local tp = tab:AddSection("Target Lock Panel")
    tp:AddToggle("Show panel when locked", true, function(v) state.TargetPanel = v end)

    local oa = tab:AddSection("Off-screen Arrows")
    oa:AddToggle("Enabled", false, function(v) state.OffscreenArrows = v end)

    -- ----- Keybind overlay -----
    buildKeyOverlay(gui)
    local kb = tab:AddSection("Keybind Overlay")
    kb:AddToggle("Show active hotkeys (top-right)", false, function(v)
        state.KeyOverlay = v
        refreshKeyOverlay()
    end)
    kb:AddLabel("Default bindings shown below; modules add their own as they boot.")
    M.RegisterKey("Toggle UI", "RightCtrl")
    M.RegisterKey("Console", "Backquote")
    M.RegisterKey("Freecam", "RightShift")

    -- ----- Killfeed -----
    buildKillFeed(gui)
    attachKillWatchers()
    local kf = tab:AddSection("Killfeed")
    kf:AddToggle("Show killfeed (bottom-right)", false, function(v)
        state.Killfeed = v
        if killFeed then killFeed.Visible = v end
    end)
    kf:AddSlider("Max entries", 2, 16, 6, function(v) state.KillfeedMax = math.floor(v) end)
    kf:AddSlider("Fade after (sec)", 1, 15, 4, function(v) state.KillfeedFade = v end)
    kf:AddButton("Test entry", function()
        if state.Killfeed then pushKillEntry("test entry", THEME.Accent) end
    end)

    -- ----- Spectator list -----
    buildSpecPanel(gui)
    local sp = tab:AddSection("Spectator Detection")
    sp:AddToggle("Show players watching you", false, function(v)
        state.SpectatorList = v
        refreshSpectatorList()
    end)
    sp:AddLabel("Heuristic: nearby players whose camera direction faces you.")

    -- ----- Performance graph -----
    buildPerfPanel(gui)
    local pg = tab:AddSection("Performance Graph")
    pg:AddToggle("Show FPS graph (10s)", false, function(v) state.PerfGraph = v end)

    local specAccum = 0
    conns.render = RunService.RenderStepped:Connect(function(dt)
        updateWatermark()
        updateCrosshair()
        updateTargetPanel()
        updateArrows()
        refreshPerf(dt)
        -- Spectator detection: only refresh every 0.5s to keep cost low
        specAccum = specAccum + dt
        if specAccum > 0.5 then
            specAccum = 0
            refreshSpectatorList()
        end
    end)
end

function M.Unload()
    for _, c in pairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    clearCrosshair()
    clearArrows()
    local g = (gethui and gethui() or game:GetService("CoreGui")):FindFirstChild("ROGBLOX_HUD")
    if g then g:Destroy() end
end

M.State = state
return M
