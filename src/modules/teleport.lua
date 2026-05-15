--[[
    Teleport module — to player, saved slots, click-tp, server hop, rejoin.
]]

local Players          = game:GetService("Players")
local TeleportService  = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local Workspace        = game:GetService("Workspace")

local M = {}

local saved = {}   -- slot -> CFrame
local clickEnabled = false
local clickConn

local function getRoot()
    local lp = Players.LocalPlayer
    local c = lp and lp.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function tpTo(target)
    local root = getRoot()
    if not root or not target then return false end
    root.CFrame = target
    return true
end

local function nameList()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer then
            table.insert(names, plr.Name)
        end
    end
    if #names == 0 then table.insert(names, "(none)") end
    return names
end

local function findPlayer(name)
    if not name or name == "(none)" then return nil end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name == name or plr.DisplayName == name then return plr end
    end
    return nil
end

function M.Build(tab, ctx)
    local Notify = ctx.Notify

    -- ---- TP to player ----
    local toPlrSec = tab:AddSection("Teleport to Player")
    local picked
    local dropdown
    dropdown = toPlrSec:AddDropdown("Player", nameList(), nameList()[1], function(v) picked = v end)
    toPlrSec:AddButton("Refresh list", function()
        -- rebuild by adding a new dropdown is overkill; warn the user instead
        Notify:Send("Teleport", "Reopen the menu after lobby changes.", 2)
    end)
    toPlrSec:AddButton("Teleport", function()
        local plr = findPlayer(picked)
        if not plr or not plr.Character then return end
        local r = plr.Character:FindFirstChild("HumanoidRootPart")
        if r then tpTo(r.CFrame + Vector3.new(0, 3, 0)) end
    end)
    toPlrSec:AddButton("Spectate (set camera)", function()
        local plr = findPlayer(picked)
        if not plr or not plr.Character then return end
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then Workspace.CurrentCamera.CameraSubject = hum end
    end)
    toPlrSec:AddButton("Reset camera", function()
        local lp = Players.LocalPlayer
        local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
        if hum then Workspace.CurrentCamera.CameraSubject = hum end
    end)

    -- ---- Saved positions ----
    local slotsSec = tab:AddSection("Saved Positions")
    for slot = 1, 3 do
        slotsSec:AddButton("Save slot " .. slot, function()
            local r = getRoot()
            if r then
                saved[slot] = r.CFrame
                Notify:Send("Teleport", "Saved slot " .. slot, 2)
            end
        end)
        slotsSec:AddButton("Load slot " .. slot, function()
            if saved[slot] then tpTo(saved[slot]) end
        end)
    end

    -- ---- Click teleport ----
    local clickSec = tab:AddSection("Click Teleport")
    clickSec:AddToggle("Hold Ctrl + click", false, function(v)
        clickEnabled = v
    end)
    clickConn = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if not clickEnabled then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then return end
        local mouse = Players.LocalPlayer:GetMouse()
        if mouse.Hit then
            tpTo(mouse.Hit + Vector3.new(0, 3, 0))
        end
    end)

    -- ---- Server actions ----
    local serverSec = tab:AddSection("Server")
    serverSec:AddButton("Rejoin", function()
        TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
    end)
    serverSec:AddButton("Server hop (low pop)", function()
        local ok, data = pcall(function()
            local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        if not ok or not data or not data.data then
            Notify:Send("Server hop", "Failed to fetch servers", 3)
            return
        end
        for _, srv in ipairs(data.data) do
            if srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, Players.LocalPlayer)
                end)
                return
            end
        end
        Notify:Send("Server hop", "No suitable server found", 3)
    end)
end

function M.Unload()
    if clickConn then clickConn:Disconnect() end
end

M.State = saved
return M
