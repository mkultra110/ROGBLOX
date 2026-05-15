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

    conns.render = RunService.RenderStepped:Connect(function()
        updateWatermark()
        updateCrosshair()
        updateTargetPanel()
        updateArrows()
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
