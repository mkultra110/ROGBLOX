--[[
    Game-specific feature templates.
    Detects the current PlaceId and exposes targeted features.
    Auto-loaded universal templates for the most popular Roblox games:
        - Da Hood
        - Blox Fruits
        - Arsenal
        - Phantom Forces
        - Murder Mystery 2 (MM2)
        - KAT
        - Strucid / Strucid-like FPS
        - Pet Simulator X
        - Adopt Me
        - Brookhaven
        - Jailbreak
    Each template registers its own UI section if its game is detected.
    Universal fallback features are always available.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local M = {}
local conns = {}
local alive = false

-- ---------- Place ID database ----------

-- Authoritative dispatch table sourced from Owl Hub's gameList.json plus
-- additions for popular 2024-2026 games. PlaceId -> canonical game name.
local GAMES = {
    -- Shooters
    [286090429]  = "Arsenal",
    [2788229376] = "Arsenal",
    [292439477]  = "Phantom Forces",
    [301549746]  = "Counter Blox",
    [1480424328] = "Counter Blox",
    [1869597719] = "Counter Blox",
    [3233893879] = "Bad Business",
    [2995662128] = "No Scope Sniping",
    [3527629287] = "BIG Paintball",
    [289565045]  = "Mad Paintball 2",
    [328028363]  = "Typical Colors 2",
    [983224898]  = "Wild Revolvers",
    [1101112213] = "Wild Revolvers",
    [1054737038] = "Wild Revolvers",
    -- Battle royale
    [1320174999] = "Island Royale",
    [3678591308] = "Island Royale",
    [3213501585] = "Island Royale",
    [3210442546] = "Island Royale",
    [2377868063] = "Strucid",
    [3606833500] = "Strucid",
    [2674164583] = "Strucid",
    [2609028954] = "Ruddev's Battle Royale",
    -- Round / knife / killing
    [142823291]  = "Murder Mystery 2",
    [621129760]  = "KAT (Knife Ability Test)",
    [3260590327] = "KAT (Knife Ability Test)",
    [137885680]  = "Zombie Rush",
    [3759927663] = "Zombie Strike",
    [3803533582] = "Zombie Strike",
    [628009815]  = "R2DA",
    [855499080]  = "Skywars",
    -- Open world / RPG
    [606849621]  = "Jailbreak",
    [155615604]  = "Prison Life",
    [402122991]  = "Redwood Prison",
    [1224212277] = "Da Hood",
    [920587237]  = "Adopt Me",
    [4924922222] = "Brookhaven",
    -- One Piece / anime
    [3237168]    = "One Piece Legendary",
    [3938392915] = "One Piece Legendary",
    [3970007519] = "One Piece Ultimate",
    [4050174018] = "One Punch Man IJ",
    [3400631762] = "JoJo Blox",
    [2281639237] = "Stands Online",
    -- Blox Fruits and clones
    [2753915549] = "Blox Fruits",
    [4442272183] = "Blox Fruits",
    -- Simulators
    [3255597014] = "Power Simulator",
    [3652625463] = "Lifting Simulator",
    [3623096087] = "Muscle Legend",
    [3956818381] = "Ninja Legends",
    [6284583030] = "Pet Simulator X",
    [4390380541] = "Rumble Quest",
    -- Misc shooters / FPS
    [443406476]  = "Project Lazarus",
    [1238482747] = "Bullet Hell",
    [2607077439] = "Operation Scorpion",
    [4456070441] = "Mayday",
    [688207762]  = "Color Craze",
    [2996424357] = "Esper Online",
    [2686500207] = "A Bizarre Day",
    -- Sports / RB World
    [2621503555] = "RB World 3",
    [2623233695] = "RB World 3",
    [2837610892] = "RB World 3",
    -- Sound / rhythm
    [2677609345] = "Sound Space",
    -- Misc
    [1899149341] = "Vehicle Tycoon",
    [261290060]  = "Terminal Railways",
    [4464235702] = "Infinity RPG 2",
    [2277629691] = "Infinity RPG 2",
    [2277630015] = "Infinity RPG 2",
    [2555870920] = "AceOfSpadez",
    [379614936]  = "Assassin",
    [866472074]  = "Assassin",
    [860428890]  = "Assassin",
    [2664771962] = "Assassin",
    [2664773504] = "Assassin",
    [3477768254] = "Squadron",
    [3501280158] = "Squadron",
}

local function currentGame()
    return GAMES[game.PlaceId] or "Unknown"
end

-- Category map — when the specific game has no bespoke template, light
-- up a category-wide one (FPS / battle royale / simulator / etc.).
local CATEGORIES = {
    -- shooters
    ["Arsenal"]          = "Shooter",
    ["Phantom Forces"]   = "Shooter",
    ["Counter Blox"]     = "Shooter",
    ["Bad Business"]     = "Shooter",
    ["No Scope Sniping"] = "Shooter",
    ["BIG Paintball"]    = "Shooter",
    ["Mad Paintball 2"]  = "Shooter",
    ["Typical Colors 2"] = "Shooter",
    ["Wild Revolvers"]   = "Shooter",
    ["Project Lazarus"]  = "Shooter",
    ["Bullet Hell"]      = "Shooter",
    ["Squadron"]         = "Shooter",
    -- battle royale
    ["Island Royale"]            = "BattleRoyale",
    ["Strucid"]                  = "BattleRoyale",
    ["Ruddev's Battle Royale"]   = "BattleRoyale",
    -- knife / round
    ["Murder Mystery 2"]         = "KnifeRound",
    ["KAT (Knife Ability Test)"] = "KnifeRound",
    ["Assassin"]                 = "KnifeRound",
    ["R2DA"]                     = "KnifeRound",
    ["Zombie Rush"]              = "KnifeRound",
    ["Zombie Strike"]            = "KnifeRound",
    -- open world
    ["Jailbreak"]      = "OpenWorld",
    ["Prison Life"]    = "OpenWorld",
    ["Redwood Prison"] = "OpenWorld",
    ["Da Hood"]        = "OpenWorld",
    -- simulators
    ["Power Simulator"]   = "Sim",
    ["Lifting Simulator"] = "Sim",
    ["Muscle Legend"]     = "Sim",
    ["Ninja Legends"]     = "Sim",
    ["Pet Simulator X"]   = "Sim",
    ["Vehicle Tycoon"]    = "Sim",
    ["Rumble Quest"]      = "Sim",
    -- anime / RPG
    ["Blox Fruits"]        = "AnimeRPG",
    ["One Piece Legendary"]= "AnimeRPG",
    ["One Piece Ultimate"] = "AnimeRPG",
    ["One Punch Man IJ"]   = "AnimeRPG",
    ["JoJo Blox"]          = "AnimeRPG",
    ["Stands Online"]      = "AnimeRPG",
    ["Infinity RPG 2"]     = "AnimeRPG",
    ["A Bizarre Day"]      = "AnimeRPG",
    -- chill
    ["Adopt Me"]    = "Chill",
    ["Brookhaven"]  = "Chill",
}

local function currentCategory()
    return CATEGORIES[currentGame()] or "Unknown"
end

-- ---------- Common helpers ----------

local function getChar()
    local lp = Players.LocalPlayer
    return lp and lp.Character
end

local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function findRemote(name)
    -- Search ReplicatedStorage for a RemoteEvent by name
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) and obj.Name == name then
            return obj
        end
    end
    return nil
end

local function fireRemote(name, ...)
    local r = findRemote(name)
    if r then
        if r:IsA("RemoteEvent") then r:FireServer(...) else r:InvokeServer(...) end
        return true
    end
    return false
end

-- ---------- Universal features ----------
-- These work in any game that exposes standard Humanoid behavior.

local universalState = {
    AutoRespawn = false,
    InstantReset = false,
    SuperJump   = false,
    SuperJumpPower = 200,
    AntiSlow    = false,
    AlwaysOnGround = false,
    InstantInteract = false,
}

local function buildUniversal(tab, ctx)
    local sec = tab:AddSection("Universal (works in most games)")
    sec:AddToggle("Auto-respawn on death", false, function(v) universalState.AutoRespawn = v end)
    sec:AddButton("Reset character", function()
        local hum = getHum()
        if hum then hum.Health = 0 end
    end)
    sec:AddToggle("Anti-slow (resists WalkSpeed reductions)", false, function(v) universalState.AntiSlow = v end)
    sec:AddToggle("Always-on-ground (ignore platform stand)", false, function(v) universalState.AlwaysOnGround = v end)
    sec:AddSlider("Super jump power", 50, 1000, 200, function(v) universalState.SuperJumpPower = v end)
    sec:AddToggle("Super jump", false, function(v) universalState.SuperJump = v end)

    -- continuous appliers
    conns.uniHB = RunService.Heartbeat:Connect(function()
        if universalState.AutoRespawn then
            local hum = getHum()
            if hum and hum.Health <= 0 then
                local lp = Players.LocalPlayer
                pcall(function() lp:LoadCharacter() end)
            end
        end
        if universalState.AntiSlow then
            local hum = getHum()
            if hum and hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
        end
        if universalState.AlwaysOnGround then
            local hum = getHum()
            if hum and hum:GetState() == Enum.HumanoidStateType.PlatformStanding then
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end
        if universalState.SuperJump then
            local hum = getHum()
            if hum then
                if hum.UseJumpPower then hum.JumpPower = universalState.SuperJumpPower
                else hum.JumpHeight = universalState.SuperJumpPower / 4 end
            end
        end
    end)
end

-- ---------- Game: Da Hood ----------

local function buildDaHood(tab)
    local sec = tab:AddSection("Da Hood")
    sec:AddLabel("Detected: Da Hood (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddButton("Drop money (held cash)", function()
        fireRemote("DropMoney")
    end)
    sec:AddButton("Grab nearby cash", function()
        local root = getRoot()
        if not root then return end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "Money" and obj:IsA("BasePart") then
                obj.CFrame = root.CFrame
            end
        end
    end)
    sec:AddToggle("Auto-grab dropped cash", false, function(v)
        if v then
            conns.dahoodGrab = RunService.Heartbeat:Connect(function()
                local root = getRoot()
                if not root then return end
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj.Name == "Money" and obj:IsA("BasePart") and (obj.Position - root.Position).Magnitude < 100 then
                        obj.CFrame = root.CFrame
                    end
                end
            end)
        else
            if conns.dahoodGrab then conns.dahoodGrab:Disconnect(); conns.dahoodGrab = nil end
        end
    end)
    sec:AddToggle("Punch aura (auto-punch nearby)", false, function(v)
        if v then
            conns.dahoodPunch = RunService.Heartbeat:Connect(function()
                local root = getRoot()
                if not root then return end
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= Players.LocalPlayer then
                        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                        if hrp and (hrp.Position - root.Position).Magnitude < 10 then
                            pcall(function() fireRemote("Punch") end)
                            break
                        end
                    end
                end
            end)
        else
            if conns.dahoodPunch then conns.dahoodPunch:Disconnect(); conns.dahoodPunch = nil end
        end
    end)
end

-- ---------- Game: Blox Fruits ----------

local function buildBloxFruits(tab)
    local sec = tab:AddSection("Blox Fruits")
    sec:AddLabel("Detected: Blox Fruits (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddButton("Collect all dropped fruits", function()
        local root = getRoot()
        if not root then return end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "Fruit" and obj:IsA("Tool") then
                obj.Parent = Players.LocalPlayer.Backpack
            end
        end
    end)
    sec:AddToggle("Auto-farm nearest enemy", false, function(v)
        if v then
            conns.bfFarm = RunService.Heartbeat:Connect(function()
                local root = getRoot()
                if not root then return end
                local best, bestDist
                for _, npc in ipairs(Workspace:GetDescendants()) do
                    if npc:IsA("Model") then
                        local hum = npc:FindFirstChildOfClass("Humanoid")
                        local hrp = npc:FindFirstChild("HumanoidRootPart")
                        if hum and hrp and hum.Health > 0 and not Players:GetPlayerFromCharacter(npc) then
                            local d = (hrp.Position - root.Position).Magnitude
                            if not bestDist or d < bestDist then best, bestDist = hrp, d end
                        end
                    end
                end
                if best then
                    root.CFrame = best.CFrame * CFrame.new(0, 0, 4)
                    local tool = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if tool then pcall(function() tool:Activate() end) end
                end
            end)
        else
            if conns.bfFarm then conns.bfFarm:Disconnect(); conns.bfFarm = nil end
        end
    end)
end

-- ---------- Game: Arsenal ----------

local function buildArsenal(tab)
    local sec = tab:AddSection("Arsenal")
    sec:AddLabel("Detected: Arsenal (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Infinite ammo (client-side)", false, function(v)
        if v then
            conns.arsenalAmmo = RunService.Heartbeat:Connect(function()
                local char = getChar()
                if not char then return end
                local tool = char:FindFirstChildOfClass("Tool")
                if not tool then return end
                local ammo = tool:FindFirstChild("Ammo")
                if ammo then ammo.Value = 999 end
                local mag = tool:FindFirstChild("Mag")
                if mag then mag.Value = 999 end
            end)
        else
            if conns.arsenalAmmo then conns.arsenalAmmo:Disconnect(); conns.arsenalAmmo = nil end
        end
    end)
    sec:AddToggle("No recoil (client camera)", false, function(v)
        if v then
            conns.arsenalRecoil = RunService.RenderStepped:Connect(function()
                local cam = Workspace.CurrentCamera
                if cam then cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, 0) end
            end)
        else
            if conns.arsenalRecoil then conns.arsenalRecoil:Disconnect(); conns.arsenalRecoil = nil end
        end
    end)
