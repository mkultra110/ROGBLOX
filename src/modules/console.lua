--[[
    In-game console — multi-line Lua editor + output panel.
    Lets you paste/edit scripts and run them inside the executor's
    sandbox without leaving Roblox. Useful for one-off tests,
    debugging, or running other community scripts on top of ROGBLOX.
]]

local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local M = {}

local state = {
    Open = false,
    History = {},
    HistoryIdx = 0,
}

local THEME = {
    Bg     = Color3.fromRGB(14, 14, 20),
    Panel  = Color3.fromRGB(22, 22, 32),
    Panel2 = Color3.fromRGB(28, 28, 40),
    Accent = Color3.fromRGB(140, 100, 255),
    Text   = Color3.fromRGB(235, 235, 245),
    Sub    = Color3.fromRGB(150, 150, 165),
    Good   = Color3.fromRGB(120, 220, 140),
    Bad    = Color3.fromRGB(235, 90, 100),
    Stroke = Color3.fromRGB(48, 48, 64),
}

local consoleGui
local editorBox, outputBox, runBtn, clearBtn, closeBtn
local toggleKey = Enum.KeyCode.Backquote   -- `~` key by default
local conns = {}

local function appendOutput(text, color)
    if not outputBox then return end
    color = color or THEME.Sub
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Font = Enum.Font.Code
    label.Text = text
    label.TextColor3 = color
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.TextWrapped = true
    label.RichText = false
    label.Parent = outputBox
end

local function runScript()
    local src = editorBox.Text
    if src == "" then return end
    table.insert(state.History, src)
    state.HistoryIdx = #state.History
    appendOutput("> " .. src:sub(1, 80) .. (src:len() > 80 and "..." or ""), THEME.Accent)

    -- print() override for captured output
    local oldPrint = print
    local capturedLines = {}
    local function localPrint(...)
        local args = {...}
        local parts = {}
        for i, v in ipairs(args) do parts[i] = tostring(v) end
        table.insert(capturedLines, table.concat(parts, "\t"))
    end

    local chunk, err = loadstring(src, "@ROGBLOX_console")
    if not chunk then
        appendOutput("compile error: " .. tostring(err), THEME.Bad)
        return
    end
    local env = setmetatable({print = localPrint}, {__index = getfenv()})
    setfenv(chunk, env)
    local ok, runtimeErr = pcall(chunk)
    for _, line in ipairs(capturedLines) do appendOutput(line, THEME.Text) end
    if not ok then
        appendOutput("runtime error: " .. tostring(runtimeErr), THEME.Bad)
    else
        appendOutput("[ok]", THEME.Good)
    end
    -- scroll to bottom on next frame
    task.defer(function()
        outputBox.CanvasPosition = Vector2.new(0, outputBox.AbsoluteCanvasSize.Y)
    end)
end

