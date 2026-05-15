--[[
    Auto-farm / auto-clicker / auto-attack module.
    Generic primitives — concrete farms are usually game-specific.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")

local M = {}
local state = {
    AutoClick    = false,
    CPS          = 16,
    AutoAttack   = false,         -- swing Tool every N seconds
    AttackRate   = 0.4,
    NearestNPC   = false,         -- walk to nearest NPC repeatedly
    NPCRange     = 80,
    NPCKeyword   = "",
}

local conns = {}

local function getRoot()
    local lp = Players.LocalPlayer
    local c = lp and lp.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function findNearestNPC()
    local root = getRoot()
    if not root then return nil end
    local needle = state.NPCKeyword:lower()
    local best, bestDist
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Health > 0 then
            local model = obj.Parent
            local hrp = model and model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
            local plr = Players:GetPlayerFromCharacter(model)
            if hrp and not plr then
                if needle == "" or model.Name:lower():find(needle, 1, true) then
                    local d = (hrp.Position - root.Position).Magnitude
                    if d <= state.NPCRange and (not bestDist or d < bestDist) then
                        best, bestDist = hrp, d
                    end
                end
            end
        end
    end
    return best
end

function M.Build(tab, ctx)
    local clickSec = tab:AddSection("Auto Clicker")
    clickSec:AddToggle("Enabled", false, function(v) state.AutoClick = v end)
    clickSec:AddSlider("CPS", 1, 60, 16, function(v) state.CPS = v end)
    clickSec:AddLabel("Tip: most games block mouse1press detection; if it doesn't fire, set a hotkey.")

    task.spawn(function()
        while true do
            if state.AutoClick then
                pcall(function()
                    if mouse1click then mouse1click()
                    elseif mouse1press and mouse1release then mouse1press(); mouse1release() end
                end)
                task.wait(1 / math.max(state.CPS, 1))
            else
                task.wait(0.1)
            end
        end
    end)

    local attackSec = tab:AddSection("Auto Attack")
    attackSec:AddToggle("Activate equipped tool", false, function(v) state.AutoAttack = v end)
    attackSec:AddSlider("Rate (sec)", 0.05, 5, 0.4, function(v) state.AttackRate = v end)
    task.spawn(function()
        while true do
            if state.AutoAttack then
                local lp = Players.LocalPlayer
                local char = lp and lp.Character
                if char then
                    for _, tool in ipairs(char:GetChildren()) do
                        if tool:IsA("Tool") then
                            pcall(function() tool:Activate() end)
                        end
                    end
                end
                task.wait(state.AttackRate)
            else
                task.wait(0.1)
            end
        end
    end)

    local farmSec = tab:AddSection("NPC Tracker")
    farmSec:AddToggle("Track nearest NPC", false, function(v) state.NearestNPC = v end)
    farmSec:AddSlider("Range", 5, 500, 80, function(v) state.NPCRange = v end)
    farmSec:AddTextBox("Name filter", "(blank = any)", function(v) state.NPCKeyword = v end)
    farmSec:AddButton("Teleport to nearest", function()
        local t = findNearestNPC()
        local root = getRoot()
        if t and root then root.CFrame = t.CFrame + Vector3.new(0, 0, 3) end
    end)

    conns.farm = RunService.Heartbeat:Connect(function()
        if not state.NearestNPC then return end
        local t = findNearestNPC()
        local root = getRoot()
        if t and root then
            local hum = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:MoveTo(t.Position)
            end
        end
    end)
end

function M.Unload()
    for _, c in pairs(conns) do if c.Disconnect then pcall(function() c:Disconnect() end) end end
end

M.State = state
return M