end

-- ---------- Game: Phantom Forces ----------

local function buildPhantomForces(tab)
    local sec = tab:AddSection("Phantom Forces")
    sec:AddLabel("Detected: Phantom Forces (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Hold-shoot (auto-fire on aim)", false, function(v)
        if v then
            conns.pfHoldShoot = RunService.Heartbeat:Connect(function()
                pcall(function()
                    if mouse1press and mouse1release then mouse1press(); task.wait(); mouse1release() end
                end)
            end)
        else
            if conns.pfHoldShoot then conns.pfHoldShoot:Disconnect(); conns.pfHoldShoot = nil end
        end
    end)
    sec:AddSlider("Fire delay (ms)", 10, 500, 60, function(v)
        -- delay used by hold-shoot loop, future use
    end)
end

-- ---------- Game: MM2 ----------

local function buildMM2(tab)
    local sec = tab:AddSection("Murder Mystery 2")
    sec:AddLabel("Detected: MM2 (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddButton("Reveal murderer + sheriff", function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Players.LocalPlayer and plr.Backpack then
                local hasKnife = plr.Backpack:FindFirstChild("Knife") or
                                 (plr.Character and plr.Character:FindFirstChild("Knife"))
                local hasGun   = plr.Backpack:FindFirstChild("Gun") or
                                 (plr.Character and plr.Character:FindFirstChild("Gun"))
                if hasKnife then
                    print("[MM2] Murderer: " .. plr.Name)
                end
                if hasGun then
                    print("[MM2] Sheriff: " .. plr.Name)
                end
            end
        end
    end)
    sec:AddButton("Teleport to gun (when dropped)", function()
        local root = getRoot()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "GunDrop" or obj.Name == "Gun" then
                if obj:IsA("BasePart") and root then
                    root.CFrame = obj.CFrame + Vector3.new(0, 3, 0)
                    return
                end
            end
        end
    end)
