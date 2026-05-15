--[[
    ESP module.
    Box, name, distance, health bar, tracers, chams.
]]

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local Workspace     = game:GetService("Workspace")
local Lighting      = game:GetService("Lighting")

local M = {}

local state = {
    Enabled    = false,
    Box        = true,
    Name       = true,
    Distance   = true,
    Health     = true,
    Tracer     = false,
    Chams      = false,
    TeamCheck  = false,
    TeamColor  = false,
    Color      = Color3.fromRGB(120, 90, 220),
    EnemyColor = Color3.fromRGB(220, 80, 90),
    AllyColor  = Color3.fromRGB(90, 200, 120),
    MaxDist    = 1000,
    TracerFrom = "Bottom", -- Bottom | Center | Top | Mouse
}

local objects = {}  -- [player] = {box, name, dist, hpBg, hpFill, tracer, chams}
local rsConn, addedConn, removingConn
local PlayersUtil, Drawing

local function colorFor(plr)
    if state.TeamColor and plr.Team and plr.TeamColor then
        return plr.TeamColor.Color
    end
    if PlayersUtil.SameTeam(plr) then
        return state.AllyColor
    end
    return state.EnemyColor
end

local function makeFor(plr)
    if objects[plr] then return end
    local set = {}
    set.box   = Drawing.new("Square", {Thickness = 1, Filled = false, Color = state.Color, Visible = false})
    set.boxOutline = Drawing.new("Square", {Thickness = 3, Filled = false, Color = Color3.new(0,0,0), Transparency = 0.5, Visible = false})
    set.name  = Drawing.new("Text", {Size = 13, Center = true, Outline = true, Color = state.Color, Visible = false, Font = 2})
    set.dist  = Drawing.new("Text", {Size = 11, Center = true, Outline = true, Color = Color3.new(1,1,1), Visible = false, Font = 2})
    set.hpBg  = Drawing.new("Square", {Thickness = 1, Filled = true, Color = Color3.fromRGB(40,40,40), Visible = false})
    set.hpFill= Drawing.new("Square", {Thickness = 1, Filled = true, Color = Color3.fromRGB(90,200,120), Visible = false})
    set.tracer= Drawing.new("Line", {Thickness = 1, Color = state.Color, Visible = false})

    -- Chams via Highlight
    local hl = Instance.new("Highlight")
    hl.Name = "ROGBLOX_Chams"
    hl.FillTransparency = 0.65
    hl.OutlineTransparency = 0
    hl.FillColor = state.Color
    hl.OutlineColor = state.Color
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = false
    set.chams = hl

    objects[plr] = set
end

local function removeFor(plr)
    local set = objects[plr]
    if not set then return end
    for _, v in pairs(set) do
        if typeof(v) == "Instance" then
            v:Destroy()
        elseif v.Remove then
            pcall(function() v:Remove() end)
        end
    end
    objects[plr] = nil
end

local function clearAll()
    for plr in pairs(objects) do removeFor(plr) end
end

local function hideSet(set)
    set.box.Visible = false
    set.boxOutline.Visible = false
    set.name.Visible = false
    set.dist.Visible = false
    set.hpBg.Visible = false
    set.hpFill.Visible = false
    set.tracer.Visible = false
    set.chams.Enabled = false
end

