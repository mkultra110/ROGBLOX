--[[
    SaveManager addon (Linoria pattern).

    Per-PlaceId named profiles, persisted as JSON on disk via the
    executor's filesystem API.

    Storage layout:
        ROGBLOX/
          settings/
            <placeId>/
              <profileName>.json
              autoload.txt        -- name of profile to load on startup

    Each registered "flag" is a {Get, Set} pair backed by a UI component.
    Save() serializes every flag's current value, Load() restores them.
]]

local HttpService = game:GetService("HttpService")

local M = {}

M.Folder       = "ROGBLOX/settings"
M.PlaceFolder  = nil
M.AutoloadPath = nil
M.Flags        = {}     -- [name] = {Get = fn, Set = fn(value), Default = ?}
M.Listeners    = {}
M.Ignore       = {}     -- [name] = true skips on save/load (e.g. theme keys)

-- ---------- Filesystem helpers ----------

local hasFS = type(writefile) == "function"
             and type(readfile)  == "function"
             and type(isfile)    == "function"
             and type(makefolder) == "function"

local function ensureFolders()
    if not hasFS then return false end
    for _, path in ipairs({"ROGBLOX", M.Folder, M.PlaceFolder}) do
        if isfolder and not isfolder(path) then
            pcall(makefolder, path)
        end
    end
    return true
end

local function init()
    M.PlaceFolder = M.Folder .. "/" .. tostring(game.PlaceId)
    M.AutoloadPath = M.PlaceFolder .. "/autoload.txt"
    ensureFolders()
end
init()

-- ---------- Flag registration ----------

function M.Register(name, accessors)
    -- accessors = {Get = function() return v end, Set = function(v) ... end, Default = v}
    M.Flags[name] = accessors
end

function M.Unregister(name)
    M.Flags[name] = nil
end

function M.SetIgnore(name, on)
    M.Ignore[name] = on and true or nil
end

-- ---------- Save / load ----------

function M.Snapshot()
    local out = {}
    for name, accessors in pairs(M.Flags) do
        if not M.Ignore[name] and accessors.Get then
            local ok, value = pcall(accessors.Get)
            if ok then
                -- Color3 -> {hex} for JSON round-trip
                if typeof(value) == "Color3" then
                    out[name] = {kind = "Color3", hex = string.format("#%02x%02x%02x",
                        math.floor(value.R * 255 + 0.5),
                        math.floor(value.G * 255 + 0.5),
                        math.floor(value.B * 255 + 0.5))}
                elseif typeof(value) == "EnumItem" then
                    out[name] = {kind = "Enum", value = tostring(value)}
                elseif type(value) == "table" then
                    out[name] = {kind = "table", value = value}
                else
                    out[name] = value
                end
            end
        end
    end
    return out
end

function M.Apply(data)
    if type(data) ~= "table" then return end
    for name, value in pairs(data) do
        local accessors = M.Flags[name]
        if accessors and accessors.Set then
            local v = value
            if type(value) == "table" and value.kind == "Color3" and value.hex then
                local r = tonumber(value.hex:sub(2, 3), 16) or 0
                local g = tonumber(value.hex:sub(4, 5), 16) or 0
                local b = tonumber(value.hex:sub(6, 7), 16) or 0
                v = Color3.fromRGB(r, g, b)
            elseif type(value) == "table" and value.kind == "table" then
                v = value.value
            end
            pcall(accessors.Set, v)
        end
    end
end

function M.Save(profileName)
    if not hasFS then return false, "no filesystem" end
    profileName = profileName or "default"
    ensureFolders()
    local path = M.PlaceFolder .. "/" .. profileName .. ".json"
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, M.Snapshot())
    if not ok then return false, encoded end
    local ok2, err = pcall(writefile, path, encoded)
    return ok2, err or path
end

function M.Load(profileName)
    if not hasFS then return false, "no filesystem" end
    profileName = profileName or "default"
    local path = M.PlaceFolder .. "/" .. profileName .. ".json"
    if not (isfile and isfile(path)) then return false, "no such profile" end
    local ok, raw = pcall(readfile, path)
    if not ok then return false, raw end
    local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 then return false, decoded end
    M.Apply(decoded)
    return true
end

function M.Delete(profileName)
    if not hasFS then return false end
    local path = M.PlaceFolder .. "/" .. profileName .. ".json"
    if isfile and isfile(path) and delfile then
        pcall(delfile, path)
        return true
    end
    return false
end

function M.List()
    local out = {}
    if not (hasFS and listfiles) then return out end
    local ok, files = pcall(listfiles, M.PlaceFolder)
    if not ok then return out end
    for _, file in ipairs(files) do
        local name = file:match("([^/\\]+)%.json$")
        if name then table.insert(out, name) end
    end
    table.sort(out)
    return out
end

-- ---------- Autoload ----------

function M.SetAutoload(profileName)
    if not hasFS then return end
    if profileName == nil or profileName == "" then
        if isfile and isfile(M.AutoloadPath) and delfile then pcall(delfile, M.AutoloadPath) end
        return
    end
    pcall(writefile, M.AutoloadPath, tostring(profileName))
end

function M.GetAutoload()
    if not hasFS then return nil end
    if isfile and isfile(M.AutoloadPath) then
        local ok, name = pcall(readfile, M.AutoloadPath)
        if ok then return name end
    end
    return nil
end

function M.AutoLoad()
    local name = M.GetAutoload()
    if name and name ~= "" then
        return M.Load(name)
    end
    return false
end

-- ---------- UI binding helpers ----------

-- Helper to wrap a UI component (with :Get / :Set) into a flag.
function M.BindComponent(name, component)
    M.Register(name, {
        Get = function() return component.Get and component:Get() or component:Get() end,
        Set = function(v) if component.Set then component:Set(v) end end,
    })
end

return M