end

-- ---------- Game: KAT ----------

local function buildKAT(tab)
    local sec = tab:AddSection("KAT")
    sec:AddLabel("Detected: KAT (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Auto-parry knives", false, function(v)
        if v then
            conns.katParry = RunService.Heartbeat:Connect(function()
                local root = getRoot()
                if not root then return end
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj.Name == "Knife" and obj:IsA("BasePart") then
                        local d = (obj.Position - root.Position).Magnitude
                        if d < 18 then
                            VirtualInputManager:SendKeyEvent(true, "F", false, game)
                            task.wait(0.05)
                            VirtualInputManager:SendKeyEvent(false, "F", false, game)
                        end
                    end
                end
            end)
        else
            if conns.katParry then conns.katParry:Disconnect(); conns.katParry = nil end
        end
    end)
end

-- ---------- Game: Jailbreak ----------

local function buildJailbreak(tab)
    local sec = tab:AddSection("Jailbreak")
    sec:AddLabel("Detected: Jailbreak (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddButton("Teleport to bank", function()
        local root = getRoot()
        local bank = Workspace:FindFirstChild("Banks") and Workspace.Banks:FindFirstChild("Bank")
        if root and bank then
            local p = bank:FindFirstChild("Door") or bank.PrimaryPart
            if p then root.CFrame = p.CFrame + Vector3.new(0, 5, 0) end
        end
    end)
    sec:AddButton("Teleport to jewelry", function()
        local root = getRoot()
        local jew = Workspace:FindFirstChild("Jewelrys") and Workspace.Jewelrys:FindFirstChild("Jewelry")
        if root and jew then
            local p = jew:FindFirstChild("Door") or jew.PrimaryPart
            if p then root.CFrame = p.CFrame + Vector3.new(0, 5, 0) end
        end
    end)
end

-- ---------- Game: Pet Sim X ----------

local function buildPetSimX(tab)
    local sec = tab:AddSection("Pet Simulator X")
    sec:AddLabel("Detected: PSX (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Auto-farm coins (mash)", false, function(v)
        if v then
            conns.psxCoins = RunService.Heartbeat:Connect(function()
                pcall(function()
                    if mouse1press and mouse1release then mouse1press(); mouse1release() end
                end)
            end)
        else
            if conns.psxCoins then conns.psxCoins:Disconnect(); conns.psxCoins = nil end
        end
    end)
end

-- ---------- Game: Counter Blox ----------

local function buildCounterBlox(tab)
    local sec = tab:AddSection("Counter Blox")
    sec:AddLabel("Detected: Counter Blox (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Auto-fire on lock", false, function(v)
        if v then
            conns.cbFire = RunService.Heartbeat:Connect(function()
                pcall(function() if mouse1click then mouse1click() end end)
            end)
        else
            if conns.cbFire then conns.cbFire:Disconnect(); conns.cbFire = nil end
        end
    end)
    sec:AddToggle("No recoil (best-effort)", false, function(v)
        if v then
            conns.cbRecoil = RunService.RenderStepped:Connect(function()
                local lp = Players.LocalPlayer
                local char = lp and lp.Character
                local tool = char and char:FindFirstChildOfClass("Tool")
                if tool then
                    local recoil = tool:FindFirstChild("Recoil")
                    if recoil and recoil:IsA("NumberValue") then recoil.Value = 0 end
                end
            end)
        else
            if conns.cbRecoil then conns.cbRecoil:Disconnect(); conns.cbRecoil = nil end
        end
    end)
end

-- ---------- Game: Strucid ----------

