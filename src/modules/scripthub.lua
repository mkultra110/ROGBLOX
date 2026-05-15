--[[
    Scripthub — run / save / autoload third-party community scripts on
    top of ROGBLOX. Pastes a URL or raw Lua, executes it, and remembers
    favorites per-PlaceId so they auto-run next session.

    Storage: ROGBLOX/scripthub/<placeId>.json
        {favorites = {{name, url}, ...}, autorun = {name, ...}}
]]

local HttpService = game:GetService("HttpService")

local M = {}
local conns = {}

-- Curated catalog of well-known free community scripts. Pre-seeded as
-- favorites on first run so the user has an immediate library to draw
-- from. URLs picked from long-running, generally-stable raw GitHub
-- sources. Add / remove freely.
local CATALOG = {
    -- Universal hubs
    {name="Owl Hub",                 url="https://raw.githubusercontent.com/CriShoux/OwlHub/master/OwlHub.txt"},
    {name="Infinite Yield (admin)",  url="https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"},
    {name="Dex Explorer",            url="https://raw.githubusercontent.com/peyton2465/Dex/master/out.lua"},
    {name="Remote Spy",              url="https://raw.githubusercontent.com/exxtremestuffs/SimpleSpySource/master/SimpleSpy.lua"},
    {name="EzHub Universal",         url="https://raw.githubusercontent.com/EZHUB/Scripts/main/loader.lua"},
    {name="Hydroxide (debug)",       url="https://raw.githubusercontent.com/Upbolt/Hydroxide/revision/main.lua"},
    -- Universal aimbots
    {name="Universal Silent Aim",    url="https://raw.githubusercontent.com/Stefanuk12/ROBLOX/master/Universal/UniversalSilentAim.lua"},
    {name="Universal Aim-Lock",      url="https://raw.githubusercontent.com/Averiias/Universal-SilentAim/main/main.lua"},
    {name="AimHot v8",               url="https://raw.githubusercontent.com/Herrtt/AimHot-v8/master/Main.lua"},
    {name="Stefanuk12 Aiming",       url="https://raw.githubusercontent.com/Stefanuk12/Aiming/main/Examples/UniversalSilentAim.lua"},
    {name="Cripware Universal",      url="https://raw.githubusercontent.com/yerbowanie/Cripware/master/cripware.lua"},
    -- Universal ESP
    {name="Universal ESP (wa0101)",  url="https://raw.githubusercontent.com/wa0101/Roblox-ESP/main/esp.lua"},
    {name="Unnamed ESP",             url="https://raw.githubusercontent.com/ic3w0lf22/Unnamed-ESP/master/UnnamedESP.lua"},
    {name="Highlight Chams",         url="https://raw.githubusercontent.com/0zBug/Highlight/main/main.lua"},
    -- UI libraries (for user scripts)
    {name="LinoriaLib loader",       url="https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"},
    {name="Rayfield",                url="https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"},
    {name="Fluent",                  url="https://raw.githubusercontent.com/dawid-scripts/Fluent/master/main.lua"},
    -- Game-specific staples (placeholders for users to add their own)
    {name="Arsenal aimbot+esp",      url="https://raw.githubusercontent.com/0x777Luck/farewell-roblox/main/arsenal.lua"},
    {name="Phantom Forces hub",      url="https://raw.githubusercontent.com/0x777Luck/farewell-roblox/main/phantomforces.lua"},
    {name="Da Hood premium-ish",     url="https://raw.githubusercontent.com/Stefanuk12/ROBLOX/master/Games/Da%20Hood/Main.lua"},
    {name="Counter Blox aim",        url="https://raw.githubusercontent.com/0x777Luck/farewell-roblox/main/counterblox.lua"},
    {name="Murder Mystery 2 hub",    url="https://raw.githubusercontent.com/scripts-hub/scripts/main/mm2.lua"},
    {name="KAT auto-parry",          url="https://raw.githubusercontent.com/scripts-hub/scripts/main/kat.lua"},
    {name="Bad Business universal",  url="https://raw.githubusercontent.com/0x777Luck/farewell-roblox/main/badbusiness.lua"},
    {name="Strucid aim",             url="https://raw.githubusercontent.com/scripts-hub/scripts/main/strucid.lua"},
    {name="Island Royale aim",       url="https://raw.githubusercontent.com/scripts-hub/scripts/main/islandroyale.lua"},
    {name="Blox Fruits auto-farm",   url="https://raw.githubusercontent.com/scripts-hub/scripts/main/bloxfruits.lua"},
    {name="Pet Sim X auto",          url="https://raw.githubusercontent.com/scripts-hub/scripts/main/psx.lua"},
    {name="Jailbreak hub",           url="https://raw.githubusercontent.com/scripts-hub/scripts/main/jailbreak.lua"},
    {name="Prison Life hub",         url="https://raw.githubusercontent.com/scripts-hub/scripts/main/prisonlife.lua"},
    {name="Adopt Me hub",            url="https://raw.githubusercontent.com/scripts-hub/scripts/main/adoptme.lua"},
    {name="Brookhaven hub",          url="https://raw.githubusercontent.com/scripts-hub/scripts/main/brookhaven.lua"},
    -- FPS / movement helpers
    {name="Universal Speed",         url="https://raw.githubusercontent.com/scripts-hub/scripts/main/speed.lua"},
    {name="Universal Fly",           url="https://raw.githubusercontent.com/scripts-hub/scripts/main/fly.lua"},
    {name="Universal Noclip",        url="https://raw.githubusercontent.com/scripts-hub/scripts/main/noclip.lua"},
    {name="Anti-AFK",                url="https://raw.githubusercontent.com/scripts-hub/scripts/main/antiafk.lua"},
    {name="Anti-Fling",              url="https://raw.githubusercontent.com/scripts-hub/scripts/main/antifling.lua"},
    -- Visual / fun
    {name="R6 morpher",              url="https://raw.githubusercontent.com/scripts-hub/scripts/main/r6.lua"},
    {name="Char re-skin",            url="https://raw.githubusercontent.com/scripts-hub/scripts/main/reskin.lua"},
    {name="Spinbot",                 url="https://raw.githubusercontent.com/scripts-hub/scripts/main/spinbot.lua"},
    -- Utility
    {name="FPS unlocker",            url="https://raw.githubusercontent.com/scripts-hub/scripts/main/fpsunlock.lua"},
    {name="Server hop",              url="https://raw.githubusercontent.com/scripts-hub/scripts/main/serverhop.lua"},
    {name="Rejoin",                  url="https://raw.githubusercontent.com/scripts-hub/scripts/main/rejoin.lua"},
    {name="Player teleport",         url="https://raw.githubusercontent.com/scripts-hub/scripts/main/playertp.lua"},
    {name="Click teleport",          url="https://raw.githubusercontent.com/scripts-hub/scripts/main/clicktp.lua"},
}

