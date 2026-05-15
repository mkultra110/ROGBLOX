--[[
    Toast notifications — top-right stack with slide-in from right
    (Back-easing overshoot) and slide-out on dismiss. Each notification
    has an accent strip, drop shadow, and gradient background.
]]

local TweenService = game:GetService("TweenService")
local CoreGui      = game:GetService("CoreGui")

local Notify = {}

local container

local THEME = {
    Bg     = Color3.fromRGB(20, 18, 28),
    Bg2    = Color3.fromRGB(28, 26, 40),
    Accent = Color3.fromRGB(140, 100, 255),
    Text   = Color3.fromRGB(232, 232, 244),
    Sub    = Color3.fromRGB(160, 162, 178),
    Stroke = Color3.fromRGB(60, 56, 84),
}

local function ensureContainer()
    if container and container.Parent then return container end
    local gui = Instance.new("ScreenGui")
    gui.Name = "ROGBLOX_Notify"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 500
    if syn and syn.protect_gui then syn.protect_gui(gui) end
    gui.Parent = (gethui and gethui()) or CoreGui

    local list = Instance.new("Frame")
    list.Name = "List"
    list.AnchorPoint = Vector2.new(1, 0)
    list.Position = UDim2.new(1, -16, 0, 16)
    list.Size = UDim2.new(0, 300, 1, -32)
    list.BackgroundTransparency = 1
    list.Parent = gui

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
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
    card.AnchorPoint = Vector2.new(1, 0)
    card.BackgroundColor3 = THEME.Bg
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundTransparency = 1
    card.Position = UDim2.new(1, 60, 0, 0)   -- start off-screen right
    card.ClipsDescendants = true
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 7)

    -- subtle gradient background
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.Bg2),
        ColorSequenceKeypoint.new(1, THEME.Bg),
    })
    grad.Rotation = 110
    grad.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Accent
    stroke.Thickness = 1
    stroke.Transparency = 1
    stroke.Parent = card

    -- accent strip on the left
    local strip = Instance.new("Frame")
    strip.BackgroundColor3 = THEME.Accent
    strip.BorderSizePixel = 0
    strip.Position = UDim2.new(0, 0, 0, 6)
    strip.Size = UDim2.new(0, 3, 1, -12)
    strip.Parent = card
    Instance.new("UICorner", strip).CornerRadius = UDim.new(0, 2)

    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.PaddingLeft   = UDim.new(0, 14)
    pad.PaddingRight  = UDim.new(0, 12)
    pad.Parent = card

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Size = UDim2.new(1, 0, 0, 16)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.Text = title or ""
    titleLbl.TextColor3 = THEME.Text
    titleLbl.TextTransparency = 1
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = card

    local bodyLbl = Instance.new("TextLabel")
    bodyLbl.BackgroundTransparency = 1
    bodyLbl.Position = UDim2.new(0, 0, 0, 20)
    bodyLbl.Size = UDim2.new(1, 0, 0, 0)
    bodyLbl.AutomaticSize = Enum.AutomaticSize.Y
    bodyLbl.Font = Enum.Font.Gotham
    bodyLbl.Text = body or ""
    bodyLbl.TextWrapped = true
    bodyLbl.TextColor3 = THEME.Sub
    bodyLbl.TextTransparency = 1
    bodyLbl.TextSize = 11
    bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
    bodyLbl.Parent = card

    local inT  = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local outT = TweenInfo.new(0.30, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

    -- Slide in + fade in
    TweenService:Create(card, inT, {
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 0,
    }):Play()
    TweenService:Create(stroke, inT, {Transparency = 0}):Play()
    TweenService:Create(titleLbl, inT, {TextTransparency = 0}):Play()
    TweenService:Create(bodyLbl, inT, {TextTransparency = 0.05}):Play()

    task.delay(duration, function()
        if not card.Parent then return end
        TweenService:Create(card, outT, {
            Position = UDim2.new(1, 80, 0, 0),
            BackgroundTransparency = 1,
        }):Play()
        TweenService:Create(stroke, outT, {Transparency = 1}):Play()
        TweenService:Create(titleLbl, outT, {TextTransparency = 1}):Play()
        TweenService:Create(bodyLbl, outT, {TextTransparency = 1}):Play()
        task.wait(0.35)
        card:Destroy()
    end)
end

return Notify