local function buildStrucid(tab)
    local sec = tab:AddSection("Strucid")
    sec:AddLabel("Detected: Strucid (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddButton("Collect all materials", function()
        local root = getRoot()
        if not root then return end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "Material" or obj.Name == "Mat" then
                if obj:IsA("BasePart") then obj.CFrame = root.CFrame end
            end
        end
    end)
    sec:AddLabel("Auto-build wall: not implemented in this version (varies per Strucid build).")
end

-- ---------- Game: Bad Business ----------

local function buildBadBusiness(tab)
    local sec = tab:AddSection("Bad Business")
    sec:AddLabel("Detected: Bad Business (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Hold to fire while aiming", false, function(v)
        if v then
            conns.bbFire = RunService.Heartbeat:Connect(function()
                pcall(function() if mouse1press then mouse1press(); task.wait(0.05); mouse1release() end end)
            end)
        else
            if conns.bbFire then conns.bbFire:Disconnect(); conns.bbFire = nil end
        end
    end)
end

-- ---------- Game: Prison Life ----------

local function buildPrisonLife(tab)
    local sec = tab:AddSection("Prison Life")
    sec:AddLabel("Detected: Prison Life (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddButton("Take all guns (prison armory)", function()
        local lp = Players.LocalPlayer
        local root = getRoot()
        if not root then return end
        for _, item in ipairs(Workspace:GetDescendants()) do
            if item:IsA("Tool") then
                local handle = item:FindFirstChild("Handle")
                if handle then handle.CFrame = root.CFrame end
            end
        end
    end)
    sec:AddButton("Open all doors / cells", function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name:lower():find("door") and obj:IsA("BasePart") then
                pcall(function() obj.CanCollide = false; obj.Transparency = 0.8 end)
            end
        end
    end)
    sec:AddButton("Teleport to gun shop", function()
        local root = getRoot()
        local gs = Workspace:FindFirstChild("Gun Shop", true) or Workspace:FindFirstChild("GunShop", true)
        if root and gs then
            local p = gs:IsA("BasePart") and gs or gs:FindFirstChildWhichIsA("BasePart")
            if p then root.CFrame = p.CFrame + Vector3.new(0, 4, 0) end
        end
    end)
end

-- ---------- Game: Adopt Me ----------

local function buildAdoptMe(tab)
    local sec = tab:AddSection("Adopt Me")
    sec:AddLabel("Detected: Adopt Me (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddSlider("Walkspeed", 16, 200, 30, function(v)
        local hum = getHum(); if hum then hum.WalkSpeed = v end
    end)
    sec:AddButton("Teleport to next quest marker", function()
        local root = getRoot()
        if not root then return end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name:find("Quest") and obj:IsA("BasePart") then
                root.CFrame = obj.CFrame + Vector3.new(0, 3, 0); return
            end
        end
    end)
end

-- ---------- Game: Brookhaven ----------

local function buildBrookhaven(tab)
    local sec = tab:AddSection("Brookhaven")
    sec:AddLabel("Detected: Brookhaven (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddSlider("Walkspeed", 16, 200, 30, function(v)
        local hum = getHum(); if hum then hum.WalkSpeed = v end
    end)
    sec:AddSlider("Jump power", 50, 500, 100, function(v)
        local hum = getHum()
        if hum then
            if hum.UseJumpPower then hum.JumpPower = v
            else hum.JumpHeight = v / 4 end
        end
    end)
    sec:AddButton("Snap to nearest car", function()
        local root = getRoot()
        if not root then return end
        local best, bestDist
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name:lower():find("vehicle") or obj.Name:lower():find("car") then
                local p = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if p then
                    local d = (p.Position - root.Position).Magnitude
                    if not bestDist or d < bestDist then best, bestDist = p, d end
                end
            end
        end
        if best then root.CFrame = best.CFrame + Vector3.new(0, 5, 0) end
    end)
end

-- ---------- Game: Island Royale ----------

local function buildIslandRoyale(tab)
    local sec = tab:AddSection("Island Royale")
    sec:AddLabel("Detected: Island Royale (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddSlider("Walkspeed", 16, 100, 40, function(v)
        local hum = getHum(); if hum then hum.WalkSpeed = v end
    end)
    sec:AddButton("Grab all dropped loot in radius", function()
        local root = getRoot(); if not root then return end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Tool") then
                local h = obj:FindFirstChild("Handle")
                if h and (h.Position - root.Position).Magnitude < 150 then
                    h.CFrame = root.CFrame
                end
            end
        end
    end)
    sec:AddToggle("Auto-loot crates", false, function(v)
        if v then
            conns.irLoot = RunService.Heartbeat:Connect(function()
                local root = getRoot(); if not root then return end
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj.Name:lower():find("crate") and obj:IsA("BasePart") then
                        local d = (obj.Position - root.Position).Magnitude
                        if d < 60 then obj.CFrame = root.CFrame end
                    end
                end
            end)
        else
            if conns.irLoot then conns.irLoot:Disconnect(); conns.irLoot = nil end
        end
    end)
end

-- ---------- Game: BIG Paintball ----------

local function buildBigPaintball(tab)
    local sec = tab:AddSection("BIG Paintball")
    sec:AddLabel("Detected: BIG Paintball (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Auto-spray", false, function(v)
        if v then
            conns.bpSpray = RunService.Heartbeat:Connect(function()
                pcall(function() if mouse1press and mouse1release then mouse1press(); task.wait(); mouse1release() end end)
            end)
        else
            if conns.bpSpray then conns.bpSpray:Disconnect(); conns.bpSpray = nil end
        end
    end)
end

-- ---------- Game: Mad Paintball 2 ----------

local function buildMadPaintball2(tab)
    local sec = tab:AddSection("Mad Paintball 2")
    sec:AddLabel("Detected: Mad Paintball 2 (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddSlider("Walkspeed", 16, 80, 30, function(v)
        local hum = getHum(); if hum then hum.WalkSpeed = v end
    end)
    sec:AddToggle("Auto-fire", false, function(v)
        if v then
            conns.mp2Fire = RunService.Heartbeat:Connect(function()
                pcall(function() if mouse1click then mouse1click() end end)
            end)
        else
            if conns.mp2Fire then conns.mp2Fire:Disconnect(); conns.mp2Fire = nil end
        end
    end)
end

-- ---------- Game: Project Lazarus ----------