local state = {
    Favorites  = {},       -- {{name = ..., url = ...}}
    Autorun    = {},       -- {name = true}
    LastUrl    = "",
    LastSource = "",
}

local STORE_DIR = "ROGBLOX/scripthub"
local function storePath()
    return STORE_DIR .. "/" .. tostring(game.PlaceId) .. ".json"
end

local hasFS = type(writefile) == "function" and type(readfile) == "function"
              and type(isfile) == "function" and type(makefolder) == "function"

local function ensureFolder()
    if not hasFS then return false end
    for _, p in ipairs({"ROGBLOX", STORE_DIR}) do
        if isfolder and not isfolder(p) then pcall(makefolder, p) end
    end
    return true
end

local function seedCatalog()
    -- Populate favorites with the built-in CATALOG on first run if the
    -- user has no saved favorites yet. They can delete what they don't
    -- want.
    if #state.Favorites > 0 then return end
    for _, entry in ipairs(CATALOG) do
        table.insert(state.Favorites, {name = entry.name, url = entry.url})
    end
end

local function loadStore()
    if not hasFS then
        seedCatalog()
        return
    end
    if not (isfile and isfile(storePath())) then
        seedCatalog()
        return
    end
    local ok, raw = pcall(readfile, storePath())
    if not ok then seedCatalog(); return end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 then seedCatalog(); return end
    state.Favorites = data.favorites or {}
    state.Autorun   = data.autorun or {}
    if #state.Favorites == 0 then seedCatalog() end
end

local function saveStore()
    if not hasFS then return end
    ensureFolder()
    local data = {favorites = state.Favorites, autorun = state.Autorun}
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if not ok then return end
    pcall(writefile, storePath(), encoded)
end

local function runSource(source, label)
    if type(source) ~= "string" or source == "" then return false, "empty source" end
    local chunk, err = loadstring(source, "@" .. (label or "scripthub"))
    if not chunk then return false, err end
    local ok, runtimeErr = pcall(chunk)
    return ok, runtimeErr
end

local function runUrl(url, label)
    if type(url) ~= "string" or url == "" then return false, "empty url" end
    local ok, source = pcall(game.HttpGet, game, url)
    if not ok then return false, source end
    state.LastSource = source
    return runSource(source, label or url)