local function update(plr, set)
    if not state.Enabled or not PlayersUtil.IsAlive(plr) then
        hideSet(set); return
    end
    if state.TeamCheck and PlayersUtil.SameTeam(plr) then
        hideSet(set); return
    end

    local cam = Workspace.CurrentCamera
    local char = plr.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local head = char and char:FindFirstChild("Head")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not head or not hum then hideSet(set); return end

    local distance = (cam.CFrame.Position - root.Position).Magnitude
    if distance > state.MaxDist then hideSet(set); return end

    local rootScreen, onScreen = cam:WorldToViewportPoint(root.Position)
    if not onScreen then hideSet(set); return end

    local headScreen = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
    local footPos = root.Position - Vector3.new(0, 3, 0)
    local footScreen = cam:WorldToViewportPoint(footPos)

    local height = math.abs(footScreen.Y - headScreen.Y)
    local width  = height * 0.55
    local boxX = rootScreen.X - width / 2
    local boxY = headScreen.Y

    local color = colorFor(plr)

    if state.Box then
        set.box.Position = Vector2.new(boxX, boxY)
        set.box.Size = Vector2.new(width, height)
        set.box.Color = color
        set.box.Visible = true
        set.boxOutline.Position = set.box.Position
        set.boxOutline.Size = set.box.Size
        set.boxOutline.Visible = true
    else
        set.box.Visible = false
        set.boxOutline.Visible = false
    end

    if state.Name then
        set.name.Position = Vector2.new(rootScreen.X, boxY - 16)
        set.name.Text = plr.DisplayName
        set.name.Color = color
        set.name.Visible = true
    else
        set.name.Visible = false
    end

    if state.Distance then
        set.dist.Position = Vector2.new(rootScreen.X, boxY + height + 2)
        set.dist.Text = string.format("[%dm]", math.floor(distance))
        set.dist.Visible = true
    else
        set.dist.Visible = false
    end

    if state.Health then
        local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        local barH = height
        set.hpBg.Position = Vector2.new(boxX - 6, boxY)
        set.hpBg.Size = Vector2.new(3, barH)
        set.hpBg.Visible = true
        set.hpFill.Position = Vector2.new(boxX - 6, boxY + (1 - hpPct) * barH)
        set.hpFill.Size = Vector2.new(3, barH * hpPct)
        set.hpFill.Color = Color3.fromRGB(
            math.floor(255 * (1 - hpPct)),
            math.floor(200 * hpPct),
            80
        )
        set.hpFill.Visible = true
    else
        set.hpBg.Visible = false
        set.hpFill.Visible = false
    end

    if state.Tracer then
        local viewport = cam.ViewportSize
        local fromY = viewport.Y
        if state.TracerFrom == "Center" then fromY = viewport.Y / 2
        elseif state.TracerFrom == "Top" then fromY = 0 end
        set.tracer.From = Vector2.new(viewport.X / 2, fromY)
        set.tracer.To = Vector2.new(rootScreen.X, boxY + height)
        set.tracer.Color = color
        set.tracer.Visible = true
    else
        set.tracer.Visible = false
    end

    if state.Chams then
        set.chams.Adornee = char
        set.chams.FillColor = color
        set.chams.OutlineColor = color
        set.chams.Enabled = true
        if not set.chams.Parent then set.chams.Parent = char end
    else
        set.chams.Enabled = false
    end
end

function M.Build(tab, ctx)
    PlayersUtil = ctx.Players
    Drawing = ctx.Drawing

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer then makeFor(plr) end
    end
    addedConn = Players.PlayerAdded:Connect(function(plr) makeFor(plr) end)
    removingConn = Players.PlayerRemoving:Connect(function(plr) removeFor(plr) end)

    local general = tab:AddSection("ESP")
    general:AddToggle("Enabled", false, function(v)
        state.Enabled = v
        if not v then for _, s in pairs(objects) do hideSet(s) end end
    end)
    general:AddToggle("Box", true, function(v) state.Box = v end)
    general:AddToggle("Name", true, function(v) state.Name = v end)
    general:AddToggle("Distance", true, function(v) state.Distance = v end)
    general:AddToggle("Health bar", true, function(v) state.Health = v end)
    general:AddToggle("Tracers", false, function(v) state.Tracer = v end)
    general:AddToggle("Chams", false, function(v) state.Chams = v end)
    general:AddSlider("Max distance", 50, 5000, 1000, function(v) state.MaxDist = v end)

    local filters = tab:AddSection("Filters & Colors")
    filters:AddToggle("Team check (hide allies)", false, function(v) state.TeamCheck = v end)
    filters:AddToggle("Team color", false, function(v) state.TeamColor = v end)
    filters:AddDropdown("Tracer origin", {"Bottom","Center","Top"}, "Bottom", function(v) state.TracerFrom = v end)

    rsConn = RunService.RenderStepped:Connect(function()
        for plr, set in pairs(objects) do
            update(plr, set)
        end
    end)
end

function M.Unload()
    if rsConn then rsConn:Disconnect() end
    if addedConn then addedConn:Disconnect() end
    if removingConn then removingConn:Disconnect() end
    clearAll()
end

M.State = state
return M