local function buildProjectLazarus(tab)
    local sec = tab:AddSection("Project Lazarus")
    sec:AddLabel("Detected: Project Lazarus (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Infinite ammo (client value)", false, function(v)
        if v then
            conns.plAmmo = RunService.Heartbeat:Connect(function()
                local char = getChar()
                local tool = char and char:FindFirstChildOfClass("Tool")
                if tool then
                    for _, ch in ipairs(tool:GetDescendants()) do
                        if ch:IsA("NumberValue") and (ch.Name:lower():find("ammo") or ch.Name:lower():find("mag")) then
                            ch.Value = 999
                        end
                    end
                end
            end)
        else
            if conns.plAmmo then conns.plAmmo:Disconnect(); conns.plAmmo = nil end
        end
    end)
end

-- ---------- Game: Power / Lifting / Muscle / Ninja sims ----------

local function buildStatSim(tab, name)
    local sec = tab:AddSection(name)
    sec:AddLabel("Detected: " .. name .. " (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Auto-mash mouse1 (stat farm)", false, function(v)
        if v then
            conns.statMash = RunService.Heartbeat:Connect(function()
                pcall(function() if mouse1click then mouse1click() end end)
            end)
        else
            if conns.statMash then conns.statMash:Disconnect(); conns.statMash = nil end
        end
    end)
    sec:AddToggle("Auto-rebirth check (every 30s)", false, function(v)
        if v then
            conns.statRebirth = task.spawn(function()
                while alive do
                    task.wait(30)
                    pcall(function() fireRemote("Rebirth") end)
                end
            end)
        end
    end)
end
local function buildPowerSim(tab)    buildStatSim(tab, "Power Simulator")    end
local function buildLiftingSim(tab)  buildStatSim(tab, "Lifting Simulator")  end
local function buildMuscleLegend(tab)buildStatSim(tab, "Muscle Legend")      end
local function buildNinjaLegends(tab)buildStatSim(tab, "Ninja Legends")      end

-- ---------- Game: One Piece / JoJo / anime ----------

local function buildAnimeFarm(tab, name)
    local sec = tab:AddSection(name)
    sec:AddLabel("Detected: " .. name .. " (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Auto-attack nearest enemy", false, function(v)
        if v then
            conns.afAttack = RunService.Heartbeat:Connect(function()
                local root = getRoot(); if not root then return end
                local best, bestDist
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("Humanoid") and obj.Health > 0 then
                        local hrp = obj.Parent and obj.Parent:FindFirstChild("HumanoidRootPart")
                        local plr = obj.Parent and Players:GetPlayerFromCharacter(obj.Parent)
                        if hrp and not plr then
                            local d = (hrp.Position - root.Position).Magnitude
                            if not bestDist or d < bestDist then best, bestDist = hrp, d end
                        end
                    end
                end
                if best and (best.Position - root.Position).Magnitude < 200 then
                    root.CFrame = best.CFrame * CFrame.new(0, 0, 3)
                    local char = getChar()
                    if char then
                        for _, t in ipairs(char:GetChildren()) do
                            if t:IsA("Tool") then pcall(function() t:Activate() end) end
                        end
                    end
                end
            end)
        else
            if conns.afAttack then conns.afAttack:Disconnect(); conns.afAttack = nil end
        end
    end)
end
local function buildOnePieceLegendary(tab) buildAnimeFarm(tab, "One Piece Legendary") end
local function buildOnePieceUltimate(tab)  buildAnimeFarm(tab, "One Piece Ultimate")  end
local function buildOnePunchManIJ(tab)     buildAnimeFarm(tab, "One Punch Man IJ")    end
local function buildJoJoBlox(tab)          buildAnimeFarm(tab, "JoJo Blox")           end
local function buildStandsOnline(tab)      buildAnimeFarm(tab, "Stands Online")       end
local function buildABizarreDay(tab)       buildAnimeFarm(tab, "A Bizarre Day")       end

-- ---------- Game: R2DA / Zombie Rush / Zombie Strike ----------

local function buildZombieGame(tab, name)
    local sec = tab:AddSection(name)
    sec:AddLabel("Detected: " .. name .. " (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Auto-shoot zombies", false, function(v)
        if v then
            conns.zomShoot = RunService.Heartbeat:Connect(function()
                pcall(function() if mouse1click then mouse1click() end end)
            end)
        else
            if conns.zomShoot then conns.zomShoot:Disconnect(); conns.zomShoot = nil end
        end
    end)
    sec:AddSlider("Walkspeed", 16, 80, 25, function(v)
        local hum = getHum(); if hum then hum.WalkSpeed = v end
    end)
end
local function buildR2DA(tab)         buildZombieGame(tab, "R2DA")         end
local function buildZombieRush(tab)   buildZombieGame(tab, "Zombie Rush")  end
local function buildZombieStrike(tab) buildZombieGame(tab, "Zombie Strike") end

-- ---------- Game: Vehicle Tycoon ----------

local function buildVehicleTycoon(tab)
    local sec = tab:AddSection("Vehicle Tycoon")
    sec:AddLabel("Detected: Vehicle Tycoon (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Auto-collect droppers", false, function(v)
        if v then
            conns.vtDrop = RunService.Heartbeat:Connect(function()
                local root = getRoot(); if not root then return end
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj.Name:lower():find("part") and obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
                        local d = (obj.Position - root.Position).Magnitude
                        if d < 80 then obj.CFrame = root.CFrame end
                    end
                end
            end)
        else
            if conns.vtDrop then conns.vtDrop:Disconnect(); conns.vtDrop = nil end
        end
    end)
end

-- ---------- Game: Sound Space ----------