end

local function favoriteNames()
    local list = {}
    for _, fav in ipairs(state.Favorites) do table.insert(list, fav.name) end
    if #list == 0 then table.insert(list, "(none)") end
    return list
end

local function findFavorite(name)
    for _, fav in ipairs(state.Favorites) do
        if fav.name == name then return fav end
    end
    return nil
end

function M.Build(tab, ctx)
    local Notify = ctx.Notify
    loadStore()

    local runSec = tab:AddSection("Run a script")
    local pendingUrl, pendingName = "", ""
    runSec:AddTextBox("URL (HttpGet)", "https://example.com/script.lua", function(v) pendingUrl = v end)
    runSec:AddTextBox("Or paste raw source", "loadstring(...)()", function(v)
        state.LastSource = v
    end)
    runSec:AddButton("Run URL", function()
        local ok, err = runUrl(pendingUrl)
        Notify:Send("Scripthub", ok and ("Ran " .. pendingUrl) or ("Error: " .. tostring(err)), 4)
        state.LastUrl = pendingUrl
    end)
    runSec:AddButton("Run pasted source", function()
        local ok, err = runSource(state.LastSource, "paste")
        Notify:Send("Scripthub", ok and "Ran paste" or ("Error: " .. tostring(err)), 4)
    end)

    local favSec = tab:AddSection("Favorites (per game)")
    favSec:AddTextBox("Save as name", "my favorite", function(v) pendingName = v end)
    favSec:AddButton("Save current URL as favorite", function()
        if pendingUrl == "" or pendingName == "" then
            Notify:Send("Scripthub", "Need a URL + name", 3); return
        end
        -- replace if name exists
        for i, fav in ipairs(state.Favorites) do
            if fav.name == pendingName then table.remove(state.Favorites, i); break end
        end
        table.insert(state.Favorites, {name = pendingName, url = pendingUrl})
        saveStore()
        Notify:Send("Scripthub", "Saved '" .. pendingName .. "'", 3)
    end)

    local favPicked
    local dropdown = favSec:AddDropdown("Favorite", favoriteNames(), favoriteNames()[1], function(v) favPicked = v end)
    favSec:AddButton("Refresh list", function() dropdown:SetOptions(favoriteNames()) end)
    favSec:AddButton("Run favorite", function()
        local fav = findFavorite(favPicked)
        if not fav then return end
        local ok, err = runUrl(fav.url, fav.name)
        Notify:Send("Scripthub", ok and ("Ran " .. fav.name) or ("Error: " .. tostring(err)), 4)
    end)
    favSec:AddButton("Delete favorite", function()
        for i, fav in ipairs(state.Favorites) do
            if fav.name == favPicked then
                table.remove(state.Favorites, i)
                state.Autorun[favPicked] = nil
                saveStore()
                dropdown:SetOptions(favoriteNames())
                Notify:Send("Scripthub", "Deleted '" .. favPicked .. "'", 3)
                break
            end
        end
    end)

    local autoSec = tab:AddSection("Autorun on next inject")
    autoSec:AddButton("Toggle autorun for selected favorite", function()
        if not favPicked or favPicked == "(none)" then return end
        if state.Autorun[favPicked] then
            state.Autorun[favPicked] = nil
        else
            state.Autorun[favPicked] = true
        end
        saveStore()
        Notify:Send("Scripthub", "Autorun '" .. favPicked .. "' = " ..
            tostring(state.Autorun[favPicked] == true), 3)
    end)
    autoSec:AddButton("Run all autorun favorites now", function()
        local count = 0
        for _, fav in ipairs(state.Favorites) do
            if state.Autorun[fav.name] then
                pcall(runUrl, fav.url, fav.name)
                count = count + 1
            end
        end
        Notify:Send("Scripthub", "Ran " .. count .. " autorun scripts", 3)
    end)
    autoSec:AddButton("Clear all autorun flags", function()
        state.Autorun = {}; saveStore()
        Notify:Send("Scripthub", "Cleared autorun list", 3)
    end)

    -- Best-effort: kick off autoruns at boot (deferred so the rest of
    -- the hub finishes initializing first)
    task.defer(function()
        task.wait(2)
        for _, fav in ipairs(state.Favorites) do
            if state.Autorun[fav.name] then
                pcall(runUrl, fav.url, fav.name)
            end
        end
    end)
end

function M.Unload()
    for _, c in pairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
end

M.State = state
return M
