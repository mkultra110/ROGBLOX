--[[
    Executor environment probe.

    Roblox executors implement the Unified Naming Convention (UNC) — and
    its 2025 successor sUNC — to varying degrees. This module checks
    which UNC functions are available in the current executor so the
    hub can degrade gracefully instead of erroring on a missing global.

    Usage:
        local Env = fetch("src/utils/env.lua")
        if Env.Has("hookmetamethod") then
            -- safe to install silent-aim
        end
        Env.Print()  -- prints a full conformance report to console

    Categories follow the UNC spec
    (github.com/unified-naming-convention/NamingStandard).
]]

local M = {}

local FEATURES = {
    Cache       = {"cache.invalidate", "cache.iscached", "cache.replace", "cloneref", "compareinstances"},
    Closure     = {"checkcaller", "clonefunction", "getcallingscript", "getscriptclosure",
                   "hookfunction", "iscclosure", "islclosure", "isexecutorclosure", "loadstring",
                   "newcclosure"},
    Console     = {"rconsoleclear", "rconsoleinput", "rconsoleprint", "rconsolesettitle"},
    Crypt       = {"crypt.base64encode", "crypt.base64decode", "crypt.encrypt", "crypt.decrypt",
                   "crypt.generatebytes", "crypt.generatekey", "crypt.hash"},
    Debug       = {"debug.getconstant", "debug.getconstants", "debug.getinfo", "debug.getproto",
                   "debug.getprotos", "debug.getstack", "debug.getupvalue", "debug.getupvalues",
                   "debug.setconstant", "debug.setstack", "debug.setupvalue"},
    Drawing     = {"Drawing", "Drawing.new", "Drawing.Fonts", "isrenderobj", "getrenderproperty",
                   "setrenderproperty", "cleardrawcache"},
    Filesystem  = {"readfile", "listfiles", "writefile", "makefolder", "appendfile",
                   "isfile", "isfolder", "delfolder", "delfile", "loadfile", "dofile"},
    Input       = {"isrbxactive", "mouse1click", "mouse1press", "mouse1release",
                   "mouse2click", "mouse2press", "mouse2release", "mousemoveabs", "mousemoverel",
                   "mousescroll", "keypress", "keyrelease"},
    Instances   = {"fireclickdetector", "fireproximityprompt", "firesignal", "firetouchinterest",
                   "getcallbackvalue", "getconnections", "getcustomasset", "gethiddenproperty",
                   "gethui", "getinstances", "getnilinstances", "isscriptable", "sethiddenproperty",
                   "setrbxclipboard", "setscriptable"},
    Metatable   = {"getrawmetatable", "hookmetamethod", "getnamecallmethod", "isreadonly",
                   "setrawmetatable", "setreadonly"},
    Misc        = {"identifyexecutor", "lz4compress", "lz4decompress", "messagebox", "queue_on_teleport",
                   "request", "setclipboard", "setfflag", "getfflag", "setfpscap"},
    Scripts     = {"getgc", "getgenv", "getloadedmodules", "getrenv", "getrunningscripts",
                   "getscriptbytecode", "getscripthash", "getscripts", "getsenv", "getthreadidentity",
                   "setthreadidentity"},
    WebSocket   = {"WebSocket", "WebSocket.connect"},
}

local function tryResolve(name)
    -- Direct global lookup
    local ok, v = pcall(function()
        local cur = getfenv(0)
        for part in name:gmatch("[^.]+") do
            cur = cur[part]
            if cur == nil then return nil end
        end
        return cur
    end)
    if ok and v ~= nil then return v end
    -- _G lookup
    ok, v = pcall(function()
        local cur = _G
        for part in name:gmatch("[^.]+") do
            cur = cur[part]
            if cur == nil then return nil end
        end
        return cur
    end)
    if ok then return v end
    return nil
end

M.Probe = {}
M.Categories = {}
M.Conformance = 0
M.Total = 0

local function probe()
    local found, total = 0, 0
    for category, names in pairs(FEATURES) do
        local catFound, catTotal = 0, #names
        for _, n in ipairs(names) do
            total = total + 1
            local v = tryResolve(n)
            local present = v ~= nil
            M.Probe[n] = present
            if present then
                found = found + 1
                catFound = catFound + 1
            end
        end
        M.Categories[category] = {found = catFound, total = catTotal}
    end
    M.Conformance = found / math.max(total, 1)
    M.Total = total
end

probe()

function M.Has(name)
    local v = M.Probe[name]
    if v ~= nil then return v end
    -- runtime lookup for things not in our manifest
    return tryResolve(name) ~= nil
end

function M.Name()
    if M.Has("identifyexecutor") then
        local ok, name, ver = pcall(identifyexecutor)
        if ok and name then return name, ver end
    end
    -- common executor-specific globals
    if syn then return "Synapse X" end
    if KRNL_LOADED or krnl then return "Krnl" end
    if fluxus then return "Fluxus" end
    if Krnl then return "Krnl" end
    if Wave then return "Wave" end
    if AWP then return "AWP" end
    return "Unknown executor"
end

function M.Summary()
    local lines = {}
    table.insert(lines, ("ROGBLOX env probe -- conformance %.1f%% (%d / %d UNC functions)")
        :format(M.Conformance * 100, M.Conformance * M.Total, M.Total))
    table.insert(lines, "executor: " .. tostring(M.Name()))
    for cat, c in pairs(M.Categories) do
        table.insert(lines, string.format("  %s: %d / %d", cat, c.found, c.total))
    end
    return table.concat(lines, "\n")
end

function M.Print()
    print(M.Summary())
end

-- short, named helpers that the rest of the hub will use
M.CanHookMeta     = M.Has("hookmetamethod") and M.Has("getrawmetatable") and M.Has("getnamecallmethod")
M.CanHookFn       = M.Has("hookfunction")
M.CanFileSystem   = M.Has("readfile") and M.Has("writefile") and M.Has("isfile")
M.CanDrawing      = M.Has("Drawing")
M.CanRequest      = M.Has("request") or M.Has("syn.request") or M.Has("http.request")
M.CanCheckCaller  = M.Has("checkcaller")
M.CanNewCClosure  = M.Has("newcclosure")
M.CanFFlag        = M.Has("setfflag") and M.Has("getfflag")
M.CanWebSocket    = M.Has("WebSocket")
M.CanLZ4          = M.Has("lz4compress") and M.Has("lz4decompress")

return M