local function buildSoundSpace(tab)
    local sec = tab:AddSection("Sound Space")
    sec:AddLabel("Detected: Sound Space (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddLabel("Auto-play: not implemented (varies per version).")
    sec:AddSlider("Cursor sensitivity tweak", 0.1, 5, 1, function(v) end, {Decimals = 2})
end

-- ---------- Game: Mayday ----------

local function buildMayday(tab)
    local sec = tab:AddSection("Mayday")
    sec:AddLabel("Detected: Mayday (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Hold-fire", false, function(v)
        if v then
            conns.mdFire = RunService.Heartbeat:Connect(function()
                pcall(function() if mouse1press and mouse1release then mouse1press(); mouse1release() end end)
            end)
        else
            if conns.mdFire then conns.mdFire:Disconnect(); conns.mdFire = nil end
        end
    end)
end

-- ---------- Game: Squadron ----------

local function buildSquadron(tab)
    local sec = tab:AddSection("Squadron")
    sec:AddLabel("Detected: Squadron (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Auto-fire", false, function(v)
        if v then
            conns.sqFire = RunService.Heartbeat:Connect(function()
                pcall(function() if mouse1click then mouse1click() end end)
            end)
        else
            if conns.sqFire then conns.sqFire:Disconnect(); conns.sqFire = nil end
        end
    end)
end

-- ---------- Game: Redwood Prison ----------

local function buildRedwoodPrison(tab)
    local sec = tab:AddSection("Redwood Prison")
    sec:AddLabel("Detected: Redwood Prison (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddSlider("Walkspeed", 16, 100, 30, function(v)
        local hum = getHum(); if hum then hum.WalkSpeed = v end
    end)
    sec:AddButton("Open all cells", function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name:lower():find("cell") and obj:IsA("BasePart") then
                pcall(function() obj.CanCollide = false; obj.Transparency = 0.7 end)
            end
        end
    end)
end

-- ---------- Game: Wild Revolvers / No-Scope Sniping / Bullet Hell ----------

local function buildGenericShooter(tab, name)
    local sec = tab:AddSection(name)
    sec:AddLabel("Detected: " .. name .. " (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Auto-fire", false, function(v)
        if v then
            conns.gsFire = RunService.Heartbeat:Connect(function()
                pcall(function() if mouse1click then mouse1click() end end)
            end)
        else
            if conns.gsFire then conns.gsFire:Disconnect(); conns.gsFire = nil end
        end
    end)
    sec:AddSlider("Walkspeed", 16, 80, 25, function(v)
        local hum = getHum(); if hum then hum.WalkSpeed = v end
    end)
end
local function buildWildRevolvers(tab)   buildGenericShooter(tab, "Wild Revolvers")    end
local function buildNoScopeSniping(tab)  buildGenericShooter(tab, "No Scope Sniping")  end
local function buildBulletHell(tab)      buildGenericShooter(tab, "Bullet Hell")       end
local function buildOperationScorpion(tab) buildGenericShooter(tab, "Operation Scorpion") end

-- ---------- Game: Typical Colors 2 ----------

local function buildTypicalColors2(tab)
    local sec = tab:AddSection("Typical Colors 2")
    sec:AddLabel("Detected: TC2 (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Hold-fire", false, function(v)
        if v then
            conns.tc2Fire = RunService.Heartbeat:Connect(function()
                pcall(function() if mouse1press and mouse1release then mouse1press(); mouse1release() end end)
            end)
        else
            if conns.tc2Fire then conns.tc2Fire:Disconnect(); conns.tc2Fire = nil end
        end
    end)
end

-- ---------- Game: Skywars ----------

local function buildSkywars(tab)
    local sec = tab:AddSection("Skywars")
    sec:AddLabel("Detected: Skywars (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddSlider("Walkspeed", 16, 80, 28, function(v)
        local hum = getHum(); if hum then hum.WalkSpeed = v end
    end)
    sec:AddButton("Pull nearby chests", function()
        local root = getRoot(); if not root then return end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name:lower():find("chest") and obj:IsA("BasePart") then
                local d = (obj.Position - root.Position).Magnitude
                if d < 100 then obj.CFrame = root.CFrame end
            end
        end
    end)
end

-- ---------- Game: Infinity RPG 2 ----------

local function buildInfinityRpg2(tab)
    local sec = tab:AddSection("Infinity RPG 2")
    sec:AddLabel("Detected: Infinity RPG 2 (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Auto-attack nearest mob", false, function(v)
        if v then
            buildAnimeFarm(tab, "(auto)")
        end
    end)
end

-- ---------- Game: AceOfSpadez ----------

local function buildAceOfSpadez(tab)
    local sec = tab:AddSection("AceOfSpadez")
    sec:AddLabel("Detected: AceOfSpadez (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Hold-fire", false, function(v)
        if v then
            conns.aosFire = RunService.Heartbeat:Connect(function()
                pcall(function() if mouse1press and mouse1release then mouse1press(); mouse1release() end end)
            end)
        else
            if conns.aosFire then conns.aosFire:Disconnect(); conns.aosFire = nil end
        end
    end)
end

-- ---------- Game: Assassin ----------

local function buildAssassinGame(tab)
    local sec = tab:AddSection("Assassin")
    sec:AddLabel("Detected: Assassin (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddButton("Reveal target", function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Players.LocalPlayer then
                local char = plr.Character
                local knife = char and (char:FindFirstChild("Knife") or char:FindFirstChild("KnifeModel"))
                if knife then print("[Assassin] target with knife: " .. plr.Name) end
            end
        end
    end)
end

-- ---------- Game: RB World 3 ----------

local function buildRBWorld3(tab)
    local sec = tab:AddSection("RB World 3")
    sec:AddLabel("Detected: RB World 3 (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddSlider("Walkspeed", 16, 60, 22, function(v)
        local hum = getHum(); if hum then hum.WalkSpeed = v end
    end)
end

-- ---------- Game: Color Craze ----------

local function buildColorCraze(tab)
    local sec = tab:AddSection("Color Craze")
    sec:AddLabel("Detected: Color Craze (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddSlider("Walkspeed", 16, 100, 32, function(v)
        local hum = getHum(); if hum then hum.WalkSpeed = v end
    end)
end

-- ---------- Game: Esper Online ----------

local function buildEsperOnline(tab)
    local sec = tab:AddSection("Esper Online")
    sec:AddLabel("Detected: Esper Online (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddSlider("Walkspeed", 16, 80, 24, function(v)
        local hum = getHum(); if hum then hum.WalkSpeed = v end
    end)
end

-- ---------- Game: Terminal Railways ----------

local function buildTerminalRailways(tab)
    local sec = tab:AddSection("Terminal Railways")
    sec:AddLabel("Detected: Terminal Railways (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddSlider("Walkspeed", 16, 80, 24, function(v)
        local hum = getHum(); if hum then hum.WalkSpeed = v end
    end)
end

-- ---------- Game: Rumble Quest ----------

local function buildRumbleQuest(tab)
    local sec = tab:AddSection("Rumble Quest")
    sec:AddLabel("Detected: Rumble Quest (PlaceId " .. tostring(game.PlaceId) .. ")")
    sec:AddToggle("Auto-attack nearest mob", false, function(v)
        if v then
            buildAnimeFarm(tab, "(rumble-auto)")
        end
    end)
end

-- ---------- Category-wide builders ----------
-- Stand-in features that work for an entire game category.

local function buildShooterCategory(tab)
    local sec = tab:AddSection("Shooter (category)")
    sec:AddLabel("Generic FPS helpers (aimbot tab has the real targeting).")
    sec:AddToggle("Crosshair always centered (lock mouse to center)", false, function(v)
        if v then
            conns.crosshair = RunService.RenderStepped:Connect(function()
                local cam = Workspace.CurrentCamera
                if cam then
                    -- placeholder — most shooters already lock the cursor
                end
            end)
        else
            if conns.crosshair then conns.crosshair:Disconnect(); conns.crosshair = nil end
        end
    end)
    sec:AddButton("Pick up all dropped weapons (try)", function()
        local root = getRoot()
        if not root then return end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Tool") then
                local handle = obj:FindFirstChild("Handle")
                if handle then handle.CFrame = root.CFrame end
            end
        end
    end)
end

local function buildBattleRoyaleCategory(tab)
    local sec = tab:AddSection("Battle Royale (category)")
    sec:AddButton("Collect all loot in range", function()
        local root = getRoot()
        if not root then return end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Tool") or (obj:IsA("BasePart") and (
                obj.Name:lower():find("loot") or obj.Name:lower():find("chest") or
                obj.Name:lower():find("ammo")
            )) then
                local part = obj:IsA("Tool") and obj:FindFirstChild("Handle") or obj
                if part and part:IsA("BasePart") and (part.Position - root.Position).Magnitude < 200 then
                    part.CFrame = root.CFrame
                end
            end
        end
    end)
