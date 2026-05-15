--[[
    Startup splash — big centered "ROGBLOX loaded" card that pulses in
    when the hub finishes booting, then fades out after a few seconds.
    Drop-in: Splash.Show("Title", "Body", duration_seconds).
]]

local TweenService = game:GetService("TweenService")
local CoreGui      = game:GetService("CoreGui")

local M = {}

local function makeGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ROGBLOX_Splash"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000
    if syn and syn.protect_gui then syn.protect_gui(gui) end
    gui.Parent = (gethui and gethui()) or CoreGui
    return gui
end

function M.Show(title, body, duration)
    duration = duration or 2.4

    local gui = makeGui()

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.Size = UDim2.new(0, 340, 0, 110)
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    card.BackgroundTransparency = 1
    card.BorderSizePixel = 0
    card.Parent = gui
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(140, 100, 255)
    s.Thickness = 1.5
    s.Transparency = 1
    s.Parent = card

    -- gradient bg
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,  Color3.fromRGB(28, 26, 44)),
        ColorSequenceKeypoint.new(1,  Color3.fromRGB(18, 16, 30)),
    })
    grad.Rotation = 120
    grad.Parent = card

    -- accent strip
    local strip = Instance.new("Frame")
    strip.BackgroundColor3 = Color3.fromRGB(140, 100, 255)
    strip.Position = UDim2.new(0, 12, 0.5, -22)
    strip.Size = UDim2.new(0, 4, 0, 0)
    strip.BorderSizePixel = 0
    strip.Parent = card
    Instance.new("UICorner", strip).CornerRadius = UDim.new(0, 2)

    -- title (gradient text effect via UIGradient on a TextLabel)
    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.new(0, 28, 0, 18)
    titleLbl.Size = UDim2.new(1, -44, 0, 30)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.Text = title or "ROGBLOX"
    titleLbl.TextColor3 = Color3.fromRGB(245, 240, 255)
    titleLbl.TextSize = 22
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextTransparency = 1
    titleLbl.Parent = card

    local tg = Instance.new("UIGradient")
    tg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromRGB(210, 175, 255)),
        ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(140, 100, 255)),
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(255, 130, 200)),
    })
    tg.Parent = titleLbl

    local bodyLbl = Instance.new("TextLabel")
    bodyLbl.BackgroundTransparency = 1
    bodyLbl.Position = UDim2.new(0, 28, 0, 52)
    bodyLbl.Size = UDim2.new(1, -44, 0, 44)
    bodyLbl.Font = Enum.Font.Gotham
    bodyLbl.Text = body or ""
    bodyLbl.TextColor3 = Color3.fromRGB(170, 175, 195)
    bodyLbl.TextSize = 12
    bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
    bodyLbl.TextYAlignment = Enum.TextYAlignment.Top
    bodyLbl.TextWrapped = true
    bodyLbl.TextTransparency = 1
    bodyLbl.Parent = card

    -- starting pose: slightly smaller + invisible, then ease into place
    card.Size = UDim2.new(0, 300, 0, 96)

    local easeIn  = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local easeOut = TweenInfo.new(0.30, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

    TweenService:Create(card, easeIn, {
        BackgroundTransparency = 0.05,
        Size = UDim2.new(0, 340, 0, 110),
    }):Play()
    TweenService:Create(s,        easeIn, {Transparency = 0}):Play()
    TweenService:Create(titleLbl, easeIn, {TextTransparency = 0}):Play()
    TweenService:Create(bodyLbl,  easeIn, {TextTransparency = 0.05}):Play()
    TweenService:Create(strip,    easeIn, {Size = UDim2.new(0, 4, 0, 44)}):Play()

    task.delay(duration, function()
        TweenService:Create(card,     easeOut, {BackgroundTransparency = 1}):Play()
        TweenService:Create(s,        easeOut, {Transparency = 1}):Play()
        TweenService:Create(titleLbl, easeOut, {TextTransparency = 1}):Play()
        TweenService:Create(bodyLbl,  easeOut, {TextTransparency = 1}):Play()
        TweenService:Create(strip,    easeOut, {Size = UDim2.new(0, 4, 0, 0)}):Play()
        task.wait(0.4)
        gui:Destroy()
    end)
end

return M
