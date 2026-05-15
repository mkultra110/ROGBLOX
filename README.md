# ROGBLOX

Roblox cheat hub. One-click loader for Windows.

## Use

1. Download the repo (green **Code** button -> Download ZIP) and unzip it.
2. Make sure the repo is **public** on GitHub (the in-game loader fetches over HTTPS).
3. Double-click **`launch.bat`**.
4. Click **Load and Launch Roblox**.

That's it. The loader:
- Installs the cheat into every executor's autoexec folder it can find
  (Synapse X, Wave, Krnl, Fluxus, Script-Ware, Solara, AWP, Xeno, Hydrogen,
  Delta, CelerNB).
- Copies the loader one-liner to your clipboard.
- Launches Roblox.

Attach your executor when you're in a game. The script runs automatically.
Press **RightCtrl** in-game to toggle the menu.

## Features

Aimbot - ESP - Silent aim - Hitbox expander - Kill aura - Anti-aim -
Walkspeed / Jump / Fly / Noclip / Spinbot - Teleport (player, saved slots,
click-tp, server hop) - Fullbright / No-fog / FOV unlock / Item ESP /
Chat log - Auto clicker / Auto attack / NPC tracker - Anti-AFK / FPS cap /
Anti-fling / Chat spam / Freecam.

Config is saved per game (`PlaceId`) in your executor's workspace folder.

## Manual loader

If autoexec doesn't fire, paste this into your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/mkultra110/rogblox/main/src/main.lua"))()
```
