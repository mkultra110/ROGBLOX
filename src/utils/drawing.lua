--[[
    Drawing API wrapper.
    Executors expose Drawing.new("Type") for on-screen shapes that
    bypass Roblox's GUI system. We wrap it to clean up on Remove and
    fall back to BillboardGui when Drawing isn't available.
]]

local M = {}

local hasDrawing = type(Drawing) == "table" and type(Drawing.new) == "function"
M.Supported = hasDrawing

local registry = setmetatable({}, {__mode = "v"})

local function fallback(class, props)
    -- Tiny BillboardGui-based fallback. Crude but keeps the UI alive
    -- on executors without Drawing.
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.Parent = workspace
    local bb = Instance.new("BillboardGui")
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, props.Size and props.Size.X or 50, 0, props.Size and props.Size.Y or 20)
    bb.Parent = part
    local frame = Instance.new(class == "Text" and "TextLabel" or "Frame")
    frame.BackgroundTransparency = class == "Text" and 1 or 0.5
    frame.BackgroundColor3 = props.Color or Color3.new(1, 1, 1)
    frame.Size = UDim2.new(1, 0, 1, 0)
    if class == "Text" then
        frame.Text = props.Text or ""
        frame.TextColor3 = props.Color or Color3.new(1, 1, 1)
        frame.Font = Enum.Font.GothamBold
        frame.TextSize = props.Size or 12
    end
    frame.Parent = bb
    return {
        _part = part, _frame = frame, _fallback = true,
        Remove = function(self)
            if self._part then self._part:Destroy(); self._part = nil end
        end,
        Set = function(self, k, v)
            if k == "Visible" then self._part.Parent = v and workspace or nil
            elseif k == "Color" then self._frame.BackgroundColor3 = v; if self._frame.TextColor3 then self._frame.TextColor3 = v end
            elseif k == "Text" and self._frame.Text then self._frame.Text = v end
            end
        end,
    }
end

function M.new(class, defaults)
    if hasDrawing then
        local obj = Drawing.new(class)
        for k, v in pairs(defaults or {}) do obj[k] = v end
        registry[#registry + 1] = obj
        return obj
    else
        local f = fallback(class, defaults or {})
        registry[#registry + 1] = f
        return f
    end
end

function M.RemoveAll()
    for _, obj in pairs(registry) do
        pcall(function()
            if obj.Remove then obj:Remove() end
        end)
    end
    table.clear(registry)
end

return M
