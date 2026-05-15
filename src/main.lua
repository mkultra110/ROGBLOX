--[[
    ROGBLOX — main entry point
    Fetches each module from the repo, wires them together,
    builds the UI, and exposes _G.ROGBLOX for runtime control.
]]

local BRANCH = "main"
local BASE = "https://raw.githubusercontent.com/mkultra110/rogblox/" .. BRANCH .. "/"

local function fetch(path)
    local url = BASE .. path
    local source = game:HttpGet(url)
    local chunk, err = loadstring(source, "@" .. path)
    if not chunk then
        error("ROGBLOX load failed for " .. path .. ": " .. tostring(err))
    end
    return chunk()
end

-- libraries first
local UI       = fetch("src/library/ui.lua")
local Notify   = fetch("src/library/notify.lua")
local Config   = fetch("src/config.lua")

-- shared utilities
local PlayersUtil = fetch("src/utils/players.lua")
local Drawing     = fetch("src/utils/drawing.lua")

-- feature modules
local Aimbot   = fetch("src/modules/aimbot.lua")
local ESP      = fetch("src/modules/esp.lua")
local Combat   = fetch("src/modules/combat_extras.lua")
local Movement = fetch("src/modules/movement.lua")
local Teleport = fetch("src/modules/teleport.lua")
local World    = fetch("src/modules/world.lua")
local Farm     = fetch("src/modules/autofarm.lua")
local Misc     = fetch("src/modules/misc.lua")

local Window = UI:CreateWindow({
    Title    = "ROGBLOX",
    SubTitle = "v0.2.0  ⚡  for LO",
    Size     = Vector2.new(620, 400),
    Toggle   = Enum.KeyCode.RightControl,
})

local ctx = {
    UI       = UI,
    Window   = Window,
    Notify   = Notify,
    Config   = Config,
    Players  = PlayersUtil,
    Drawing  = Drawing,
}

Aimbot.Build(  Window:AddTab("Aimbot"),   ctx)
ESP.Build(     Window:AddTab("Visuals"),  ctx)
Combat.Build(  Window:AddTab("Combat+"),  ctx)
Movement.Build(Window:AddTab("Movement"), ctx)
Teleport.Build(Window:AddTab("Teleport"), ctx)
World.Build(   Window:AddTab("World"),    ctx)
Farm.Build(    Window:AddTab("Auto"),     ctx)
Misc.Build(    Window:AddTab("Misc"),     ctx)

local SettingsTab = Window:AddTab("Settings")
local cfgSection = SettingsTab:AddSection("Config")
cfgSection:AddButton("Save", function()
    Config.Save()
    Notify:Send("Config", "Saved for PlaceId " .. tostring(game.PlaceId), 3)
end)
cfgSection:AddButton("Load", function()
    Config.Load()
    Notify:Send("Config", "Loaded", 3)
end)
cfgSection:AddButton("Reset", function()
    Config.Reset()
    Notify:Send("Config", "Reset to defaults", 3)
end)

local infoSection = SettingsTab:AddSection("About")
infoSection:AddLabel("ROGBLOX — Roblox cheat hub")
infoSection:AddLabel("Branch: " .. BRANCH)
infoSection:AddLabel("PlaceId: " .. tostring(game.PlaceId))
infoSection:AddLabel("JobId: " .. tostring(game.JobId))
infoSection:AddLabel("Press RightCtrl to toggle UI")

-- public API
_G.ROGBLOX = {
    Version = "0.2.0",
    UI      = UI,
    Window  = Window,
    Notify  = Notify,
    Modules = {
        Aimbot   = Aimbot,
        ESP      = ESP,
        Combat   = Combat,
        Movement = Movement,
        Teleport = Teleport,
        World    = World,
        Farm     = Farm,
        Misc     = Misc,
    },
    Unload = function()
        for _, mod in pairs({Aimbot, ESP, Combat, Movement, Teleport, World, Farm, Misc}) do
            if mod.Unload then pcall(mod.Unload) end
        end
        Window:Destroy()
        _G.ROGBLOX_LOADED = false
        _G.ROGBLOX = nil
    end,
}

Notify:Send("ROGBLOX", "Loaded — press RightCtrl to toggle UI", 4)
pcall(Config.Load)