local function buildGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ROGBLOX_Console"
    gui.ResetOnSpawn = false
    gui.Enabled = false
    if syn and syn.protect_gui then syn.protect_gui(gui) end
    gui.Parent = (gethui and gethui()) or CoreGui

    local root = Instance.new("Frame")
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.new(0.5, 0, 0.5, 0)
    root.Size = UDim2.new(0, 720, 0, 480)
    root.BackgroundColor3 = THEME.Bg
    root.BorderSizePixel = 0
    root.Parent = gui
    Instance.new("UICorner", root).CornerRadius = UDim.new(0, 10)
    local s = Instance.new("UIStroke"); s.Color = THEME.Stroke; s.Thickness = 1; s.Parent = root

    -- title bar
    local title = Instance.new("Frame")
    title.BackgroundColor3 = THEME.Panel
    title.Size = UDim2.new(1, 0, 0, 32)
    title.BorderSizePixel = 0
    title.Parent = root
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)

    local titleText = Instance.new("TextLabel")
    titleText.BackgroundTransparency = 1
    titleText.Position = UDim2.new(0, 14, 0, 0)
    titleText.Size = UDim2.new(0, 300, 1, 0)
    titleText.Font = Enum.Font.GothamBold
    titleText.Text = "ROGBLOX Console"
    titleText.TextColor3 = THEME.Text
    titleText.TextSize = 13
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = title

    closeBtn = Instance.new("TextButton")
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.Position = UDim2.new(1, -10, 0.5, 0)
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.BackgroundColor3 = THEME.Bad
    closeBtn.AutoButtonColor = false
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "x"
    closeBtn.TextColor3 = THEME.Text
    closeBtn.TextSize = 12
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = title
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

    -- editor (top half)
    local editorFrame = Instance.new("Frame")
    editorFrame.BackgroundColor3 = THEME.Panel
    editorFrame.Position = UDim2.new(0, 10, 0, 40)
    editorFrame.Size = UDim2.new(1, -20, 0.55, -50)
    editorFrame.BorderSizePixel = 0
    editorFrame.Parent = root
    Instance.new("UICorner", editorFrame).CornerRadius = UDim.new(0, 6)

    local scroll = Instance.new("ScrollingFrame")
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Size = UDim2.new(1, -8, 1, -8)
    scroll.Position = UDim2.new(0, 4, 0, 4)
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = THEME.Accent
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.Parent = editorFrame

    editorBox = Instance.new("TextBox")
    editorBox.BackgroundTransparency = 1
    editorBox.Size = UDim2.new(1, -6, 0, 0)
    editorBox.AutomaticSize = Enum.AutomaticSize.Y
    editorBox.Font = Enum.Font.Code
    editorBox.TextColor3 = THEME.Text
    editorBox.PlaceholderText = "-- type Lua here, press Run (or Ctrl+Enter)\nprint('hello from ROGBLOX')"
    editorBox.PlaceholderColor3 = THEME.Sub
    editorBox.Text = ""
    editorBox.TextSize = 13
    editorBox.TextXAlignment = Enum.TextXAlignment.Left
    editorBox.TextYAlignment = Enum.TextYAlignment.Top
    editorBox.MultiLine = true
    editorBox.ClearTextOnFocus = false
    editorBox.TextWrapped = true
    editorBox.Parent = scroll

    -- buttons row
    local btnRow = Instance.new("Frame")
    btnRow.BackgroundTransparency = 1
    btnRow.Position = UDim2.new(0, 10, 0.55, -2)
    btnRow.Size = UDim2.new(1, -20, 0, 28)
    btnRow.Parent = root

    runBtn = Instance.new("TextButton")
    runBtn.BackgroundColor3 = THEME.Accent
    runBtn.AutoButtonColor = false
    runBtn.Size = UDim2.new(0, 80, 1, 0)
    runBtn.Font = Enum.Font.GothamBold
    runBtn.Text = "Run (Ctrl+Enter)"
    runBtn.TextColor3 = THEME.Text
    runBtn.TextSize = 11
    runBtn.BorderSizePixel = 0
    runBtn.AutomaticSize = Enum.AutomaticSize.X
    runBtn.Parent = btnRow
    Instance.new("UICorner", runBtn).CornerRadius = UDim.new(0, 5)

    clearBtn = Instance.new("TextButton")
    clearBtn.BackgroundColor3 = THEME.Panel
    clearBtn.AutoButtonColor = false
    clearBtn.AnchorPoint = Vector2.new(1, 0)
    clearBtn.Position = UDim2.new(1, 0, 0, 0)
    clearBtn.Size = UDim2.new(0, 80, 1, 0)
    clearBtn.Font = Enum.Font.GothamMedium
    clearBtn.Text = "Clear output"
    clearBtn.TextColor3 = THEME.Sub
    clearBtn.TextSize = 11
    clearBtn.BorderSizePixel = 0
    clearBtn.Parent = btnRow
    Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 5)

    -- output panel (bottom)
    local outputFrame = Instance.new("Frame")
    outputFrame.BackgroundColor3 = THEME.Panel2
    outputFrame.Position = UDim2.new(0, 10, 0.55, 30)
    outputFrame.Size = UDim2.new(1, -20, 0.45, -40)
    outputFrame.BorderSizePixel = 0
    outputFrame.Parent = root
    Instance.new("UICorner", outputFrame).CornerRadius = UDim.new(0, 6)

    outputBox = Instance.new("ScrollingFrame")
    outputBox.BackgroundTransparency = 1
    outputBox.BorderSizePixel = 0
    outputBox.Size = UDim2.new(1, -8, 1, -8)
    outputBox.Position = UDim2.new(0, 4, 0, 4)
    outputBox.ScrollBarThickness = 3
    outputBox.ScrollBarImageColor3 = THEME.Accent
    outputBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
    outputBox.CanvasSize = UDim2.new(0, 0, 0, 0)
    outputBox.Parent = outputFrame
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 2)
    layout.Parent = outputBox

    return gui, root
end

local function bindEvents()
    closeBtn.MouseButton1Click:Connect(function()
        state.Open = false
        consoleGui.Enabled = false
    end)
    runBtn.MouseButton1Click:Connect(runScript)
    clearBtn.MouseButton1Click:Connect(function()
        for _, child in ipairs(outputBox:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
    end)

    conns.key = UserInputService.InputBegan:Connect(function(input, processed)
        if input.KeyCode == toggleKey and not processed then
            state.Open = not state.Open
            consoleGui.Enabled = state.Open
        elseif state.Open and input.KeyCode == Enum.KeyCode.Return and
               UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            runScript()
        end
    end)
end

function M.Build(tab, ctx)
    consoleGui = buildGui()
    bindEvents()

    local sec = tab:AddSection("Console")
    sec:AddLabel("In-game Lua REPL. Paste scripts, run, inspect output.")
    sec:AddButton("Open console", function()
        state.Open = true
        consoleGui.Enabled = true
    end)
    sec:AddKeybind("Toggle key (default: ` )", toggleKey, function()
        state.Open = not state.Open
        consoleGui.Enabled = state.Open
    end)
    sec:AddButton("Run last", function()
        if state.History[#state.History] then
            editorBox.Text = state.History[#state.History]
            runScript()
        end
    end)
    sec:AddButton("Insert HttpGet template", function()
        editorBox.Text = 'loadstring(game:HttpGet("https://"))()'
    end)
end

function M.Unload()
    for _, c in pairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    if consoleGui then consoleGui:Destroy() end
    consoleGui = nil
end

M.State = state
return M
