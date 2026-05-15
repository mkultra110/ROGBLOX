# ROGBLOX

A modular Roblox cheat hub written in Lua. Custom draggable UI, tabbed
layout, configurable hotkeys, save/load configs, and a one-line loader.

## Loading

Paste this into any Lua executor (Synapse X, Krnl, Fluxus, Script-Ware,
AWP, etc.):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/mkultra110/rogblox/main/src/main.lua"))()
```

Or load from a specific branch:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/mkultra110/rogblox/claude/create-git-metadata-rfQ6g/src/main.lua"))()
```

## Features

### Combat
- **Aimbot** — Closest player, FOV circle, wall-check line of sight,
  team check, head/torso priority, smoothing, toggle hotkey
- **Trigger Bot** — Auto-fire when crosshair is on a player
- **Hitbox Expander** — Resize and recolor target hitboxes

### Visuals (ESP)
- Box ESP (corner / outline / filled)
- Name tag with distance
- Health bar + numeric HP
- Tracers from screen anchor (bottom / center / top)
- Team color or unified color
- Chams (highlight through walls)
- Skeleton lines

### Movement
- WalkSpeed multiplier
- JumpPower / JumpHeight modifier
- Infinite jump
- Fly (Q/E for up/down, WASD for direction, configurable speed)
- Noclip (walk through walls)
- Spinbot

### Teleport
- Teleport to selected player
- Save position slots (3 slots, hotkey load)
- Click-to-teleport (CTRL + click)
- Server hop (lowest population)
- Rejoin current server

### Misc
- Anti-AFK (defeats the 20-minute idle kick)
- FPS unlocker (sets framerate cap)
- Anti-fling
- Freecam (Right Shift to toggle)
- Chat spammer with configurable delay

### Config
- Auto-save on toggle change
- Per-game configs (keyed by `game.PlaceId`)
- Import/export config string

## Source Layout

```
src/
├── main.lua              # entry point, loads modules via HttpGet
├── config.lua            # config persistence
├── library/
│   ├── ui.lua            # custom UI library
│   └── notify.lua        # toast notifications
├── modules/
│   ├── aimbot.lua
│   ├── esp.lua
│   ├── movement.lua
│   ├── teleport.lua
│   └── misc.lua
└── utils/
    ├── players.lua       # player iteration helpers
    └── drawing.lua       # Drawing API wrappers
```

## Hotkeys (default)

| Key       | Action                       |
|-----------|------------------------------|
| RightCtrl | Toggle UI                    |
| E         | Toggle aimbot                |
| F         | Toggle fly                   |
| V         | Toggle noclip                |
| T         | Save position slot 1         |
| Y         | Load position slot 1         |
| RShift    | Toggle freecam               |

Rebind any key from the **Misc → Keybinds** section.

## Disclaimer

For educational and research purposes. Don't run on accounts you care
about — Roblox's Hyperion / Byfron anti-cheat will detect most executor
injections on protected games (the universal apps). Stick to non-Hyperion
games or VM testing.
