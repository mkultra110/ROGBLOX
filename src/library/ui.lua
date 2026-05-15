--[[
    ROGBLOX UI library
    Window → Tab → Section → Components (Toggle, Slider, Button,
    Dropdown, Keybind, TextBox, Label, ColorPicker).
    Draggable window, dark theme, simple and chunky.
]]

local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")

local UI = {}
UI.__index = UI

local THEME = {
    Background  = Color3.fromRGB(20,  20,  24),
    Panel       = Color3.fromRGB(28,  28,  32),
    Element     = Color3.fromRGB(38,  38,  44),
    ElementHover= Color3.fromRGB(48,  48,  56),
    Accent      = Color3.fromRGB(120, 90,  220),
    AccentDim   = Color3.fromRGB( 80, 60,  150),
    Text        = Color3.fromRGB(230, 230, 235),
    SubText     = Color3.fromRGB(150, 150, 160),
    Stroke      = Color3.fromRGB(50,  50,  58),
    Good        = Color3.fromRGB( 90, 200, 120),
    Bad         = Color3.fromRGB(220,  80,  90),
}

local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    for _, child in ipairs(children or {}) do child.Parent = inst end
    return inst
end

local function corner(radius, parent)
    return new("UICorner", {CornerRadius = UDim.new(0, radius), Parent = parent})
end

