# ROGBLOX pro upgrade — todo

Brief: make the aimbot, teleport system, HUD, and menu professional-grade.

## Plan

### 1. UI library v2 (src/library/ui.lua)
- [x] New theme — accent customizable, smoother palette
- [x] Title bar with accent strip, subtitle, search box, min/close buttons
- [x] Resizable window via corner grip
- [x] Draggable
- [x] Smooth tween transitions on tab/state changes
- [x] Active-tab indicator strip
- [x] Collapsible sections
- [x] Live label search filter across all components
- [x] New components: Slider with input box, multi-select Dropdown, Color Picker, Divider
- [x] All components track Label + Frame so search can filter them

### 2. HUD module (src/modules/hud.lua) — NEW
- [x] Watermark (top-left): FPS, ping, username, time, brand
- [x] Crosshair: Plus / Dot / Circle, color, size, gap, thickness, outline
- [x] Target lock panel: name, hp bar, distance, target metadata
- [x] Off-screen arrows for enemies outside the viewport
- [x] Drawing-API based, ScreenGui fallback

### 3. Aimbot rewrite (src/modules/aimbot.lua)
- [x] Target modes: Crosshair / Mouse / Distance / LowestHP
- [x] Multi-part priority list (Head > HRP > UpperTorso default)
- [x] Prediction (lead via AssemblyLinearVelocity * t)
- [x] Visibility (Workspace:Raycast LOS)
- [x] Smoothing curves: Linear / Sine / Exponential
- [x] Sticky lock + auto-switch on invalid target
- [x] Friend list parser (comma-separated names)
- [x] FOV circle (color, filled/outline, snap line preview)
- [x] Trigger bot with delay and pixel window
- [x] Publishes M.LockedTarget for HUD panel

### 4. Teleport rewrite (src/modules/teleport.lua)
- [ ] Live player list (refresh, distance, HP shown)
- [ ] 10 named waypoint slots — save / load / clear / rename
- [ ] TP modes: To / Behind / In front / Above / Below / Aim TP
- [ ] Pathwalk (smooth interp over N seconds instead of instant)
- [ ] TP history (back / forward stack)
- [ ] Click-TP retained (Ctrl + click)
- [ ] Server hop + rejoin retained

### 5. Wiring (src/main.lua)
- [ ] Add HUD tab, build before Aimbot so HUD reads aimbot.LockedTarget
- [ ] Pass aimbot module into HUD context (or do it via the shared M.LockedTarget pattern)
- [ ] Keep ordering: Aimbot / Visuals / Combat+ / Movement / Teleport / HUD / World / Auto / Misc / Settings

### 6. Verification
- [ ] All Lua files load without syntax errors (lua -p as best-effort)
- [ ] Loader URL produces no 404 on the pushed branch
- [ ] Cross-reference module API signatures match between aimbot.M.LockedTarget and hud reads

### 7. Commit / push / PR
- [ ] git commit with clear summary
- [ ] git push -u origin claude/create-git-metadata-rfQ6g
- [ ] Note: PR cannot be opened until base branch exists on repo

## Review
_To be filled in after execution._
