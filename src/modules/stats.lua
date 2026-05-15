--[[
    Session stats tracker.

    Tracks per-session metrics derived from the local Humanoid:
        - Deaths    : Humanoid.Died fires
        - Respawns  : new character spawns
        - Damage taken : drops in Humanoid.Health (only when negative delta)
        - HP healed   : positive deltas
        - Distance traveled : sum of root.Position deltas
        - Session time : seconds since module init
        - Peak walkspeed observed
        - Currently equipped tool name

    Renders an overlay panel that the user can move and toggle. Stats
    persist across respawns (only reset when the player rejoins or
    clicks Reset).
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local M = {}
local conns = {}

local stats = {
    Deaths        = 0,
    Respawns      = 0,
    DamageTaken   = 0,
    HpHealed      = 0,
    Distance      = 0,
    SessionStart  = tick(),
    PeakSpeed     = 0,
    CurrentTool   = "",
    LastHp        = nil,
    LastPos       = nil,
}

local panel, labels = nil, {}

local THEME = {
    Bg    = Color3.fromRGB(14, 14, 20),
    Panel = Color3.fromRGB(22, 22, 32),
    Text  = Color3.fromRGB(235, 235, 245),
    Sub   = Color3.fromRGB(150, 150, 165),
    Accent= Color3.fromRGB(140, 100, 255),
    Stroke= Color3.fromRGB(48, 48, 64),
}

local state = {
    Enabled = false,
}

local function makeGui()
    local existing = (gethui and gethui() or game:GetService("CoreGui")):FindFirstChild("ROGBLOX_Stats")
    if existing then return existing end
    local g = Instance.new("ScreenGui")
    g.Name = "ROGBLOX_Stats"
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.Enabled = false
    if syn and syn.protect_gui then syn.protect_gui(g) end
    g.Parent = (gethui and gethui()) or game:GetService("CoreGui")
    return g
end

local function buildPanel()
    local gui = makeGui()
    if panel then return end

    panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0, 1)
    panel.Position = UDim2.new(0, 12, 1, -12)
    panel.Size = UDim2.new(0, 220, 0, 160)
    panel.BackgroundColor3 = THEME.Bg
    panel.BackgroundTransparency = 0.1
    panel.BorderSizePixel = 0
    panel.Parent = gui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke"); s.Color = THEME.Stroke; s.Thickness = 1; s.Parent = panel

    local title = Instance.new("TextLabel")
    title.BackgroundColor3 = THEME.Panel
    title.BorderSizePixel = 0
    title.Size = UDim2.new(1, 0, 0, 22)
    title.Font = Enum.Font.GothamBold
    title.Text = "  Session stats"
    title.TextColor3 = THEME.Text
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 6)

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 2)
    layout.Parent = panel
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 28)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = panel

    local function row(name)
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, 0, 0, 14)
        lbl.Font = Enum.Font.Code
        lbl.TextColor3 = THEME.Sub
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = name
        lbl.Parent = panel
        return lbl
    end
    labels.session    = row("session 0s")
    labels.deaths     = row("deaths 0")
    labels.respawns   = row("respawns 0")
    labels.damage     = row("damage taken 0")
    labels.healed     = row("hp healed 0")
    labels.distance   = row("distance 0m")
    labels.peakSpeed  = row("peak speed 0")
    labels.tool       = row("tool -")
end

local function attach(char)
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 3)
    local hrp = char:WaitForChild("HumanoidRootPart", 3)
    if not hum or not hrp then return end
    stats.LastHp = hum.Health
    stats.LastPos = hrp.Position

    if conns.died then conns.died:Disconnect() end
    conns.died = hum.Died:Connect(function()
        stats.Deaths = stats.Deaths + 1
    end)

    if conns.hpChanged then conns.hpChanged:Disconnect() end
    conns.hpChanged = hum.HealthChanged:Connect(function(newHp)
        if stats.LastHp then
            local delta = newHp - stats.LastHp
            if delta < 0 then
                stats.DamageTaken = stats.DamageTaken - delta
            elseif delta > 0 then
                stats.HpHealed = stats.HpHealed + delta
            end
        end
        stats.LastHp = newHp
    end)
end

local function detect()
    local lp = Players.LocalPlayer
    if not lp then return end
    if lp.Character then attach(lp.Character) end
    conns.charAdded = lp.CharacterAdded:Connect(function(c)
        stats.Respawns = stats.Respawns + 1
        attach(c)
    end)
end

local function tick_(dt)
    if not state.Enabled then panel.Visible = false; return end
    panel.Visible = true
    local lp = Players.LocalPlayer
    local char = lp and lp.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")

    if hrp and stats.LastPos then
        local d = (hrp.Position - stats.LastPos).Magnitude
        if d < 50 then  -- ignore teleports / respawns
            stats.Distance = stats.Distance + d
        end
        stats.LastPos = hrp.Position
    elseif hrp then
        stats.LastPos = hrp.Position
    end
    if hum then
        if hum.WalkSpeed > stats.PeakSpeed then stats.PeakSpeed = hum.WalkSpeed end
        local tool
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then tool = t.Name; break end
        end
        stats.CurrentTool = tool or "-"
    end

    local elapsed = math.floor(tick() - stats.SessionStart)
    local mins = math.floor(elapsed / 60)
    local secs = elapsed % 60
    labels.session.Text   = string.format("session   %dm%02ds", mins, secs)
    labels.deaths.Text    = string.format("deaths    %d", stats.Deaths)
    labels.respawns.Text  = string.format("respawns  %d", stats.Respawns)
    labels.damage.Text    = string.format("damage    %d", math.floor(stats.DamageTaken))
    labels.healed.Text    = string.format("healed    %d", math.floor(stats.HpHealed))
    labels.distance.Text  = string.format("distance  %dm", math.floor(stats.Distance))
    labels.peakSpeed.Text = string.format("peak ws   %d", math.floor(stats.PeakSpeed))
    labels.tool.Text      = "tool      " .. stats.CurrentTool
end

function M.Build(tab, ctx)
    buildPanel()
    detect()

    local sec = tab:AddSection("Session Stats")
    sec:AddToggle("Show overlay", false, function(v)
        state.Enabled = v
        if panel.Parent then panel.Parent.Enabled = v end
    end)
    sec:AddButton("Reset stats", function()
        stats.Deaths = 0; stats.Respawns = 0
        stats.DamageTaken = 0; stats.HpHealed = 0
        stats.Distance = 0; stats.PeakSpeed = 0
        stats.SessionStart = tick()
    end)
    sec:AddButton("Print to console", function()
        print(string.format(
            "[ROGBLOX stats] session %ds  deaths %d  respawns %d  damage %d  healed %d  distance %dm  peakws %d",
            math.floor(tick() - stats.SessionStart),
            stats.Deaths, stats.Respawns,
            math.floor(stats.DamageTaken), math.floor(stats.HpHealed),
            math.floor(stats.Distance), math.floor(stats.PeakSpeed)))
    end)

    conns.render = RunService.RenderStepped:Connect(tick_)
end

function M.Unload()
    for _, c in pairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    if panel and panel.Parent then panel.Parent:Destroy() end
    panel, labels = nil, {}
end

M.Stats = stats
M.State = state
return M
