# ROGBLOX — comprehensive audit, fix, beautify, expand

Source of audit: sub-agent verifier (see commit 836f33d).
Additional spec from LO: "test everything, audit everything, fix
everything; loader and cheat must be visually super beautiful."

## Bugs (verifier-flagged)

- [x] hud.lua:189 — crosshair outline indexing broken (`idx + 0` no-op)
- [x] movement.lua:51 — dead conditional empty body
- [x] autofarm.lua:38 — precedence bug: `model:FindFirstChild` called when `model` nil
- [x] utils/drawing.lua:46 — fallback Set Color reads TextColor3 on Frame

## Concerns / leaks (verifier-flagged)

- [x] combat_extras.lua — silent-aim metatable hook never restored / re-applies
- [x] combat_extras.lua — hitbox/god/antiaim conns + kill-aura task not cleaned up
- [x] autofarm.lua — two unbounded `while task.wait` loops survive Unload
- [x] misc.lua — chat-spam loop survives Unload
- [x] misc.lua — freecam keybind desyncs from underlying state
- [x] world.lua — TextChatService.OnIncomingMessage never restored
- [x] ui.lua — AddLabel/AddDivider don't call trackComponent (search-filter inconsistency)
- [x] ui.lua — multi-dropdown skips initial callback
- [x] players.lua — HasLOS mutates caller's ignore list
- [x] players.lua — tortured `camera.CFrame.p and {} or camera` expression

## Visual beautification

- [ ] **Loader (launch.ps1)** — rewrite in WPF
  - Borderless window, rounded corners, gradient background
  - Big logo with gradient text fill
  - Glowing accent button with hover state + press animation
  - Animated status text with check icons
  - Drop shadow
- [ ] **In-game UI (ui.lua)** — visual upgrade
  - Background gradient on window (dark to very dark)
  - Title bar gradient + soft inner glow
  - Accent strip glow effect (UIStroke + tween)
  - Section headers with gradient underline
  - Slider fill gradient
  - Toggle: smoother spring animation, glow when on
  - Notifications: slide-in from right with bounce
  - Tab indicator: pulse on selection
  - Optional blur backdrop (DepthOfFieldEffect / BlurEffect on Lighting)
  - Better fonts (`GothamSSm` if available, fallback `Gotham`)

## v0.4 features (matching/exceeding premium hubs)

- [ ] Aimbot: Whitelist (TargetList), explicit Toggle mode (vs Hold), offset modes (Static/Dynamic/Auto), camera shake option, resolver for spinning targets
- [ ] ESP: Drawing object pool, Skeleton ESP (R6/R15 bone tables)
- [ ] HUD: Keybind list overlay
- [ ] Per-PlaceId profile auto-load on join

## Verification

- [ ] Re-spawn audit agent after fixes land for a second pass
- [ ] Manual sanity check on cross-references after UI edits

## Review

_to be filled in after this batch._
