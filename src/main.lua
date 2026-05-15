--[[
    ROGBLOX — main entry point.
    Fetches each module from the repo, builds the UI, wires modules,
    and exposes _G.ROGBLOX for runtime control.
]]

local BRANCH = "main"
local BASE = "https://raw.githubusercontent.com/mkultra110/rogblox/" .. BRANCH .. "/"

local function fetch(path)
    local source = game:HttpGet(BASE .. path)
    local chunk, err = loadstring(source, "@" .. path)
    if not chunk then
        error("ROGBLOX load failed for " .. path .. ": " .. tostring(err))
    end
    return chunk()
end

-- libraries first
local UI           = fetch("src/library/ui.lua")
local Notify       = fetch("src/library/notify.lua")
local SaveManager  = fetch("src/library/savemanager.lua")
local ThemeManager = fetch("src/library/thememanager.lua")
local Config       = fetch("src/config.lua")

-- shared utilities
local PlayersUtil = fetch("src/utils/players.lua")
local Drawing     = fetch("src/utils/drawing.lua")
local Env         = fetch("src/utils/env.lua")

-- feature modules
local Aimbot     = fetch("src/modules/aimbot.lua")
local ESP        = fetch("src/modules/esp.lua")
local Combat     = fetch("src/modules/combat_extras.lua")
local Movement   = fetch("src/modules/movement.lua")
local Teleport   = fetch("src/modules/teleport.lua")
local HUD        = fetch("src/modules/hud.lua")
local World      = fetch("src/modules/world.lua")
local Farm       = fetch("src/modules/autofarm.lua")
local Games      = fetch("src/modules/games.lua")
local PlayerList = fetch("src/modules/playerlist.lua")
local Console    = fetch("src/modules/console.lua")
local Scripthub  = fetch("src/modules/scripthub.lua")
local Stats      = fetch("src/modules/stats.lua")
local Macro      = fetch("src/modules/macro.lua")
local Misc       = fetch("src/modules/misc.lua")

local Window = UI:CreateWindow({
    Title    = "ROGBLOX",
    SubTitle = "v0.5.0  HQ",
    Size     = Vector2.new(720, 500),
    Toggle   = Enum.KeyCode.RightControl,
})

local ctx = {
    UI          = UI,
    Window      = Window,
    Notify      = Notify,
    Config      = Config,
    SaveManager = SaveManager,
    Players     = PlayersUtil,
    Drawing     = Drawing,
    Env         = Env,
    Aimbot      = Aimbot,
}

-- Aimbot first so HUD can read its LockedTarget through ctx.
Aimbot.Build(    Window:AddTab("Aimbot"),     ctx)
HUD.Build(       Window:AddTab("HUD"),        ctx)
ESP.Build(       Window:AddTab("Visuals"),    ctx)
Combat.Build(    Window:AddTab("Combat+"),    ctx)
Movement.Build(  Window:AddTab("Movement"),   ctx)
Teleport.Build(  Window:AddTab("Teleport"),   ctx)
World.Build(     Window:AddTab("World"),      ctx)
Farm.Build(      Window:AddTab("Auto"),       ctx)
Games.Build(     Window:AddTab("Games"),      ctx)
PlayerList.Build(Window:AddTab("Players"),    ctx)
Console.Build(   Window:AddTab("Console"),    ctx)
Scripthub.Build( Window:AddTab("Scripthub"),  ctx)
Stats.Build(     Window:AddTab("Stats"),      ctx)
Macro.Build(     Window:AddTab("Macro"),      ctx)
Misc.Build(      Window:AddTab("Misc"),       ctx)

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

local themeSection = SettingsTab:AddSection("Theme")
themeSection:AddDropdown("Theme preset", ThemeManager.Names(), "Default", function(name)
    ThemeManager.Apply(UI, Window, name)
end)
themeSection:AddColorPicker("Accent color", UI.Theme.Accent, function(c) Window:SetAccent(c) end)

local profilesSection = SettingsTab:AddSection("Profiles (named configs)")
local profileName = "default"
profilesSection:AddTextBox("Profile name", "default", function(v) profileName = v ~= "" and v or "default" end)
profilesSection:AddButton("Save profile", function()
    local ok, info = SaveManager.Save(profileName)
    Notify:Send("Profile", ok and ("Saved " .. profileName) or ("Save failed: " .. tostring(info)), 3)
end)
profilesSection:AddButton("Load profile", function()
    local ok, info = SaveManager.Load(profileName)
    Notify:Send("Profile", ok and ("Loaded " .. profileName) or ("Load failed: " .. tostring(info)), 3)
end)
profilesSection:AddButton("Delete profile", function()
    if SaveManager.Delete(profileName) then
        Notify:Send("Profile", "Deleted " .. profileName, 3)
    end
end)
profilesSection:AddButton("Set as autoload", function()
    SaveManager.SetAutoload(profileName)
    Notify:Send("Profile", "Will autoload " .. profileName, 3)
end)
profilesSection:AddButton("Clear autoload", function()
    SaveManager.SetAutoload(nil)
    Notify:Send("Profile", "Autoload cleared", 3)
end)

local infoSection = SettingsTab:AddSection("About")
infoSection:AddLabel("ROGBLOX — pro Roblox cheat hub")
infoSection:AddLabel("Branch: " .. BRANCH)
infoSection:AddLabel("PlaceId: " .. tostring(game.PlaceId))
infoSection:AddLabel("JobId: " .. tostring(game.JobId))
infoSection:AddLabel("Press RightCtrl to toggle UI")

_G.ROGBLOX = {
    Version = "0.5.0",
    UI      = UI,
    Window  = Window,
    Notify  = Notify,
    Modules = {
        Aimbot     = Aimbot,
        ESP        = ESP,
        Combat     = Combat,
        Movement   = Movement,
        Teleport   = Teleport,
        HUD        = HUD,
        World      = World,
        Farm       = Farm,
        Games      = Games,
        PlayerList = PlayerList,
        Console    = Console,
        Scripthub  = Scripthub,
        Stats      = Stats,
        Macro      = Macro,
        Misc       = Misc,
    },
    Unload = function()
        for _, mod in ipairs({Aimbot, ESP, Combat, Movement, Teleport, HUD, World, Farm, Games, PlayerList, Console, Scripthub, Stats, Macro, Misc}) do
            if mod.Unload then pcall(mod.Unload) end
        end
        Window:Destroy()
        _G.ROGBLOX_LOADED = false
        _G.ROGBLOX = nil
    end,
}

Notify:Send("ROGBLOX", "v0.5.0 loaded - press RightCtrl to toggle UI", 4)
pcall(Config.Load)
-- Honor autoload profile if the user set one.
task.defer(function()
    pcall(SaveManager.AutoLoad)
end)