end

local function buildKnifeRoundCategory(tab)
    local sec = tab:AddSection("Knife / Round (category)")
    sec:AddButton("Reveal role-bearers (knife/gun owners)", function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= Players.LocalPlayer then
                local hasKnife = (plr.Backpack and plr.Backpack:FindFirstChild("Knife"))
                              or (plr.Character and plr.Character:FindFirstChild("Knife"))
                local hasGun   = (plr.Backpack and plr.Backpack:FindFirstChild("Gun"))
                              or (plr.Character and plr.Character:FindFirstChild("Gun"))
                if hasKnife then print("[role] knife: " .. plr.Name) end
                if hasGun   then print("[role] gun:   " .. plr.Name) end
            end
        end
    end)
    sec:AddToggle("Auto-pickup drops within range", false, function(v)
        if v then
            conns.krPickup = RunService.Heartbeat:Connect(function()
                local root = getRoot()
                if not root then return end
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if (obj.Name == "GunDrop" or obj.Name == "Knife" or obj.Name == "Gun")
                       and obj:IsA("BasePart")
                       and (obj.Position - root.Position).Magnitude < 30 then
                        obj.CFrame = root.CFrame
                    end
                end
            end)
        else
            if conns.krPickup then conns.krPickup:Disconnect(); conns.krPickup = nil end
        end
    end)
end

local function buildOpenWorldCategory(tab)
    local sec = tab:AddSection("Open World (category)")
    sec:AddButton("Print named landmarks", function()
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:IsA("Folder") or child:IsA("Model") then
                print("[map] " .. child.Name)
            end
        end
    end)
    sec:AddSlider("Walkspeed", 16, 300, 50, function(v)
        local hum = getHum(); if hum then hum.WalkSpeed = v end
    end)
end

local function buildSimCategory(tab)
    local sec = tab:AddSection("Simulator (category)")
    sec:AddToggle("Auto-mash mouse1 (auto-click farm)", false, function(v)
        if v then
            conns.simMash = RunService.Heartbeat:Connect(function()
                pcall(function()
                    if mouse1click then mouse1click()
                    elseif mouse1press and mouse1release then mouse1press(); mouse1release() end
                end)
            end)
        else
            if conns.simMash then conns.simMash:Disconnect(); conns.simMash = nil end
        end
    end)
    sec:AddToggle("Anti-idle (click periodically)", false, function(v)
        if v then
            conns.simIdle = task.spawn(function()
                while alive do
                    task.wait(60)
                    pcall(function() if mouse1click then mouse1click() end end)
                end
            end)
        end
    end)
end

local function buildAnimeRPGCategory(tab)
    local sec = tab:AddSection("Anime RPG (category)")
    sec:AddToggle("Auto-attack equipped tool", false, function(v)
        if v then
            conns.animeAttack = RunService.Heartbeat:Connect(function()
                local char = getChar()
                if not char then return end
                for _, t in ipairs(char:GetChildren()) do
                    if t:IsA("Tool") then pcall(function() t:Activate() end) end
                end
            end)
        else
            if conns.animeAttack then conns.animeAttack:Disconnect(); conns.animeAttack = nil end
        end
    end)
    sec:AddButton("TP to nearest NPC", function()
        local root = getRoot()
        if not root then return end
        local best, bestDist
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Humanoid") and obj.Health > 0 then
                local hrp = obj.Parent and obj.Parent:FindFirstChild("HumanoidRootPart")
                local plr = obj.Parent and Players:GetPlayerFromCharacter(obj.Parent)
                if hrp and not plr then
                    local d = (hrp.Position - root.Position).Magnitude
                    if not bestDist or d < bestDist then best, bestDist = hrp, d end
                end
            end
        end
        if best then root.CFrame = best.CFrame * CFrame.new(0, 0, 4) end
    end)
end

-- ---------- Build dispatch ----------

