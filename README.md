# ROGBLOX

Roblox cheat hub. One-click loader for Windows.

## Get the single .exe (recommended)

1. Download the repo (green **Code** button -> Download ZIP) and unzip it.
2. **Double-click `build-exe.bat`** once. It installs the PS2EXE module
   (one-time, Windows PowerShell built-in), then compiles `launch.ps1`
   into **`ROGBLOX.exe`**.
3. From then on, just double-click **`ROGBLOX.exe`**. You can delete every
   other file in the folder if you want — the .exe is fully standalone.

## Use it

1. Open `ROGBLOX.exe`.
2. Click **Load**.
3. The loader installs the cheat into every executor it detects and launches
   Roblox.
4. After this one-time setup, opening Roblox always loads ROGBLOX
   automatically (assuming your executor has autoexec + auto-attach on).
5. In-game, press **RightCtrl** to toggle the menu.

If no executor is installed, the loader opens a download page for Solara
(or pick any free executor — Wave, Xeno, Delta also work). Install one,
re-run, click Load, done.

## Features

Aimbot - ESP - Silent aim - Hitbox expander - Kill aura - Anti-aim -
Walkspeed / Jump / Fly / Noclip / Spinbot - Teleport (player, named
waypoint slots, click-tp, server hop, pathwalk) - HUD (watermark,
crosshair, target lock panel, off-screen arrows) - Fullbright / No-fog /
FOV unlock / Item ESP / Chat log - Auto clicker / Auto attack / NPC
tracker - Anti-AFK / FPS cap / Anti-fling / Chat spam / Freecam.

Config saves per game (`PlaceId`) inside your executor's workspace
folder.

## Manual loader (skip the .exe)

If you don't want to compile, just paste this into your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/mkultra110/rogblox/main/src/main.lua"))()
```
