--[[
    Config persistence
    Stores per-game configs as JSON under workspace/ROGBLOX/<PlaceId>.json.
    Uses writefile/readfile if the executor supports them.
]]

local HttpService = game:GetService("HttpService")

local Config = {}

Config.FOLDER = "ROGBLOX"
Config._values = {}
Config._defaults = {}
Config._listeners = {}

local function has(fn)
    return type(_G[fn]) == "function" or type(rawget(getfenv(), fn)) == "function"
end

local hasFS = pcall(function()
    return writefile and readfile and isfile and makefolder
end) and writefile and readfile and isfile and makefolder

local function placePath()
    return Config.FOLDER .. "/" .. tostring(game.PlaceId) .. ".json"
end

local function ensureFolder()
    if hasFS and makefolder and not (isfolder and isfolder(Config.FOLDER)) then
        pcall(makefolder, Config.FOLDER)
    end
end

function Config.SetDefault(key, value)
    Config._defaults[key] = value
    if Config._values[key] == nil then
        Config._values[key] = value
    end
end

function Config.Get(key)
    if Config._values[key] ~= nil then return Config._values[key] end
    return Config._defaults[key]
end

function Config.Set(key, value)
    Config._values[key] = value
    local list = Config._listeners[key]
    if list then
        for _, fn in ipairs(list) do
            task.spawn(fn, value)
        end
    end
end

function Config.OnChange(key, fn)
    Config._listeners[key] = Config._listeners[key] or {}
    table.insert(Config._listeners[key], fn)
end

function Config.Save()
    if not hasFS then return false, "no filesystem" end
    ensureFolder()
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, Config._values)
    if not ok then return false, encoded end
    local ok2, err = pcall(writefile, placePath(), encoded)
    return ok2, err
end

function Config.Load()
    if not hasFS then return false, "no filesystem" end
    if not (isfile and isfile(placePath())) then return false, "no config" end
    local ok, raw = pcall(readfile, placePath())
    if not ok then return false, raw end
    local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 then return false, decoded end
    for k, v in pairs(decoded) do
        Config.Set(k, v)
    end
    return true
end

function Config.Reset()
    Config._values = {}
    for k, v in pairs(Config._defaults) do
        Config.Set(k, v)
    end
end

function Config.Export()
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, Config._values)
    return ok and encoded or "{}"
end

function Config.Import(str)
    local ok, decoded = pcall(HttpService.JSONDecode, HttpService, str)
    if not ok then return false, decoded end
    for k, v in pairs(decoded) do
        Config.Set(k, v)
    end
    return true
end

return Config
