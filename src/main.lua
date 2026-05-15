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
local Splash       = fetch("src/library/splash.lua")
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

-- Helper: builds a tab and runs the module's Build inside pcall so
-- a single broken module can't take the whole hub down. Logs the
-- error to the console and continues to the next module.
local loadFailures = {}
local function safeBuild(name, mod)
    local ok, err = pcall(function() mod.Build(Window:AddTab(name), ctx) end)
    if not ok then
        table.insert(loadFailures, name)
        warn(("[ROGBLOX] module %s failed to build: %s"):format(name, tostring(err)))
    end
end

-- Aimbot first so HUD can read its LockedTarget through ctx.
safeBuild("Aimbot",    Aimbot)
safeBuild("HUD",       HUD)
safeBuild("Visuals",   ESP)
safeBuild("Combat+",   Combat)
safeBuild("Movement",  Movement)
safeBuild("Teleport",  Teleport)
safeBuild("World",     World)
safeBuild("Auto",      Farm)
safeBuild("Games",     Games)
safeBuild("Players",   PlayerList)
safeBuild("Console",   Console)
safeBuild("Scripthub", Scripthub)
safeBuild("Stats",     Stats)
safeBuild("Macro",     Macro)
safeBuild("Misc",      Misc)

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

-- ----- Startup splash + notifications -----
-- Show a centered "ROGBLOX loaded" card for a couple seconds, then
-- raise the standard toast. If any modules failed to build, surface
-- them so the user knows the hub is partially up.
local moduleCount = 15
local builtCount  = moduleCount - #loadFailures
pcall(function()
    Splash.Show(
        "ROGBLOX v0.5.0",
        string.format("%d / %d modules ready. Press RightCtrl to toggle the menu.",
            builtCount, moduleCount),
        2.6
    )
end)
Notify:Send("ROGBLOX",
    "Loaded - press RightCtrl in-game to open the menu.", 4)
if #loadFailures > 0 then
    task.delay(2.8, function()
        Notify:Send("Warning",
            "Some modules failed to load: " .. table.concat(loadFailures, ", "), 6)
    end)
end

pcall(Config.Load)
-- Honor autoload profile if the user set one.
task.defer(function()
    pcall(SaveManager.AutoLoad)
end)
