--[[
    Teleport — professional implementation.

    - Live player list (refresh, distance, HP shown next to names)
    - 10 named waypoint slots with save / load / clear / rename
    - TP modes: To, Behind, In front, Above, Below, Aim TP (where camera looks)
    - Pathwalk: smooth interp to destination over N seconds
    - TP history (back / forward stack)
    - Click-TP (Ctrl + click)
    - Server hop, rejoin
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TeleportService  = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local Workspace        = game:GetService("Workspace")
local TweenService     = game:GetService("TweenService")

local M = {}

local state = {
    Mode       = "To",      -- To | Behind | InFront | Above | Below | Aim
    Offset     = 3,
    PathWalk   = false,
    PathTime   = 0.5,
    ClickTP    = false,
}

local SLOTS = 10
local saved = {}            -- [slot] = {Name = string, CFrame = CFrame}
local history = {}          -- stack of CFrames before each TP
local future = {}           -- redo stack
local conns = {}

-- ---------- Helpers ----------

local function getChar()
    local lp = Players.LocalPlayer
    return lp and lp.Character
end

local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function pushHistory()
    local r = getRoot()
    if r then
        table.insert(history, r.CFrame)
        if #history > 32 then table.remove(history, 1) end
        future = {}
    end
end

local function doTeleport(target)
    if not target then return end
    local root = getRoot()
    if not root then return end
    pushHistory()
    if state.PathWalk and state.PathTime > 0 then
        local t = TweenService:Create(root, TweenInfo.new(state.PathTime, Enum.EasingStyle.Linear), {CFrame = target})
        t:Play()
    else
        root.CFrame = target
    end
end

local function targetCFrameForMode(plr)
    local char = plr and plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local cf = hrp.CFrame
    local off = state.Offset
    if state.Mode == "To" then
        return cf * CFrame.new(0, 0, -off)
    elseif state.Mode == "Behind" then
        return cf * CFrame.new(0, 0, off)
    elseif state.Mode == "InFront" then
        return cf * CFrame.new(0, 0, -off)
    elseif state.Mode == "Above" then
        return cf + Vector3.new(0, off, 0)
    elseif state.Mode == "Below" then
        return cf - Vector3.new(0, off, 0)
    elseif state.Mode == "Aim" then
        local cam = Workspace.CurrentCamera
        if not cam then return cf end
        local origin = cam.CFrame.Position
        local lookDir = cam.CFrame.LookVector
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {getChar()}
        local result = Workspace:Raycast(origin, lookDir * 1000, params)
        local pos = result and result.Position or (origin + lookDir * 50)
        return CFrame.new(pos + Vector3.new(0, off, 0))
    end
    return cf
end

local function playerList()
    local names = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer then
            local meta = plr.Name
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local myRoot = getRoot()
            if hrp and hum and myRoot then
                meta = string.format("%s  [%dm %d%%]", plr.Name,
                    math.floor((hrp.Position - myRoot.Position).Magnitude),
                    math.floor(hum.Health / math.max(hum.MaxHealth, 1) * 100))
            end
            table.insert(names, meta)
        end
    end
    if #names == 0 then table.insert(names, "(no other players)") end
    return names
end

local function findPlayerByMeta(meta)
    if not meta then return nil end
    local name = meta:match("^([^%s]+)")
    if not name or name == "(no" then return nil end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name == name then return plr end
    end
    return nil
end

-- ---------- Build UI ----------

function M.Build(tab, ctx)
    local Notify = ctx.Notify
    local UI = ctx.UI

    -- ----- Player list -----
    local plrSec = tab:AddSection("Teleport to Player")
    local picked
    local dropdown = plrSec:AddDropdown("Player", playerList(), playerList()[1], function(v) picked = v end)

    plrSec:AddButton("Refresh list", function()
        dropdown:SetOptions(playerList())
        Notify:Send("Teleport", "Player list refreshed", 2)
    end)
    plrSec:AddDropdown("TP mode", {"To","Behind","InFront","Above","Below","Aim"}, "To", function(v) state.Mode = v end)
    plrSec:AddSlider("Offset", 0, 30, 3, function(v) state.Offset = v end)
    plrSec:AddButton("Teleport", function()
        local plr = findPlayerByMeta(picked)
        local cf = plr and targetCFrameForMode(plr)
        if cf then doTeleport(cf) else Notify:Send("Teleport", "No target selected", 2) end
    end)
    plrSec:AddButton("Spectate", function()
        local plr = findPlayerByMeta(picked)
        local hum = plr and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then Workspace.CurrentCamera.CameraSubject = hum end
    end)
    plrSec:AddButton("Reset camera", function()
        local hum = getChar() and getChar():FindFirstChildOfClass("Humanoid")
        if hum then Workspace.CurrentCamera.CameraSubject = hum end
    end)

    -- Auto-refresh player list when players join/leave
    conns.added = Players.PlayerAdded:Connect(function() pcall(function() dropdown:SetOptions(playerList()) end) end)
    conns.left  = Players.PlayerRemoving:Connect(function() pcall(function() dropdown:SetOptions(playerList()) end) end)

    -- ----- Pathwalk -----
    local pathSec = tab:AddSection("Pathwalk")
    pathSec:AddToggle("Smooth teleport (tween)", false, function(v) state.PathWalk = v end)
    pathSec:AddSlider("Path duration (s)", 0.05, 5, 0.5, function(v) state.PathTime = v end, {Decimals = 2})

    -- ----- Waypoint slots -----
    local wpSec = tab:AddSection("Waypoints")
    for slot = 1, SLOTS do
        saved[slot] = {Name = "Slot " .. slot, CFrame = nil}
        local row = nil
        wpSec:AddTextBox("Name " .. slot, "Slot " .. slot, function(text)
            saved[slot].Name = text ~= "" and text or ("Slot " .. slot)
        end)
        wpSec:AddButton("Save slot " .. slot, function()
            local r = getRoot()
            if r then
                saved[slot].CFrame = r.CFrame
                Notify:Send("Waypoint", "Saved: " .. saved[slot].Name, 2)
            end
        end)
        wpSec:AddButton("Load slot " .. slot, function()
            if saved[slot].CFrame then
                doTeleport(saved[slot].CFrame)
            else
                Notify:Send("Waypoint", "Slot " .. slot .. " is empty", 2)
            end
        end)
        wpSec:AddButton("Clear slot " .. slot, function()
            saved[slot].CFrame = nil
            Notify:Send("Waypoint", "Cleared slot " .. slot, 2)
        end)
        wpSec:AddDivider()
    end

    -- ----- History -----
    local histSec = tab:AddSection("Teleport History")
    histSec:AddButton("Undo (back)", function()
        local last = table.remove(history)
        if last then
            local r = getRoot()
            if r then
                table.insert(future, r.CFrame)
                r.CFrame = last
            end
        else
            Notify:Send("History", "Nothing to undo", 2)
        end
    end)
    histSec:AddButton("Redo (forward)", function()
        local next_ = table.remove(future)
        if next_ then
            local r = getRoot()
            if r then
                table.insert(history, r.CFrame)
                r.CFrame = next_
            end
        else
            Notify:Send("History", "Nothing to redo", 2)
        end
    end)
    histSec:AddButton("Clear history", function()
        history = {}; future = {}
        Notify:Send("History", "Cleared", 2)
    end)

    -- ----- Click TP -----
    local clkSec = tab:AddSection("Click TP")
    clkSec:AddToggle("Hold Ctrl + click world", false, function(v) state.ClickTP = v end)
    conns.click = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if not state.ClickTP then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then return end
        local mouse = Players.LocalPlayer:GetMouse()
        if mouse.Hit then
            doTeleport(mouse.Hit + Vector3.new(0, state.Offset, 0))
        end
    end)

    -- ----- Server -----
    local srvSec = tab:AddSection("Server")
    srvSec:AddButton("Rejoin current server", function()
        TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
    end)
    srvSec:AddButton("Server hop (lowest pop)", function()
        local ok, data = pcall(function()
            local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        if not (ok and data and data.data) then
            Notify:Send("Server hop", "Failed to fetch", 3); return
        end
        for _, srv in ipairs(data.data) do
            if srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, Players.LocalPlayer)
                end)
                return
            end
        end
        Notify:Send("Server hop", "No suitable server", 3)
    end)
end

function M.Unload()
    for _, c in pairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
end

M.State = state
M.Saved = saved
return M
