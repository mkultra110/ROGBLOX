--[[
    ROGBLOX UI library v2 — pro menu.
    Window  -> Tabs (left rail with icons) -> Sections -> Components.
    Components: Toggle, Slider (with input), Button, Dropdown (multi),
                Keybind, TextBox, Label, ColorPicker, Divider.
    Window features: drag, resize, minimize, fade animations, accent
    color customization, top-bar search filter, watermark/HUD overlay.
]]

local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local Players          = game:GetService("Players")

local UI = {}
UI.__index = UI

local THEME = {
    Background   = Color3.fromRGB(16,  16,  22),
    Panel        = Color3.fromRGB(22,  22,  30),
    Panel2       = Color3.fromRGB(28,  28,  38),
    Element      = Color3.fromRGB(36,  36,  48),
    ElementHover = Color3.fromRGB(48,  48,  62),
    Accent       = Color3.fromRGB(140, 100, 255),
    AccentDim    = Color3.fromRGB( 90,  60, 180),
    AccentSoft   = Color3.fromRGB(180, 150, 255),
    Text         = Color3.fromRGB(235, 235, 245),
    SubText      = Color3.fromRGB(150, 150, 165),
    DimText      = Color3.fromRGB(110, 110, 125),
    Stroke       = Color3.fromRGB(50,   50,  62),
    Good         = Color3.fromRGB( 90, 220, 140),
    Warn         = Color3.fromRGB(255, 200,  80),
    Bad          = Color3.fromRGB(235,  90, 100),
}
UI.Theme = THEME

local TI_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Sine)
local TI_SLOW = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    return inst
end

local function corner(r, parent)
    return new("UICorner", {CornerRadius = UDim.new(0, r), Parent = parent})
end