local function stroke(color, thickness, parent)
    return new("UIStroke", {
        Color = color or THEME.Stroke,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(p, parent)
    return new("UIPadding", {
        PaddingTop    = UDim.new(0, p),
        PaddingBottom = UDim.new(0, p),
        PaddingLeft   = UDim.new(0, p),
        PaddingRight  = UDim.new(0, p),
        Parent = parent,
    })
end

local function getParentGui()
    if syn and syn.protect_gui then
        local container = new("ScreenGui", {Name = "ROGBLOX"})
        syn.protect_gui(container)
        container.Parent = CoreGui
        return container
    elseif gethui then
        local container = new("ScreenGui", {Name = "ROGBLOX"})
        container.Parent = gethui()
        return container
    else
        local container = new("ScreenGui", {Name = "ROGBLOX", ResetOnSpawn = false})
        container.Parent = CoreGui
        return container
    end
end

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
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                      or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

function UI:CreateWindow(opts)
    opts = opts or {}
    local size = opts.Size or Vector2.new(560, 360)

    local container = getParentGui()

    local root = new("Frame", {
        Name = "Window",
        Parent = container,
        BackgroundColor3 = THEME.Background,
        Position = UDim2.new(0.5, -size.X/2, 0.5, -size.Y/2),
        Size = UDim2.new(0, size.X, 0, size.Y),
    })
    corner(8, root)
    stroke(THEME.Stroke, 1, root)

    local titleBar = new("Frame", {
        Parent = root,
        BackgroundColor3 = THEME.Panel,
        Size = UDim2.new(1, 0, 0, 36),
    })
    corner(8, titleBar)
    new("Frame", {
        Parent = titleBar,
        BackgroundColor3 = THEME.Panel,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -8),
        Size = UDim2.new(1, 0, 0, 8),
    })

    new("TextLabel", {
        Parent = titleBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(0, 200, 1, 0),
        Font = Enum.Font.GothamBold,
        Text = opts.Title or "ROGBLOX",
        TextColor3 = THEME.Text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    new("TextLabel", {
        Parent = titleBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14 + 80, 0, 0),
        Size = UDim2.new(0, 200, 1, 0),
        Font = Enum.Font.Gotham,
        Text = opts.SubTitle or "",
        TextColor3 = THEME.SubText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    -- close button
    local closeBtn = new("TextButton", {
        Parent = titleBar,
        BackgroundColor3 = THEME.Bad,
        Position = UDim2.new(1, -28, 0.5, -10),
        Size = UDim2.new(0, 20, 0, 20),
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
        Text = "x",
        TextColor3 = THEME.Text,
        TextSize = 12,
    })
    corner(4, closeBtn)

    makeDraggable(root, titleBar)

    -- left tab list
    local tabList = new("Frame", {
        Parent = root,
        BackgroundColor3 = THEME.Panel,
        Position = UDim2.new(0, 0, 0, 36),
        Size = UDim2.new(0, 120, 1, -36),
    })
    new("UIListLayout", {
        Parent = tabList,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
    })
    padding(8, tabList)

    -- content area
    local content = new("Frame", {
        Parent = root,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 120, 0, 36),
        Size = UDim2.new(1, -120, 1, -36),
    })

    local window = setmetatable({
        _gui      = container,
        _root     = root,
        _tabList  = tabList,
        _content  = content,
        _tabs     = {},
        _active   = nil,
        _toggle   = opts.Toggle or Enum.KeyCode.RightControl,
        _visible  = true,
    }, UI)

    closeBtn.MouseButton1Click:Connect(function()
        window:Toggle()
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == window._toggle then
            window:Toggle()
        end
    end)

    return window
end

function UI:Toggle()
    self._visible = not self._visible
    self._root.Visible = self._visible
end

function UI:Destroy()
    if self._gui then self._gui:Destroy() end
end

-- ---------- Tab ----------

local Tab = {}
Tab.__index = Tab

function UI:AddTab(name, icon)
    local btn = new("TextButton", {
        Parent = self._tabList,
        BackgroundColor3 = THEME.Element,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 32),
        Font = Enum.Font.GothamMedium,
        Text = "  " .. name,
        TextColor3 = THEME.SubText,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    corner(6, btn)

    local page = new("ScrollingFrame", {
        Parent = self._content,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    })
    new("UIListLayout", {
        Parent = page,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
    })
    padding(10, page)

    local tab = setmetatable({
        _window = self,
        _btn    = btn,
        _page   = page,
        _name   = name,
    }, Tab)

    btn.MouseButton1Click:Connect(function()
        self:SelectTab(tab)
    end)

    table.insert(self._tabs, tab)
    if #self._tabs == 1 then
        self:SelectTab(tab)
    end
    return tab
end

function UI:SelectTab(tab)
    for _, t in ipairs(self._tabs) do
        t._page.Visible = (t == tab)
        t._btn.BackgroundColor3 = (t == tab) and THEME.AccentDim or THEME.Element
        t._btn.TextColor3 = (t == tab) and THEME.Text or THEME.SubText
    end
    self._active = tab
end

-- ---------- Section ----------

local Section = {}
Section.__index = Section

function Tab:AddSection(name)
    local frame = new("Frame", {
        Parent = self._page,
        BackgroundColor3 = THEME.Panel,
        Size = UDim2.new(1, -4, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    corner(6, frame)
    stroke(THEME.Stroke, 1, frame)

    local layout = new("UIListLayout", {
        Parent = frame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    })
    padding(10, frame)

    new("TextLabel", {
        Parent = frame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Font = Enum.Font.GothamBold,
        Text = name,
        TextColor3 = THEME.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    return setmetatable({_frame = frame, _layout = layout}, Section)
end

local function rowFrame(parent, height)
    local row = new("Frame", {
        Parent = parent,
        BackgroundColor3 = THEME.Element,
        Size = UDim2.new(1, 0, 0, height or 28),
    })
    corner(4, row)
    return row
end

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
    return {
        Set = function(_, t) lbl.Text = t end,
    }
end

function Section:AddButton(text, callback)
    local row = rowFrame(self._frame, 30)
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
    btn.MouseEnter:Connect(function() row.BackgroundColor3 = THEME.ElementHover end)
    btn.MouseLeave:Connect(function() row.BackgroundColor3 = THEME.Element end)
    btn.MouseButton1Click:Connect(function()
        if callback then task.spawn(callback) end
    end)
end

function Section:AddToggle(text, default, callback)
    local row = rowFrame(self._frame, 30)
    local state = default and true or false

    new("TextLabel", {
        Parent = row,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -50, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextColor3 = THEME.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local sw = new("Frame", {
        Parent = row,
        BackgroundColor3 = state and THEME.Accent or THEME.Stroke,
        Position = UDim2.new(1, -36, 0.5, -8),
        Size = UDim2.new(0, 28, 0, 16),
    })
    corner(8, sw)
    local knob = new("Frame", {
        Parent = sw,
        BackgroundColor3 = THEME.Text,
        Position = UDim2.new(state and 1 or 0, state and -14 or 2, 0.5, -6),
        Size = UDim2.new(0, 12, 0, 12),
    })
    corner(6, knob)

    local function set(v, fire)
        state = v and true or false
        TweenService:Create(sw, TweenInfo.new(0.15), {
            BackgroundColor3 = state and THEME.Accent or THEME.Stroke,
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = UDim2.new(state and 1 or 0, state and -14 or 2, 0.5, -6),
        }):Play()
        if fire and callback then task.spawn(callback, state) end
    end

    local btn = new("TextButton", {
        Parent = row,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = "",
    })
    btn.MouseButton1Click:Connect(function() set(not state, true) end)

    if state and callback then task.spawn(callback, true) end

    return {
        Set = function(_, v) set(v, true) end,
        Get = function() return state end,
    }
end

function Section:AddSlider(text, min, max, default, callback)
    local row = rowFrame(self._frame, 44)
    local value = default or min

    local label = new("TextLabel", {
        Parent = row,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 4),
        Size = UDim2.new(1, -20, 0, 16),
        Font = Enum.Font.GothamMedium,
        Text = text .. ": " .. tostring(value),
        TextColor3 = THEME.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local bar = new("Frame", {
        Parent = row,
        BackgroundColor3 = THEME.Stroke,
        Position = UDim2.new(0, 10, 1, -14),
        Size = UDim2.new(1, -20, 0, 6),
    })
    corner(3, bar)
    local fill = new("Frame", {
        Parent = bar,
        BackgroundColor3 = THEME.Accent,
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
    })
    corner(3, fill)

    local dragging = false
    local function set(v, fire)
        v = math.clamp(v, min, max)
        if max - min < 5 then
            value = math.floor(v * 100 + 0.5) / 100
        else
            value = math.floor(v + 0.5)
        end
        fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
        label.Text = text .. ": " .. tostring(value)
        if fire and callback then task.spawn(callback, value) end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                      or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
            set(min + rel * (max - min), true)
        end
    end)

    if callback then task.spawn(callback, value) end

    return {
        Set = function(_, v) set(v, true) end,
        Get = function() return value end,
    }
end

function Section:AddDropdown(text, options, default, callback)
    local row = rowFrame(self._frame, 30)
    local current = default or options[1]
    local open = false

    new("TextLabel", {
        Parent = row,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(0.5, 0, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextColor3 = THEME.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local valueBtn = new("TextButton", {
        Parent = row,
        BackgroundColor3 = THEME.Stroke,
        Position = UDim2.new(0.5, 0, 0.5, -10),
        Size = UDim2.new(0.5, -10, 0, 20),
        AutoButtonColor = false,
        Font = Enum.Font.Gotham,
        Text = tostring(current) .. "  v",
        TextColor3 = THEME.Text,
        TextSize = 11,
    })
    corner(4, valueBtn)

    local menu = new("Frame", {
        Parent = row,
        BackgroundColor3 = THEME.Panel,
        Position = UDim2.new(0.5, 0, 1, 4),
        Size = UDim2.new(0.5, -10, 0, 0),
        Visible = false,
        ZIndex = 5,
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    corner(4, menu)
    stroke(THEME.Stroke, 1, menu)
    new("UIListLayout", {
        Parent = menu,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    for _, opt in ipairs(options) do
        local item = new("TextButton", {
            Parent = menu,
            BackgroundColor3 = THEME.Panel,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 22),
            AutoButtonColor = false,
            Font = Enum.Font.Gotham,
            Text = tostring(opt),
            TextColor3 = THEME.SubText,
            TextSize = 11,
            ZIndex = 6,
        })
        item.MouseEnter:Connect(function() item.BackgroundColor3 = THEME.ElementHover end)
        item.MouseLeave:Connect(function() item.BackgroundColor3 = THEME.Panel end)
        item.MouseButton1Click:Connect(function()
            current = opt
            valueBtn.Text = tostring(current) .. "  v"
            menu.Visible = false
            open = false
            if callback then task.spawn(callback, current) end
        end)
    end

    valueBtn.MouseButton1Click:Connect(function()
        open = not open
        menu.Visible = open
    end)

    if callback then task.spawn(callback, current) end

    return {
        Set = function(_, v)
            current = v
            valueBtn.Text = tostring(current) .. "  v"
            if callback then task.spawn(callback, current) end
        end,
        Get = function() return current end,
    }
end

function Section:AddKeybind(text, default, callback)
    local row = rowFrame(self._frame, 30)
    local key = default
    local listening = false

    new("TextLabel", {
        Parent = row,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -90, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextColor3 = THEME.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local btn = new("TextButton", {
        Parent = row,
        BackgroundColor3 = THEME.Stroke,
        Position = UDim2.new(1, -80, 0.5, -10),
        Size = UDim2.new(0, 70, 0, 20),
        AutoButtonColor = false,
        Font = Enum.Font.Gotham,
        Text = key and key.Name or "...",
        TextColor3 = THEME.Text,
        TextSize = 11,
    })
    corner(4, btn)

    btn.MouseButton1Click:Connect(function()
        listening = true
        btn.Text = "..."
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if listening and input.UserInputType == Enum.UserInputType.Keyboard then
            key = input.KeyCode
            btn.Text = key.Name
            listening = false
        elseif not processed and key and input.KeyCode == key then
            if callback then task.spawn(callback) end
        end
    end)

    return {
        Get = function() return key end,
        Set = function(_, k) key = k; btn.Text = k and k.Name or "..." end,
    }
end

function Section:AddTextBox(text, placeholder, callback)
    local row = rowFrame(self._frame, 30)

    new("TextLabel", {
        Parent = row,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(0.4, 0, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextColor3 = THEME.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local box = new("TextBox", {
        Parent = row,
        BackgroundColor3 = THEME.Stroke,
        Position = UDim2.new(0.4, 0, 0.5, -10),
        Size = UDim2.new(0.6, -10, 0, 20),
        Font = Enum.Font.Gotham,
        PlaceholderText = placeholder or "",
        Text = "",
        TextColor3 = THEME.Text,
        PlaceholderColor3 = THEME.SubText,
        TextSize = 11,
        ClearTextOnFocus = false,
    })
    corner(4, box)

    box.FocusLost:Connect(function(enter)
        if enter and callback then task.spawn(callback, box.Text) end
    end)

    return {
        Get = function() return box.Text end,
        Set = function(_, v) box.Text = v end,
    }
end

UI.Theme = THEME
return UI
