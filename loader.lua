--[[
    ROGBLOX loader
    Paste this entire file into your executor, or use:
        loadstring(game:HttpGet("https://raw.githubusercontent.com/mkultra110/rogblox/main/loader.lua"))()
]]

local BRANCH = "main"
local BASE = "https://raw.githubusercontent.com/mkultra110/rogblox/" .. BRANCH .. "/"

if _G.ROGBLOX_LOADED then
    warn("[ROGBLOX] Already loaded — unloading previous instance.")
    if _G.ROGBLOX and _G.ROGBLOX.Unload then
        pcall(_G.ROGBLOX.Unload)
    end
end

local ok, err = pcall(function()
    loadstring(game:HttpGet(BASE .. "src/main.lua"))()
end)

if not ok then
    warn("[ROGBLOX] Load failed: " .. tostring(err))
else
    _G.ROGBLOX_LOADED = true
end