local function stroke(color, t, parent)
    return new("UIStroke", {
        Color = color or THEME.Stroke,
        Thickness = t or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(p, parent)
    return new("UIPadding", {
        PaddingTop = UDim.new(0, p),
        PaddingBottom = UDim.new(0, p),
        PaddingLeft = UDim.new(0, p),
        PaddingRight = UDim.new(0, p),
        Parent = parent,
    })
end

local function gradient(parent, c1, c2, rotation)
    return new("UIGradient", {
        Color = ColorSequence.new(c1, c2),
        Rotation = rotation or 90,
        Parent = parent,
    })
end

local function getParentGui(name)
    name = name or "ROGBLOX"
    if syn and syn.protect_gui then
        local g = new("ScreenGui", {Name = name, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
        syn.protect_gui(g); g.Parent = CoreGui; return g
    elseif gethui then
        local g = new("ScreenGui", {Name = name, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
        g.Parent = gethui(); return g
    else
        return new("ScreenGui", {Name = name, ResetOnSpawn = false, Parent = CoreGui,
                                 ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
    end
end

UI.GetParentGui = getParentGui

local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                       or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                       startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local function makeResizable(frame, handle, minSize)
    minSize = minSize or Vector2.new(520, 320)
    local sizing, startInput, startSize
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            sizing = true
            startInput = input.Position
            startSize = frame.AbsoluteSize
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then sizing = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sizing and (input.UserInputType == Enum.UserInputType.MouseMovement
                     or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startInput
            local w = math.max(minSize.X, startSize.X + d.X)
            local h = math.max(minSize.Y, startSize.Y + d.Y)
            frame.Size = UDim2.new(0, w, 0, h)
        end
    end)
end

-- ============================================================
-- Window
-- ============================================================

function UI:CreateWindow(opts)
    opts = opts or {}
    local size = opts.Size or Vector2.new(640, 420)
    local container = getParentGui("ROGBLOX")

    local root = new("Frame", {
        Name = "Window",
        Parent = container,
        BackgroundColor3 = THEME.Background,
        Position = UDim2.new(0.5, -size.X/2, 0.5, -size.Y/2),
        Size = UDim2.new(0, size.X, 0, size.Y),
        ClipsDescendants = true,
    })
    corner(10, root)
    stroke(THEME.Stroke, 1, root)

    -- Title bar
    local titleBar = new("Frame", {
        Parent = root,
        BackgroundColor3 = THEME.Panel,
        Size = UDim2.new(1, 0, 0, 40),
        BorderSizePixel = 0,
    })
    new("Frame", { -- bottom-fill so the corner radius doesn't cut content below
        Parent = titleBar,
        BackgroundColor3 = THEME.Panel,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -10), Size = UDim2.new(1, 0, 0, 10),
    })
    corner(10, titleBar)

    -- accent strip on the title
    local accentStrip = new("Frame", {
        Parent = titleBar,
        BackgroundColor3 = THEME.Accent,
        Size = UDim2.new(0, 4, 1, -8),
        Position = UDim2.new(0, 6, 0, 4),
        BorderSizePixel = 0,
    })
    corner(2, accentStrip)

    local titleLabel = new("TextLabel", {
        Parent = titleBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 18, 0, 0),
        Size = UDim2.new(0, 120, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = opts.Title or "ROGBLOX",
        TextColor3 = THEME.Text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local subLabel = new("TextLabel", {
        Parent = titleBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 18 + 90, 0, 0),
        Size = UDim2.new(0, 200, 1, 0),
        Font = Enum.Font.Gotham,
        Text = opts.SubTitle or "",
        TextColor3 = THEME.SubText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    -- Search box (filters component labels live)
    local searchHolder = new("Frame", {
        Parent = titleBar,
        BackgroundColor3 = THEME.Element,
        Position = UDim2.new(1, -310, 0.5, -12),
        Size = UDim2.new(0, 220, 0, 24),
        BorderSizePixel = 0,
    })
    corner(6, searchHolder)
    local search = new("TextBox", {
        Parent = searchHolder,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -20, 1, 0),
        Font = Enum.Font.Gotham,
        PlaceholderText = "Search...",
        Text = "",
        TextColor3 = THEME.Text,
        PlaceholderColor3 = THEME.DimText,
        TextSize = 12,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    -- Min / Close buttons
    local function makeIconBtn(x, color, glyph)
        local b = new("TextButton", {
            Parent = titleBar,
            BackgroundColor3 = color,
            Position = UDim2.new(1, x, 0.5, -10),
            Size = UDim2.new(0, 22, 0, 22),
            AutoButtonColor = false,
            Font = Enum.Font.GothamBold,
            Text = glyph, TextColor3 = THEME.Text, TextSize = 12,
            BorderSizePixel = 0,
        })
        corner(5, b)
        return b
    end
    local minBtn   = makeIconBtn(-58, THEME.Element, "_")
    local closeBtn = makeIconBtn(-30, THEME.Bad,     "x")

    -- Tab rail (left)
    local rail = new("Frame", {
        Parent = root,
        BackgroundColor3 = THEME.Panel,
        Position = UDim2.new(0, 0, 0, 40),
        Size = UDim2.new(0, 140, 1, -40),
        BorderSizePixel = 0,
    })
    new("UIListLayout", {Parent = rail, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)})
    padding(8, rail)

    -- Content area
    local content = new("Frame", {
        Parent = root,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 140, 0, 40),
        Size = UDim2.new(1, -140, 1, -40),
        ClipsDescendants = true,
    })

    -- Resize handle (corner)
    local grip = new("TextButton", {
        Parent = root,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Position = UDim2.new(1, -14, 1, -14),
        Size = UDim2.new(0, 14, 0, 14),
        Text = "",
    })
    local gripDot = new("Frame", {
        Parent = grip,
        BackgroundColor3 = THEME.Stroke,
        Position = UDim2.new(1, -4, 1, -4),
        Size = UDim2.new(0, 3, 0, 3),
        BorderSizePixel = 0,
    })
    corner(2, gripDot)

    makeDraggable(root, titleBar)
    makeResizable(root, grip)

    local window = setmetatable({
        _gui = container,
        _root = root,
        _rail = rail,
        _content = content,
        _tabs = {},
        _active = nil,
        _visible = true,
        _minimized = false,
        _toggle = opts.Toggle or Enum.KeyCode.RightControl,
        _accentStrip = accentStrip,
        _searchBox = search,
        _components = {},
        _theme = THEME,
    }, UI)

    minBtn.MouseButton1Click:Connect(function() window:ToggleMinimize() end)
    closeBtn.MouseButton1Click:Connect(function() window:Toggle() end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == window._toggle then window:Toggle() end
    end)

    -- Search filter wiring — hides components whose label doesn't match.
    search:GetPropertyChangedSignal("Text"):Connect(function()
        local q = search.Text:lower()
        for _, c in ipairs(window._components) do
            if c.Frame and c.Label then
                local match = q == "" or c.Label:lower():find(q, 1, true)
                c.Frame.Visible = match and true or false
            end
        end
    end)

    return window
end

function UI:Toggle()
    self._visible = not self._visible
    self._root.Visible = self._visible
end

function UI:ToggleMinimize()
    self._minimized = not self._minimized
    self._content.Visible = not self._minimized
    self._rail.Visible = not self._minimized
    local current = self._root.Size
    if self._minimized then
        self._savedSize = current
        TweenService:Create(self._root, TI_FAST, {Size = UDim2.new(0, current.X.Offset, 0, 40)}):Play()
    else
        TweenService:Create(self._root, TI_FAST, {Size = self._savedSize or UDim2.new(0, 640, 0, 420)}):Play()
    end
end

function UI:Destroy()
    if self._gui then self._gui:Destroy() end
end

function UI:SetAccent(color)
    THEME.Accent = color
    self._accentStrip.BackgroundColor3 = color
end

-- ============================================================
-- Tab
-- ============================================================

local Tab = {}
Tab.__index = Tab

function UI:AddTab(name, icon)
    local btn = new("TextButton", {
        Parent = self._rail,
        BackgroundColor3 = THEME.Element,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 32),
        Font = Enum.Font.GothamMedium,
        Text = "  " .. name,
        TextColor3 = THEME.SubText,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0,
    })
    corner(6, btn)
    local indicator = new("Frame", {
        Parent = btn,
        BackgroundColor3 = THEME.Accent,
        Size = UDim2.new(0, 3, 0.6, 0),
        Position = UDim2.new(0, 2, 0.2, 0),
        BorderSizePixel = 0,
        Visible = false,
    })
    corner(2, indicator)

    local page = new("ScrollingFrame", {
        Parent = self._content,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        BorderSizePixel = 0,
    })
    new("UIListLayout", {Parent = page, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)})
    padding(12, page)

    local tab = setmetatable({
        _window = self,
        _btn = btn,
        _indicator = indicator,
        _page = page,
        _name = name,
    }, Tab)

    btn.MouseEnter:Connect(function()
        if self._active ~= tab then
            TweenService:Create(btn, TI_FAST, {BackgroundColor3 = THEME.ElementHover}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if self._active ~= tab then
            TweenService:Create(btn, TI_FAST, {BackgroundColor3 = THEME.Element}):Play()
        end
    end)
    btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)

    table.insert(self._tabs, tab)
    if #self._tabs == 1 then self:SelectTab(tab) end
    return tab
end

function UI:SelectTab(tab)
    for _, t in ipairs(self._tabs) do
        local active = (t == tab)
        t._page.Visible = active
        t._indicator.Visible = active
        TweenService:Create(t._btn, TI_FAST, {
            BackgroundColor3 = active and THEME.AccentDim or THEME.Element,
            TextColor3 = active and THEME.Text or THEME.SubText,
        }):Play()
    end
    self._active = tab
end

-- ============================================================
-- Section
-- ============================================================

local Section = {}
Section.__index = Section

function Tab:AddSection(name)
    local outer = new("Frame", {
        Parent = self._page,
        BackgroundColor3 = THEME.Panel,
        Size = UDim2.new(1, -4, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
    })
    corner(8, outer)
    stroke(THEME.Stroke, 1, outer)

    local header = new("Frame", {
        Parent = outer,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 26),
    })
    local headerBtn = new("TextButton", {
        Parent = header,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = "  " .. name,
        TextColor3 = THEME.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local body = new("Frame", {
        Parent = outer,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0, 0, 0, 26),
    })
    new("UIListLayout", {Parent = body, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)})
    new("UIPadding", {Parent = body,
        PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
    })

    local collapsed = false
    headerBtn.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        body.Visible = not collapsed
        headerBtn.Text = (collapsed and "  > " or "  ") .. name
    end)

    return setmetatable({
        _frame = body,
        _outer = outer,
        _window = self._window,
        _name = name,
    }, Section)
end

local function rowFrame(parent, height)
    local row = new("Frame", {
        Parent = parent,
        BackgroundColor3 = THEME.Element,
        Size = UDim2.new(1, 0, 0, height or 30),
        BorderSizePixel = 0,
    })
    corner(5, row)
    return row
end

local function trackComponent(section, label, frame)
    table.insert(section._window._components, {Frame = frame, Label = label})
end

-- ---------- Label ----------

function Section:AddLabel(text)
    local lbl = new("TextLabel", {
        Parent = self._frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Font = Enum.Font.Gotham,
        Text = text,
        TextColor3 = THEME.SubText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    return {Set = function(_, t) lbl.Text = t end, Frame = lbl}
end

function Section:AddDivider()
    local d = new("Frame", {
        Parent = self._frame,
        BackgroundColor3 = THEME.Stroke,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
    })
    return {Frame = d}
end

-- ---------- Button ----------

function Section:AddButton(text, callback)
    local row = rowFrame(self._frame, 32)
    local btn = new("TextButton", {
        Parent = row,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextColor3 = THEME.Text,
        TextSize = 12,
    })
    btn.MouseEnter:Connect(function() TweenService:Create(row, TI_FAST, {BackgroundColor3 = THEME.ElementHover}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(row, TI_FAST, {BackgroundColor3 = THEME.Element}):Play() end)
    btn.MouseButton1Click:Connect(function()
        if callback then task.spawn(callback) end
    end)
    trackComponent(self, text, row)
    return {Frame = row, SetText = function(_, t) btn.Text = t end}
end

-- ---------- Toggle ----------

function Section:AddToggle(text, default, callback)
    local row = rowFrame(self._frame, 30)
    local state = default and true or false

    new("TextLabel", {
        Parent = row, BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -50, 1, 0),
        Font = Enum.Font.GothamMedium, Text = text, TextColor3 = THEME.Text,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    })

    local sw = new("Frame", {
        Parent = row, BackgroundColor3 = state and THEME.Accent or THEME.Stroke,
        Position = UDim2.new(1, -36, 0.5, -8),
        Size = UDim2.new(0, 28, 0, 16), BorderSizePixel = 0,
    })
    corner(8, sw)
    local knob = new("Frame", {
        Parent = sw, BackgroundColor3 = THEME.Text,
        Position = UDim2.new(state and 1 or 0, state and -14 or 2, 0.5, -6),
        Size = UDim2.new(0, 12, 0, 12), BorderSizePixel = 0,
    })
    corner(6, knob)

    local function set(v, fire)
        state = v and true or false
        TweenService:Create(sw, TI_FAST, {BackgroundColor3 = state and THEME.Accent or THEME.Stroke}):Play()
        TweenService:Create(knob, TI_FAST, {Position = UDim2.new(state and 1 or 0, state and -14 or 2, 0.5, -6)}):Play()
        if fire and callback then task.spawn(callback, state) end
    end

    local clickArea = new("TextButton", {Parent = row, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = ""})
    clickArea.MouseButton1Click:Connect(function() set(not state, true) end)
    if state and callback then task.spawn(callback, true) end

    trackComponent(self, text, row)
    return {Set = function(_, v) set(v, true) end, Get = function() return state end, Frame = row}
end

-- ---------- Slider ----------

function Section:AddSlider(text, min, max, default, callback, opts)
    opts = opts or {}
    local decimals = opts.Decimals or 0
    local row = rowFrame(self._frame, 50)
    local value = default or min

    local label = new("TextLabel", {
        Parent = row, BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 4),
        Size = UDim2.new(1, -70, 0, 16),
        Font = Enum.Font.GothamMedium, Text = text, TextColor3 = THEME.Text,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    })

    local inputBox = new("TextBox", {
        Parent = row, BackgroundColor3 = THEME.Panel2,
        Position = UDim2.new(1, -54, 0, 4),
        Size = UDim2.new(0, 44, 0, 16),
        Font = Enum.Font.GothamMedium,
        Text = tostring(value),
        TextColor3 = THEME.Text, TextSize = 11, BorderSizePixel = 0,
        ClearTextOnFocus = false,
    })
    corner(4, inputBox)

    local bar = new("Frame", {
        Parent = row, BackgroundColor3 = THEME.Stroke,
        Position = UDim2.new(0, 12, 1, -16),
        Size = UDim2.new(1, -24, 0, 6),
        BorderSizePixel = 0,
    })
    corner(3, bar)
    local fill = new("Frame", {
        Parent = bar, BackgroundColor3 = THEME.Accent,
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
        BorderSizePixel = 0,
    })
    corner(3, fill)

    local function format(v)
        if decimals > 0 then
            local m = 10 ^ decimals
            return tostring(math.floor(v * m + 0.5) / m)
        end
        return tostring(math.floor(v + 0.5))
    end

    local function set(v, fire)
        v = math.clamp(v, min, max)
        if decimals > 0 then
            local m = 10 ^ decimals
            value = math.floor(v * m + 0.5) / m
        else
            value = math.floor(v + 0.5)
        end
        fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
        label.Text = text
        inputBox.Text = format(value)
        if fire and callback then task.spawn(callback, value) end
    end

    inputBox.FocusLost:Connect(function(enter)
        local n = tonumber(inputBox.Text)
        if n then set(n, true) else inputBox.Text = format(value) end
    end)

    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                       or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
            set(min + rel * (max - min), true)
        end
    end)

    if callback then task.spawn(callback, value) end
    trackComponent(self, text, row)
    return {
        Set = function(_, v) set(v, true) end,
        Get = function() return value end,
        Frame = row,
    }
end

-- ---------- Dropdown ----------

function Section:AddDropdown(text, options, default, callback, opts)
    opts = opts or {}
    local multi = opts.Multi
    local row = rowFrame(self._frame, 30)

    new("TextLabel", {
        Parent = row, BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(0.45, 0, 1, 0),
        Font = Enum.Font.GothamMedium, Text = text, TextColor3 = THEME.Text,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    })

    local valueBtn = new("TextButton", {
        Parent = row, BackgroundColor3 = THEME.Panel2,
        Position = UDim2.new(0.45, 0, 0.5, -10),
        Size = UDim2.new(0.55, -12, 0, 20),
        AutoButtonColor = false,
        Font = Enum.Font.Gotham, Text = "",
        TextColor3 = THEME.Text, TextSize = 11, BorderSizePixel = 0,
    })
    corner(4, valueBtn)

    local current
    if multi then
        current = {}
        if type(default) == "table" then
            for _, v in ipairs(default) do current[v] = true end
        end
    else
        current = default or options[1]
    end

    local function refreshLabel()
        if multi then
            local list = {}
            for k, v in pairs(current) do if v then table.insert(list, tostring(k)) end end
            valueBtn.Text = #list > 0 and table.concat(list, ", ") or "(none)"
        else
            valueBtn.Text = tostring(current) .. "  v"
        end
    end

    local menu = new("Frame", {
        Parent = row, BackgroundColor3 = THEME.Panel,
        Position = UDim2.new(0.45, 0, 1, 4),
        Size = UDim2.new(0.55, -12, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false, ZIndex = 20, BorderSizePixel = 0,
    })
    corner(5, menu)
    stroke(THEME.Stroke, 1, menu)
    new("UIListLayout", {Parent = menu, SortOrder = Enum.SortOrder.LayoutOrder})

    local function rebuildItems(newOptions)
        for _, child in ipairs(menu:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for _, opt in ipairs(newOptions) do
            local item = new("TextButton", {
                Parent = menu, BackgroundColor3 = THEME.Panel,
                Size = UDim2.new(1, 0, 0, 22),
                AutoButtonColor = false,
                Font = Enum.Font.Gotham, Text = "  " .. tostring(opt),
                TextColor3 = THEME.SubText, TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 21, BorderSizePixel = 0,
            })
            item.MouseEnter:Connect(function() item.BackgroundColor3 = THEME.ElementHover end)
            item.MouseLeave:Connect(function() item.BackgroundColor3 = THEME.Panel end)
            item.MouseButton1Click:Connect(function()
                if multi then
                    current[opt] = not current[opt]
                    item.TextColor3 = current[opt] and THEME.AccentSoft or THEME.SubText
                    refreshLabel()
                    if callback then task.spawn(callback, current) end
                else
                    current = opt
                    refreshLabel()
                    menu.Visible = false
                    if callback then task.spawn(callback, current) end
                end
            end)
            if multi and current[opt] then item.TextColor3 = THEME.AccentSoft end
        end
    end

    rebuildItems(options)
    refreshLabel()

    valueBtn.MouseButton1Click:Connect(function() menu.Visible = not menu.Visible end)

    if callback and not multi then task.spawn(callback, current) end
    trackComponent(self, text, row)
    return {
        Set = function(_, v) current = v; refreshLabel(); if callback then task.spawn(callback, current) end end,
        Get = function() return current end,
        SetOptions = function(_, newOpts) rebuildItems(newOpts) end,
        Frame = row,
    }
end

-- ---------- Keybind ----------

function Section:AddKeybind(text, default, callback, opts)
    opts = opts or {}
    local row = rowFrame(self._frame, 30)
    local key = default
    local listening = false

    new("TextLabel", {
        Parent = row, BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -100, 1, 0),
        Font = Enum.Font.GothamMedium, Text = text, TextColor3 = THEME.Text,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    })

    local btn = new("TextButton", {
        Parent = row, BackgroundColor3 = THEME.Panel2,
        Position = UDim2.new(1, -88, 0.5, -10),
        Size = UDim2.new(0, 78, 0, 20),
        AutoButtonColor = false,
        Font = Enum.Font.Gotham, Text = key and key.Name or "...",
        TextColor3 = THEME.Text, TextSize = 11, BorderSizePixel = 0,
    })
    corner(4, btn)

    btn.MouseButton1Click:Connect(function()
        listening = true; btn.Text = "[press]"
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Backspace then
                    key = nil
                else
                    key = input.KeyCode
                end
                btn.Text = key and key.Name or "..."
                listening = false
            end
            return
        end
        if processed then return end
        if key and input.KeyCode == key and callback then
            task.spawn(callback)
        end
    end)

    trackComponent(self, text, row)
    return {
        Get = function() return key end,
        Set = function(_, k) key = k; btn.Text = k and k.Name or "..." end,
        Frame = row,
    }
end

-- ---------- TextBox ----------

function Section:AddTextBox(text, placeholder, callback)
    local row = rowFrame(self._frame, 30)
    new("TextLabel", {
        Parent = row, BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(0.4, 0, 1, 0),
        Font = Enum.Font.GothamMedium, Text = text, TextColor3 = THEME.Text,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local box = new("TextBox", {
        Parent = row, BackgroundColor3 = THEME.Panel2,
        Position = UDim2.new(0.4, 0, 0.5, -10),
        Size = UDim2.new(0.6, -12, 0, 20),
        Font = Enum.Font.Gotham, PlaceholderText = placeholder or "",
        Text = "", TextColor3 = THEME.Text, PlaceholderColor3 = THEME.DimText,
        TextSize = 11, ClearTextOnFocus = false, BorderSizePixel = 0,
    })
    corner(4, box)
    box.FocusLost:Connect(function(enter)
        if callback then task.spawn(callback, box.Text, enter) end
    end)
    trackComponent(self, text, row)
    return {Get = function() return box.Text end, Set = function(_, v) box.Text = v end, Frame = row}
end

-- ---------- Color Picker ----------

function Section:AddColorPicker(text, default, callback)
    local row = rowFrame(self._frame, 30)
    local current = default or Color3.fromRGB(255, 255, 255)

    new("TextLabel", {
        Parent = row, BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -60, 1, 0),
        Font = Enum.Font.GothamMedium, Text = text, TextColor3 = THEME.Text,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
    })

    local swatch = new("TextButton", {
        Parent = row, BackgroundColor3 = current,
        Position = UDim2.new(1, -44, 0.5, -10),
        Size = UDim2.new(0, 34, 0, 20),
        AutoButtonColor = false, Text = "", BorderSizePixel = 0,
    })
    corner(4, swatch)
    stroke(THEME.Stroke, 1, swatch)

    -- Tiny popup with H/S/V sliders. Compact and good enough.
    local popup = new("Frame", {
        Parent = row, BackgroundColor3 = THEME.Panel,
        Position = UDim2.new(1, -210, 1, 4),
        Size = UDim2.new(0, 200, 0, 100),
        Visible = false, ZIndex = 30, BorderSizePixel = 0,
    })
    corner(6, popup); stroke(THEME.Stroke, 1, popup)

    local function makeBar(y, label)
        new("TextLabel", {
            Parent = popup, BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, y),
            Size = UDim2.new(0, 30, 0, 16),
            Font = Enum.Font.GothamMedium, Text = label, TextColor3 = THEME.Text,
            TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31,
        })
        local bar = new("Frame", {
            Parent = popup, BackgroundColor3 = THEME.Stroke,
            Position = UDim2.new(0, 44, 0, y + 4),
            Size = UDim2.new(0, 130, 0, 8),
            ZIndex = 31, BorderSizePixel = 0,
        })
        corner(4, bar)
        local fill = new("Frame", {
            Parent = bar, BackgroundColor3 = THEME.Accent,
            Size = UDim2.new(0, 0, 1, 0),
            ZIndex = 32, BorderSizePixel = 0,
        })
        corner(4, fill)
        return bar, fill
    end

    local h, s, v = Color3.toHSV(current)
    local hBar, hFill = makeBar(8,  "H")
    local sBar, sFill = makeBar(34, "S")
    local vBar, vFill = makeBar(60, "V")

    local function refresh()
        current = Color3.fromHSV(h, s, v)
        swatch.BackgroundColor3 = current
        hFill.Size = UDim2.new(h, 0, 1, 0)
        sFill.Size = UDim2.new(s, 0, 1, 0)
        vFill.Size = UDim2.new(v, 0, 1, 0)
        if callback then task.spawn(callback, current) end
    end
    refresh()

    local function bind(bar, setter)
        local dragging
        bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
                setter(rel); refresh()
            end
        end)
    end
    bind(hBar, function(x) h = x end)
    bind(sBar, function(x) s = x end)
    bind(vBar, function(x) v = x end)

    swatch.MouseButton1Click:Connect(function() popup.Visible = not popup.Visible end)

    if callback then task.spawn(callback, current) end
    trackComponent(self, text, row)
    return {
        Set = function(_, c) current = c; h, s, v = Color3.toHSV(c); refresh() end,
        Get = function() return current end,
        Frame = row,
    }
end

return UI
