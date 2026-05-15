--[[
    Player utility helpers — iteration, alive checks, distance,
    LOS, and finding the closest target for aimbot.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local M = {}

function M.LocalPlayer()
    return Players.LocalPlayer
end

function M.LocalCharacter()
    local lp = Players.LocalPlayer
    return lp and lp.Character
end

function M.LocalRoot()
    local char = M.LocalCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

function M.GetHumanoid(plr)
    local char = plr and plr.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

function M.GetRoot(plr)
    local char = plr and plr.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

function M.GetHead(plr)
    local char = plr and plr.Character
    return char and char:FindFirstChild("Head")
end

function M.IsAlive(plr)
    local hum = M.GetHumanoid(plr)
    return hum and hum.Health > 0
end

function M.SameTeam(plr)
    local lp = Players.LocalPlayer
    if not lp or not plr then return false end
    if not lp.Team or not plr.Team then return false end
    return lp.Team == plr.Team
end

function M.Distance(a, b)
    if not a or not b then return math.huge end
    return (a.Position - b.Position).Magnitude
end

-- Line of sight check using Raycast. Accepts either a BasePart or a
-- table with a Position field as the "from".
function M.HasLOS(from, toPart, ignoreList)
    if not from or not toPart then return false end
    local origin = (typeof(from) == "Instance" and from.Position) or from.Position
    if not origin then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {M.LocalCharacter()}
    if ignoreList then
        for _, v in ipairs(ignoreList) do table.insert(ignore, v) end
    end
    params.FilterDescendantsInstances = ignore
    local dir = (toPart.Position - origin)
    local result = Workspace:Raycast(origin, dir, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(toPart.Parent)
end

-- Finds the closest player to a screen position (in pixels)
function M.ClosestToScreenPoint(screenPoint, opts)
    opts = opts or {}
    local camera = Workspace.CurrentCamera
    if not camera then return nil end
    local maxFov = opts.MaxFov or 100
    local checkTeam = opts.CheckTeam
    local checkLOS = opts.CheckLOS
    local part = opts.Part or "Head"

    local closest, bestDist
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer and M.IsAlive(plr) then
            if not (checkTeam and M.SameTeam(plr)) then
                local target = plr.Character and plr.Character:FindFirstChild(part)
                if target then
                    local screen, onScreen = camera:WorldToViewportPoint(target.Position)
                    if onScreen then
                        local dx = screen.X - screenPoint.X
                        local dy = screen.Y - screenPoint.Y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        if dist <= maxFov and (not bestDist or dist < bestDist) then
                            if not checkLOS or M.HasLOS({Position = camera.CFrame.Position}, target) then
                                bestDist = dist
                                closest = plr
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

function M.ForEachPlayer(fn)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer then
            task.spawn(fn, plr)
        end
    end
end

return M
