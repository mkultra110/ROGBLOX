--[[
    Player list overlay - pro spectator panel.
    Top-right sortable list of all players with name, HP bar, distance,
    team, and a quick-TP action.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local M = {}

local THEME = {
    Bg     = Color3.fromRGB(14, 14, 20),
    Panel  = Color3.fromRGB(22, 22, 32),
    Row    = Color3.fromRGB(28, 28, 40),
    RowAlt = Color3.fromRGB(34, 34, 48),
    Accent = Color3.fromRGB(140, 100, 255),
    Text   = Color3.fromRGB(235, 235, 245),
    Sub    = Color3.fromRGB(150, 150, 165),
    Good   = Color3.fromRGB(120, 220, 140),
    Warn   = Color3.fromRGB(255, 200, 80),
    Bad    = Color3.fromRGB(235, 90, 100),
    Stroke = Color3.fromRGB(48, 48, 64),
}

local state = {
    Enabled = false,
    SortMode = "Name",      -- Name | Distance | Health | Team
    MaxRows  = 20,
    ShowAlly = true,
    ShowEnemy = true,
    ShowSelf = false,
}

local gui, root, listScroll
local rowCache = {}
local conns = {}

local function buildGui()
    local g = Instance.new("ScreenGui")
    g.Name = "ROGBLOX_PlayerList"
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.Enabled = false
    if syn and syn.protect_gui then syn.protect_gui(g) end
    g.Parent = (gethui and gethui()) or game:GetService("CoreGui")

    local r = Instance.new("Frame")
    r.AnchorPoint = Vector2.new(1, 0)
    r.Position = UDim2.new(1, -12, 0, 80)
    r.Size = UDim2.new(0, 260, 0, 380)
    r.BackgroundColor3 = THEME.Bg
    r.BackgroundTransparency = 0.1
    r.BorderSizePixel = 0
    r.Parent = g
    Instance.new("UICorner", r).CornerRadius = UDim.new(0, 8)
    local s = Instance.new("UIStroke"); s.Color = THEME.Stroke; s.Thickness = 1; s.Parent = r

    local title = Instance.new("Frame")
    title.BackgroundColor3 = THEME.Panel
    title.Size = UDim2.new(1, 0, 0, 28)
    title.BorderSizePixel = 0
    title.Parent = r
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

    local titleText = Instance.new("TextLabel")
    titleText.BackgroundTransparency = 1
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.Size = UDim2.new(1, -20, 1, 0)
    titleText.Font = Enum.Font.GothamBold
    titleText.Text = "Players"
    titleText.TextColor3 = THEME.Text
    titleText.TextSize = 12
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = title

    local countLbl = Instance.new("TextLabel")
    countLbl.Name = "Count"
    countLbl.BackgroundTransparency = 1
    countLbl.AnchorPoint = Vector2.new(1, 0)
    countLbl.Position = UDim2.new(1, -10, 0, 0)
    countLbl.Size = UDim2.new(0, 60, 1, 0)
    countLbl.Font = Enum.Font.Gotham
    countLbl.Text = "0 / 0"
    countLbl.TextColor3 = THEME.Sub
    countLbl.TextSize = 11
    countLbl.TextXAlignment = Enum.TextXAlignment.Right
    countLbl.Parent = title

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "List"
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Position = UDim2.new(0, 6, 0, 32)
    scroll.Size = UDim2.new(1, -12, 1, -38)
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = THEME.Accent
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.Parent = r

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 3)
    layout.Parent = scroll

    return g, r, scroll
end

local function buildRow()
    local row = Instance.new("Frame")
    row.BackgroundColor3 = THEME.Row
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, 28)
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "Name"
    nameLbl.BackgroundTransparency = 1
    nameLbl.Position = UDim2.new(0, 8, 0, 0)
    nameLbl.Size = UDim2.new(0.55, 0, 1, 0)
    nameLbl.Font = Enum.Font.GothamMedium
    nameLbl.Text = "?"
    nameLbl.TextColor3 = THEME.Text
    nameLbl.TextSize = 11
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Parent = row

    local distLbl = Instance.new("TextLabel")
    distLbl.Name = "Dist"
    distLbl.BackgroundTransparency = 1
    distLbl.AnchorPoint = Vector2.new(1, 0)
    distLbl.Position = UDim2.new(1, -8, 0, 0)
    distLbl.Size = UDim2.new(0.3, 0, 1, 0)
    distLbl.Font = Enum.Font.Gotham
    distLbl.Text = "-"
    distLbl.TextColor3 = THEME.Sub
    distLbl.TextSize = 10
    distLbl.TextXAlignment = Enum.TextXAlignment.Right
    distLbl.Parent = row

    local hpBg = Instance.new("Frame")
    hpBg.Name = "HpBg"
    hpBg.BackgroundColor3 = THEME.Stroke
    hpBg.BorderSizePixel = 0
    hpBg.Position = UDim2.new(0, 8, 1, -4)
    hpBg.Size = UDim2.new(1, -16, 0, 2)
    hpBg.Parent = row
    Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 1)

    local hpFill = Instance.new("Frame")
    hpFill.Name = "HpFill"
    hpFill.BackgroundColor3 = THEME.Good
    hpFill.BorderSizePixel = 0
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.Parent = hpBg
    Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 1)

    -- click to TP
    local btn = Instance.new("TextButton")
    btn.Name = "Click"
    btn.BackgroundTransparency = 1
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = row

    return row, nameLbl, distLbl, hpFill, btn
