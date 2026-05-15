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

local function loadStore()
    if not hasFS then return end
    if not (isfile and isfile(storePath())) then return end
    local ok, raw = pcall(readfile, storePath())
    if not ok then return end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 then return end
    state.Favorites = data.favorites or {}
    state.Autorun   = data.autorun or {}
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
