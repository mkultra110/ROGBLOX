--[[
    Notify — small toast notifications in the top-right.
]]

local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local Notify = {}

local container

local function ensureContainer()
    if container and container.Parent then return container end
    local gui = Instance.new("ScreenGui")
    gui.Name = "ROGBLOX_Notify"
    gui.ResetOnSpawn = false
    if syn and syn.protect_gui then syn.protect_gui(gui) end
    gui.Parent = (gethui and gethui()) or CoreGui

    local list = Instance.new("Frame")
    list.Name = "List"
    list.AnchorPoint = Vector2.new(1, 0)
    list.Position = UDim2.new(1, -12, 0, 12)
    list.Size = UDim2.new(0, 260, 1, -24)
    list.BackgroundTransparency = 1
    list.Parent = gui

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.Parent = list

    container = list
    return container
end

function Notify:Send(title, body, duration)
    duration = duration or 3
    local parent = ensureContainer()

    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundTransparency = 1
    card.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(120, 90, 220)
    stroke.Thickness = 1
    stroke.Transparency = 1
    stroke.Parent = card

    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft   = UDim.new(0, 10)
    pad.PaddingRight  = UDim.new(0, 10)
    pad.Parent = card

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, 0, 0, 16)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
    titleLabel.TextTransparency = 1
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = card

    local bodyLabel = Instance.new("TextLabel")
    bodyLabel.BackgroundTransparency = 1
    bodyLabel.Position = UDim2.new(0, 0, 0, 18)
    bodyLabel.Size = UDim2.new(1, 0, 0, 0)
    bodyLabel.AutomaticSize = Enum.AutomaticSize.Y
    bodyLabel.Font = Enum.Font.Gotham
    bodyLabel.Text = body
    bodyLabel.TextWrapped = true
    bodyLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
    bodyLabel.TextTransparency = 1
    bodyLabel.TextSize = 11
    bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
    bodyLabel.Parent = card

    local inT  = TweenInfo.new(0.2, Enum.EasingStyle.Sine)
    local outT = TweenInfo.new(0.25, Enum.EasingStyle.Sine)

    TweenService:Create(card, inT, {BackgroundTransparency = 0}):Play()
    TweenService:Create(stroke, inT, {Transparency = 0}):Play()
    TweenService:Create(titleLabel, inT, {TextTransparency = 0}):Play()
    TweenService:Create(bodyLabel, inT, {TextTransparency = 0}):Play()

    task.delay(duration, function()
        TweenService:Create(card, outT, {BackgroundTransparency = 1}):Play()
        TweenService:Create(stroke, outT, {Transparency = 1}):Play()
        TweenService:Create(titleLabel, outT, {TextTransparency = 1}):Play()
        TweenService:Create(bodyLabel, outT, {TextTransparency = 1}):Play()
        task.wait(0.3)
        card:Destroy()
    end)
end

return Notify
