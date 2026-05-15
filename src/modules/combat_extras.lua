--[[
    Combat extras — silent aim hook, hitbox expander, kill aura, god-mode attempts,
    no-recoil shim. Many of these are game-specific; defaults use the broadest
    patterns that work on the majority of FPS/shooter Roblox titles.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")

local M = {}
local conns = {}
local alive = false   -- gate for background loops
local hookState = {}  -- snapshot of metatable handlers we replaced

local state = {
    SilentAim        = false,
    SilentFOV        = 50,
    SilentTeamCheck  = false,
    HitboxExpand     = false,
    HitboxSize       = 12,
    HitboxTransparency = 0.7,
    KillAura         = false,
    KillAuraRange    = 12,
    KillAuraRate     = 0.1,
    GodMode          = false,
    AntiAim          = false,
}

local function getRoot()
    local lp = Players.LocalPlayer
    local c = lp and lp.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local lp = Players.LocalPlayer
    local c = lp and lp.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ---------- Silent Aim ----------
-- Hooks the most common targeting methods game scripts use:
-- mouse.Hit, mouse.Target, GetMouseLocation, raycasts.

local hookedSilent = false
local origMouseHit, origMouseTarget

local function closestToCenter()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local center = cam.ViewportSize / 2
    local best, bestDist
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer then
            local char = plr.Character
            local head = char and char:FindFirstChild("Head")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                if not (state.SilentTeamCheck and plr.Team and Players.LocalPlayer.Team == plr.Team) then
                    local p, on = cam:WorldToViewportPoint(head.Position)
                    if on then
                        local d = (Vector2.new(p.X, p.Y) - center).Magnitude
                        if d <= state.SilentFOV and (not bestDist or d < bestDist) then
                            best, bestDist = plr, d
                        end
                    end
                end
            end
        end
    end
    return best
end

local function hookSilentAim()
    if hookedSilent then return end
    if not (hookmetamethod and getrawmetatable) then return end
    hookedSilent = true

    local mt = getrawmetatable(game)
    local oldIndex = mt.__index
    local oldNamecall = mt.__namecall
    if setreadonly then setreadonly(mt, false) end

    -- Save originals so Unload can restore. The metatable can't truly be
    -- "unhooked" via hookmetamethod, but we can restore the slots we
    -- replaced so subsequent reloads don't chain hooks.
    hookState.mt          = mt
    hookState.oldIndex    = oldIndex
    hookState.oldNamecall = oldNamecall

    local function redirectHead()
        if not state.SilentAim then return nil end
        local target = closestToCenter()
        if not target then return nil end
        local char = target.Character
        return char and char:FindFirstChild("Head")
    end

    mt.__index = newcclosure(function(self, key)
        if state.SilentAim and typeof(self) == "Instance" and self:IsA("Mouse") then
            if key == "Hit" then
                local head = redirectHead()
                if head then return CFrame.new(head.Position) end
            elseif key == "Target" then
                local head = redirectHead()
                if head then return head end
            end
        end
        return oldIndex(self, key)
    end)

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if state.SilentAim and method == "GetMouseLocation" and typeof(self) == "Instance" and self.ClassName == "UserInputService" then
            local head = redirectHead()
            if head then
                local cam = Workspace.CurrentCamera
                local screen = cam:WorldToViewportPoint(head.Position)
                return Vector2.new(screen.X, screen.Y)
            end
        end
        if state.SilentAim and (method == "Raycast" or method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList") and typeof(self) == "Instance" and self.ClassName == "Workspace" then
            local args = {...}
            local origin = args[1]
            local head = redirectHead()
            if head and typeof(origin) == "Vector3" then
                args[2] = (head.Position - origin)
                return oldNamecall(self, table.unpack(args))
            end
        end
        return oldNamecall(self, ...)
    end)
end

-- ---------- Hitbox Expander ----------

local hitboxConn
local function startHitbox()
    if hitboxConn then return end
    hitboxConn = RunService.Heartbeat:Connect(function()
        if not state.HitboxExpand then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Players.LocalPlayer then
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Size = Vector3.new(state.HitboxSize, state.HitboxSize, state.HitboxSize)
                    hrp.Transparency = state.HitboxTransparency
                    hrp.Material = Enum.Material.Neon
                    hrp.BrickColor = BrickColor.new("Bright red")
                    hrp.CanCollide = false
                end
            end
        end
    end)
    conns.hitbox = hitboxConn
end

-- ---------- Kill Aura ----------

local function killAuraStep()
    local root = getRoot()
    if not root then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer then
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local d = (hrp.Position - root.Position).Magnitude
                if d <= state.KillAuraRange then
                    -- Try common damage RemoteEvent names. Best-effort.
                    local rs = game:GetService("ReplicatedStorage")
                    for _, candidate in ipairs({"Damage", "DealDamage", "Hit", "Attack"}) do
                        local ev = rs:FindFirstChild(candidate, true)
                        if ev and ev:IsA("RemoteEvent") then
                            pcall(function() ev:FireServer(plr, 1e6) end)
                        end
                    end
                    -- Touch-based: tween a part to the target
                    local touchPart = root.Parent and root.Parent:FindFirstChild("RightHand")
                                   or (root.Parent and root.Parent:FindFirstChild("Right Arm"))
                    if touchPart then
                        local saved = touchPart.CFrame
                        for i = 1, 3 do
                            touchPart.CFrame = hrp.CFrame
                            task.wait()
                        end
                        touchPart.CFrame = saved
                    end
                end
            end
        end
    end
end

-- ---------- God Mode (best-effort) ----------
-- Roblox damage is server-authoritative; client-side godmode is only
-- effective against client-side projectiles or visual damage.

local godConn
local function startGodMode()
    if godConn then return end
    godConn = RunService.Heartbeat:Connect(function()
        if not state.GodMode then return end
        local hum = getHum()
        if hum then
            hum.Health = hum.MaxHealth
        end
    end)
    conns.god = godConn
end

-- ---------- Anti-Aim ----------
-- Spin the root part so the server sees you facing a chaotic direction
-- (only effective in games that use the root's orientation for hitreg).

local antiAimConn
local function startAntiAim()
    if antiAimConn then return end
    antiAimConn = RunService.Heartbeat:Connect(function()
        if not state.AntiAim then return end
        local root = getRoot()
        if root then
            root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
        end
    end)
    conns.antiAim = antiAimConn
end

function M.Build(tab, ctx)
    alive = true
    hookSilentAim()
    startHitbox()
    startGodMode()
    startAntiAim()

    local sa = tab:AddSection("Silent Aim")
    sa:AddToggle("Enabled", false, function(v) state.SilentAim = v end)
    sa:AddSlider("FOV", 10, 500, 50, function(v) state.SilentFOV = v end)
    sa:AddToggle("Team check", false, function(v) state.SilentTeamCheck = v end)
    sa:AddLabel("Hooks Mouse.Hit / Mouse.Target / Raycast")

    local hb = tab:AddSection("Hitbox Expander")
    hb:AddToggle("Enabled", false, function(v) state.HitboxExpand = v end)
    hb:AddSlider("Size", 4, 30, 12, function(v) state.HitboxSize = v end)
    hb:AddSlider("Transparency", 0, 1, 0.7, function(v) state.HitboxTransparency = v end)

    local ka = tab:AddSection("Kill Aura (best-effort)")
    ka:AddToggle("Enabled", false, function(v) state.KillAura = v end)
    ka:AddSlider("Range", 4, 40, 12, function(v) state.KillAuraRange = v end)
    ka:AddSlider("Tick rate (ms)", 50, 1000, 100, function(v) state.KillAuraRate = v / 1000 end)
    task.spawn(function()
        while alive do
            task.wait(state.KillAuraRate)
            if state.KillAura then pcall(killAuraStep) end
        end
    end)

    local gm = tab:AddSection("Other")
    gm:AddToggle("God Mode (client-side)", false, function(v) state.GodMode = v end)
    gm:AddToggle("Anti-Aim (root spin)", false, function(v) state.AntiAim = v end)
end

function M.Unload()
    alive = false
    state.SilentAim   = false
    state.HitboxExpand = false
    state.KillAura    = false
    state.GodMode     = false
    state.AntiAim     = false
    -- Restore the metatable slots we hijacked so subsequent reloads
    -- don't chain on top of our handlers.
    if hookedSilent and hookState.mt then
        pcall(function()
            if setreadonly then setreadonly(hookState.mt, false) end
            hookState.mt.__index    = hookState.oldIndex
            hookState.mt.__namecall = hookState.oldNamecall
            if setreadonly then setreadonly(hookState.mt, true) end
        end)
        hookedSilent = false
        hookState = {}
    end
    for _, c in pairs(conns) do
        if c and c.Disconnect then pcall(function() c:Disconnect() end) end
    end
    conns = {}
    hitboxConn, godConn, antiAimConn = nil, nil, nil
end

M.State = state
return M
