# ROGBLOX pro-tier upgrade — batch 4

Source: verifier agent findings + comprehensive web research on top-tier
hubs (Linoria, Stefanuk12 Aiming, Open-Aimbot, ESP libraries, devforum).

## Critical fixes (verifier)

- [ ] hud.lua:189 crosshair outline indexing
- [ ] movement.lua:51 dead conditional
- [ ] autofarm.lua:38 precedence bug
- [ ] utils/drawing.lua:46 fallback TextColor3 on Frame

## Leak fixes (verifier)

- [ ] combat_extras.lua silent-aim hook never restored / re-applies
- [ ] combat_extras.lua hitbox/god/antiAim/killAura not cleaned up
- [ ] autofarm.lua unbounded loops survive Unload
- [ ] misc.lua chat-spam loop survives Unload
- [ ] misc.lua freecam keybind desync
- [ ] world.lua OnIncomingMessage never restored
- [ ] ui.lua AddLabel/AddDivider don't track for search
- [ ] ui.lua multi-dropdown skips initial callback
- [ ] players.lua HasLOS mutates caller's list
- [ ] players.lua tortured expression

## Aimbot v2 (matching Stefanuk12 / Open-Aimbot)

- [ ] Hook all 5 Mouse props: Target, Hit, X, Y, UnitRay
- [ ] Hook 4 Workspace methods: Raycast, FindPartOnRay, FindPartOnRayWithIgnoreList, FindPartOnRayWithWhitelist
- [ ] Type validation on hook arguments
- [ ] checkcaller() bypass for our own raycasts
- [ ] Velocity history buffer (last 12 frames per player)
- [ ] Exponential smoothing on velocity for prediction
- [ ] Ballistics solver (projectile speed + gravity) for non-hitscan games
- [ ] AdditionalCheck pluggable callback

## ESP v2 (matching pro libraries)

- [ ] Drawing object pool (pre-allocate, reuse, don't GC)
- [ ] Distance culling — hide vs destroy
- [ ] Tick throttle — 30Hz update for far players, 60Hz for closest
- [ ] Skeleton ESP — R6 bone table (Head/Torso/limbs)
- [ ] Skeleton ESP — R15 bone table (joint hierarchy)
- [ ] Weapon ESP — show currently equipped Tool

## UI v3 (matching Linoria)

- [ ] TabBox component — sub-tabs within a tab
- [ ] GroupBox with explicit left/right column placement
- [ ] Dependency box — show component only when condition met
- [ ] Theme Manager — preset themes + custom
- [ ] Save Manager — named per-PlaceId profiles, JSON
- [ ] Keybind overlay (HUD) — show all active hotkeys top-right

## Review

_To be filled in._