function M.Build(tab, ctx)
    alive = true
    local detected = currentGame()
    local category = currentCategory()
    tab:AddSection("Detected"):AddLabel(
        "Game: " .. detected ..
        "  |  Category: " .. category ..
        "  |  PlaceId: " .. tostring(game.PlaceId)
    )

    -- universal features (work everywhere)
    buildUniversal(tab, ctx)

    -- bespoke per-game templates
    if     detected == "Da Hood"          then buildDaHood(tab)
    elseif detected == "Blox Fruits"      then buildBloxFruits(tab)
    elseif detected == "Arsenal"          then buildArsenal(tab)
    elseif detected == "Phantom Forces"   then buildPhantomForces(tab)
    elseif detected == "Murder Mystery 2" then buildMM2(tab)
    elseif detected == "KAT (Knife Ability Test)" or detected == "KAT" then buildKAT(tab)
    elseif detected == "Jailbreak"        then buildJailbreak(tab)
    elseif detected == "Pet Simulator X"  then buildPetSimX(tab)
    elseif detected == "Counter Blox"           then buildCounterBlox(tab)
    elseif detected == "Strucid"                then buildStrucid(tab)
    elseif detected == "Bad Business"           then buildBadBusiness(tab)
    elseif detected == "Prison Life"            then buildPrisonLife(tab)
    elseif detected == "Adopt Me"               then buildAdoptMe(tab)
    elseif detected == "Brookhaven"             then buildBrookhaven(tab)
    elseif detected == "Island Royale"          then buildIslandRoyale(tab)
    elseif detected == "BIG Paintball"          then buildBigPaintball(tab)
    elseif detected == "Mad Paintball 2"        then buildMadPaintball2(tab)
    elseif detected == "Project Lazarus"        then buildProjectLazarus(tab)
    elseif detected == "Power Simulator"        then buildPowerSim(tab)
    elseif detected == "Lifting Simulator"      then buildLiftingSim(tab)
    elseif detected == "Muscle Legend"          then buildMuscleLegend(tab)
    elseif detected == "Ninja Legends"          then buildNinjaLegends(tab)
    elseif detected == "One Piece Legendary"    then buildOnePieceLegendary(tab)
    elseif detected == "One Piece Ultimate"     then buildOnePieceUltimate(tab)
    elseif detected == "One Punch Man IJ"       then buildOnePunchManIJ(tab)
    elseif detected == "JoJo Blox"              then buildJoJoBlox(tab)
    elseif detected == "Stands Online"          then buildStandsOnline(tab)
    elseif detected == "A Bizarre Day"          then buildABizarreDay(tab)
    elseif detected == "R2DA"                   then buildR2DA(tab)
    elseif detected == "Zombie Rush"            then buildZombieRush(tab)
    elseif detected == "Zombie Strike"          then buildZombieStrike(tab)
    elseif detected == "Vehicle Tycoon"         then buildVehicleTycoon(tab)
    elseif detected == "Sound Space"            then buildSoundSpace(tab)
    elseif detected == "Mayday"                 then buildMayday(tab)
    elseif detected == "Squadron"               then buildSquadron(tab)
    elseif detected == "Redwood Prison"         then buildRedwoodPrison(tab)
    elseif detected == "Wild Revolvers"         then buildWildRevolvers(tab)
    elseif detected == "No Scope Sniping"       then buildNoScopeSniping(tab)
    elseif detected == "Bullet Hell"            then buildBulletHell(tab)
    elseif detected == "Operation Scorpion"     then buildOperationScorpion(tab)
    elseif detected == "Typical Colors 2"       then buildTypicalColors2(tab)
    elseif detected == "Skywars"                then buildSkywars(tab)
    elseif detected == "Infinity RPG 2"         then buildInfinityRpg2(tab)
    elseif detected == "AceOfSpadez"            then buildAceOfSpadez(tab)
    elseif detected == "Assassin"               then buildAssassinGame(tab)
    elseif detected == "RB World 3"             then buildRBWorld3(tab)
    elseif detected == "Color Craze"            then buildColorCraze(tab)
    elseif detected == "Esper Online"           then buildEsperOnline(tab)
    elseif detected == "Terminal Railways"      then buildTerminalRailways(tab)
    elseif detected == "Rumble Quest"           then buildRumbleQuest(tab)
    end

    -- category-wide fallback (always adds, on top of bespoke)
    if     category == "Shooter"      then buildShooterCategory(tab)
    elseif category == "BattleRoyale" then buildBattleRoyaleCategory(tab)
    elseif category == "KnifeRound"   then buildKnifeRoundCategory(tab)
    elseif category == "OpenWorld"    then buildOpenWorldCategory(tab)
    elseif category == "Sim"          then buildSimCategory(tab)
    elseif category == "AnimeRPG"     then buildAnimeRPGCategory(tab)
    end

    -- Manual override. Re-picking disconnects any active connections
    -- the previous template registered so we don't leak Heartbeat
    -- listeners every time the user changes their mind.
    local function clearTemplateConns()
        local keep = {}
        for k, c in pairs(conns) do
            if k == "uniHB" then        -- universal features stay
                keep[k] = c
            else
                if c and c.Disconnect then pcall(function() c:Disconnect() end) end
            end
        end
        conns = keep
    end

    local override = tab:AddSection("Override Template")
    override:AddDropdown("Force-load template",
        {"None","Shooter","BattleRoyale","KnifeRound","OpenWorld","Sim","AnimeRPG",
         "Da Hood","Blox Fruits","Arsenal","Phantom Forces","Murder Mystery 2","KAT","Jailbreak","Pet Simulator X",
         "Counter Blox","Strucid","Bad Business","Prison Life","Adopt Me","Brookhaven"},
        "None", function(v)
        clearTemplateConns()
        if     v == "Shooter"          then buildShooterCategory(tab)
        elseif v == "BattleRoyale"     then buildBattleRoyaleCategory(tab)
        elseif v == "KnifeRound"       then buildKnifeRoundCategory(tab)
        elseif v == "OpenWorld"        then buildOpenWorldCategory(tab)
        elseif v == "Sim"              then buildSimCategory(tab)
        elseif v == "AnimeRPG"         then buildAnimeRPGCategory(tab)
        elseif v == "Da Hood"          then buildDaHood(tab)
        elseif v == "Blox Fruits"      then buildBloxFruits(tab)
        elseif v == "Arsenal"          then buildArsenal(tab)
        elseif v == "Phantom Forces"   then buildPhantomForces(tab)
        elseif v == "Murder Mystery 2" then buildMM2(tab)
        elseif v == "KAT"              then buildKAT(tab)
        elseif v == "Jailbreak"        then buildJailbreak(tab)
        elseif v == "Pet Simulator X"  then buildPetSimX(tab)
        elseif v == "Counter Blox"     then buildCounterBlox(tab)
        elseif v == "Strucid"          then buildStrucid(tab)
        elseif v == "Bad Business"     then buildBadBusiness(tab)
        elseif v == "Prison Life"      then buildPrisonLife(tab)
        elseif v == "Adopt Me"         then buildAdoptMe(tab)
        elseif v == "Brookhaven"       then buildBrookhaven(tab)
        end
    end)
end

function M.Unload()
    alive = false
    for _, c in pairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
end

M.State = universalState
return M