end

local function updateRow(row, plr)
    local nameLbl = row:FindFirstChild("Name")
    local distLbl = row:FindFirstChild("Dist")
    local hpBg = row:FindFirstChild("HpBg")
    local hpFill = hpBg and hpBg:FindFirstChild("HpFill")
    if not (nameLbl and distLbl and hpFill) then return end

    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local lp = Players.LocalPlayer
    local myRoot = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")

    nameLbl.Text = plr.DisplayName
    if plr == lp then
        nameLbl.TextColor3 = THEME.Accent
    elseif plr.Team and lp and lp.Team and plr.Team == lp.Team then
        nameLbl.TextColor3 = THEME.Good
    else
        nameLbl.TextColor3 = THEME.Bad
    end

    if hum and hrp and myRoot then
        local d = (hrp.Position - myRoot.Position).Magnitude
        distLbl.Text = string.format("%dm", math.floor(d))
        local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        hpFill.Size = UDim2.new(pct, 0, 1, 0)
        hpFill.BackgroundColor3 = (pct > 0.5 and THEME.Good) or (pct > 0.25 and THEME.Warn) or THEME.Bad
    else
        distLbl.Text = "-"
        hpFill.Size = UDim2.new(0, 0, 1, 0)
    end
end

local function sortPlayers(list)
    local lp = Players.LocalPlayer
    local myRoot = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    table.sort(list, function(a, b)
        if state.SortMode == "Name" then
            return a.Name:lower() < b.Name:lower()
        elseif state.SortMode == "Distance" then
            local ah = a.Character and a.Character:FindFirstChild("HumanoidRootPart")
            local bh = b.Character and b.Character:FindFirstChild("HumanoidRootPart")
            if not (ah and bh and myRoot) then return a.Name < b.Name end
            return (ah.Position - myRoot.Position).Magnitude < (bh.Position - myRoot.Position).Magnitude
        elseif state.SortMode == "Health" then
            local ah = a.Character and a.Character:FindFirstChildOfClass("Humanoid")
            local bh = b.Character and b.Character:FindFirstChildOfClass("Humanoid")
            return (ah and ah.Health or 0) > (bh and bh.Health or 0)
        elseif state.SortMode == "Team" then
            return tostring(a.Team) < tostring(b.Team)
        end
        return false
    end)
end

local function filterPlayer(plr)
    local lp = Players.LocalPlayer
    if plr == lp and not state.ShowSelf then return false end
    if plr ~= lp and plr.Team and lp and lp.Team then
        if plr.Team == lp.Team and not state.ShowAlly then return false end
        if plr.Team ~= lp.Team and not state.ShowEnemy then return false end
    end
    return true
end

local function refresh()
    if not state.Enabled or not gui then return end
    local all = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if filterPlayer(plr) then table.insert(all, plr) end
    end
    sortPlayers(all)

    local needed = math.min(#all, state.MaxRows)
    for i = 1, needed do
        local row = rowCache[i]
        if not row then
            row = buildRow()
            row.LayoutOrder = i
            row.Parent = listScroll
            rowCache[i] = row
            row:FindFirstChild("Click").MouseButton1Click:Connect(function()
                -- quick-TP behind player
                local plr = row:GetAttribute("Player") and Players:FindFirstChild(row:GetAttribute("Player"))
                if not plr then return end
                local target = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                local me = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if target and me then
                    me.CFrame = target.CFrame * CFrame.new(0, 0, 3)
                end
            end)
        end
        row:SetAttribute("Player", all[i].Name)
        row.Visible = true
        updateRow(row, all[i])
    end
    for i = needed + 1, #rowCache do
        if rowCache[i] then rowCache[i].Visible = false end
    end
    local countLbl = root and root:FindFirstChild("Count", true)
    if countLbl then countLbl.Text = #all .. " / " .. #Players:GetPlayers() end
end

function M.Build(tab, ctx)
    gui, root, listScroll = buildGui()

    local sec = tab:AddSection("Player List Overlay")
    sec:AddToggle("Enabled", false, function(v)
        state.Enabled = v
        gui.Enabled = v
    end)
    sec:AddDropdown("Sort by", {"Name","Distance","Health","Team"}, "Distance", function(v) state.SortMode = v end)
    sec:AddSlider("Max rows", 4, 40, 20, function(v) state.MaxRows = v end)
    sec:AddToggle("Show allies", true, function(v) state.ShowAlly = v end)
    sec:AddToggle("Show enemies", true, function(v) state.ShowEnemy = v end)
    sec:AddToggle("Show self", false, function(v) state.ShowSelf = v end)

    conns.tick = RunService.Heartbeat:Connect(function()
        if tick() % 0.25 < 0.02 then refresh() end
    end)
end

function M.Unload()
    for _, c in pairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    if gui then gui:Destroy() end
    gui, root, listScroll, rowCache = nil, nil, nil, {}
end

M.State = state
return M
