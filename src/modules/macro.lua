--[[
    Macro recorder / playback.

    Records keyboard keypresses with timing, plays them back via the
    UNC input API (keypress / keyrelease). Useful for repeating combos,
    farming inputs, or running scripted action sequences without
    holding the keys manually.

    Limitations:
        - Only captures Roblox-window key events through
          UserInputService (no global hotkey grab).
        - Playback uses keypress/keyrelease if the executor exposes
          them; otherwise falls back to VirtualInputManager.

    Storage: keeps macros in memory + optional save via SaveManager.
]]

local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService          = game:GetService("RunService")

local M = {}

local conns = {}
local recording = false
local recordStart = 0
local currentRecord = {}     -- {{kind, key, at}, ...}
local saved = {}             -- [name] = {events = ..., totalSec = ...}
local pickedMacro = nil
local playing = false

local function pressKey(key, down)
    if not key then return end
    local code
    if typeof(key) == "EnumItem" then code = key end
    if not code then return end
    pcall(function()
        if down then
            if keypress then keypress(code)
            else VirtualInputManager:SendKeyEvent(true, code.Name, false, game) end
        else
            if keyrelease then keyrelease(code)
            else VirtualInputManager:SendKeyEvent(false, code.Name, false, game) end
        end
    end)
end

local function startRecording()
    if recording then return end
    recording = true
    currentRecord = {}
    recordStart = tick()
    conns.recDown = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            table.insert(currentRecord, {kind = "down", key = input.KeyCode, at = tick() - recordStart})
        end
    end)
    conns.recUp = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            table.insert(currentRecord, {kind = "up", key = input.KeyCode, at = tick() - recordStart})
        end
    end)
end

local function stopRecording()
    if not recording then return end
    recording = false
    if conns.recDown then conns.recDown:Disconnect(); conns.recDown = nil end
    if conns.recUp   then conns.recUp:Disconnect();   conns.recUp   = nil end
end

local function play(macro, opts)
    if not macro or #macro.events == 0 then return end
    opts = opts or {}
    local speed = opts.Speed or 1
    local loops = opts.Loops or 1
    playing = true
    task.spawn(function()
        for n = 1, loops do
            if not playing then break end
            local base = tick()
            for _, ev in ipairs(macro.events) do
                if not playing then break end
                local targetAt = base + (ev.at / speed)
                local now = tick()
                if targetAt > now then task.wait(targetAt - now) end
                pressKey(ev.key, ev.kind == "down")
            end
        end
        playing = false
    end)
end

local function macroNames()
    local out = {}
    for name in pairs(saved) do table.insert(out, name) end
    table.sort(out)
    if #out == 0 then table.insert(out, "(none)") end
    return out
end

function M.Build(tab, ctx)
    local Notify = ctx.Notify

    local rec = tab:AddSection("Record")
    rec:AddButton("Start recording", function()
        startRecording()
        Notify:Send("Macro", "Recording keystrokes...", 2)
    end)
    rec:AddButton("Stop recording", function()
        stopRecording()
        Notify:Send("Macro", "Stopped. " .. #currentRecord .. " events captured", 3)
    end)
    local pendingName = ""
    rec:AddTextBox("Save as name", "my-macro", function(v) pendingName = v end)
    local dropdown
    rec:AddButton("Save current", function()
        if pendingName == "" or #currentRecord == 0 then
            Notify:Send("Macro", "Need a name and recorded events", 3); return
        end
        local total = currentRecord[#currentRecord] and currentRecord[#currentRecord].at or 0
        saved[pendingName] = {events = currentRecord, totalSec = total}
        if dropdown then dropdown:SetOptions(macroNames()) end
        Notify:Send("Macro", string.format("Saved '%s' (%d events, %.1fs)",
            pendingName, #currentRecord, total), 3)
        currentRecord = {}
    end)

    local play_ = tab:AddSection("Playback")
    dropdown = play_:AddDropdown("Macro", macroNames(), macroNames()[1], function(v) pickedMacro = v end)
    play_:AddButton("Refresh", function() dropdown:SetOptions(macroNames()) end)
    local speed = 1.0
    local loops = 1
    play_:AddSlider("Speed", 0.1, 5, 1, function(v) speed = v end, {Decimals = 2})
    play_:AddSlider("Loops", 1, 50, 1, function(v) loops = math.floor(v) end)
    play_:AddButton("Play", function()
        local m = saved[pickedMacro]
        if not m then Notify:Send("Macro", "No macro selected", 2); return end
        play(m, {Speed = speed, Loops = loops})
        Notify:Send("Macro", "Playing " .. pickedMacro, 2)
    end)
    play_:AddButton("Stop", function()
        playing = false
    end)
    play_:AddButton("Delete selected", function()
        if pickedMacro and saved[pickedMacro] then
            saved[pickedMacro] = nil
            dropdown:SetOptions(macroNames())
            Notify:Send("Macro", "Deleted", 2)
        end
    end)
end

function M.Unload()
    stopRecording()
    playing = false
    for _, c in pairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
end

M.Saved = saved
return M
