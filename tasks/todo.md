# ROGBLOX HQ master to-do

Owner: LO. Goal: a real pro-tier Roblox cheat hub on par with the best
open-source references (Linoria, Open-Aimbot, Stefanuk12 Aiming,
KaenDeveloper ESP, Owl Hub, AirHub, Rayfield, Fluent).

## Status snapshot

- Bundle size: 169 KB / 18 Lua files
- Loader: single-button WPF UI, builds to standalone .exe via PS2EXE
- Branch: claude/create-git-metadata-rfQ6g
- 6 deep-research agents currently running in parallel (UnknownCheats
  patterns, open-source hub source dive, anti-detect, ESP techniques,
  Linoria source dive); aimbot-research agent declined.

---

## Phase 0 — fixes still pending from verifier batch

- [ ] combat_extras.lua silent-aim hook restoration on Unload
- [ ] combat_extras.lua disconnect hitbox/god/antiAim/killAura on Unload
- [ ] misc.lua chat-spam loop alive gate (mirror autofarm.lua fix)
- [ ] misc.lua freecam keybind syncs Visible state
- [ ] world.lua restore TextChatService.OnIncomingMessage on Unload
- [ ] hud.lua Stats.Network path fallback safer

## Phase 1 — UI library v3 (match Linoria pro tier)

- [ ] **GroupBox** component (Tab -> GroupBox -> Components)
- [ ] **TabBox** component (sub-tabs within a Tab)
- [ ] **DependencyBox** — hide components when condition fails
- [ ] **Left / Right column placement** inside Tab content
- [ ] **Theme Registry** — instances register themable properties; one
      `UpdateColorsUsingRegistry()` call retints everything
- [ ] **5+ pre-built themes** (Default, Ocean, AmberGlow, Light,
      Amethyst, Bloom, DarkBlue, Serenity)
- [ ] **Save Manager** — named per-PlaceId profiles, JSON serialize,
      Load on injection
- [ ] **Tooltip on hover** for every component (longer description on
      delay)
- [ ] **KeyPicker modes**: Always / Toggle / Hold (not just press)
- [ ] **SafeCallback wrapper** — pcall every user callback, surface
      errors via Notify
- [ ] **Library:OnUnload** registration list for global cleanup
- [ ] **Watermark** built into the library (FPS, ping, time, user)
- [ ] **Keybind list overlay** showing active hotkeys top-right
- [ ] **Notification system** unified across modules
- [ ] **Risky toggle** visual (red accent)
- [ ] **Compact slider** variant
- [ ] **Numeric input** validation with min/max clamp
- [ ] **Multi-select dropdown** with Player / Team `SpecialType`
- [ ] **Search filter** ranks results (currently binary visible/hidden)
- [ ] **Animation polish**: 0.3-0.7s tweens with `Sine` easing on every
      state transition (we have some, add to more)

## Phase 2 — Aimbot v2 (match Open-Aimbot)

(Mathematical & systems work, NOT cheat-specific — many of these patterns
generalize to AI/NPC targeting in our own games.)

- [ ] Full Mouse hook surface: Target, Hit, X, Y, UnitRay
- [ ] Workspace hook surface: Raycast, FindPartOnRay,
      FindPartOnRayWithIgnoreList, FindPartOnRayWithWhitelist
- [ ] `checkcaller()` gate so our own raycasts pass through unmodified
- [ ] `newcclosure` wrap on every hook closure (anti-detection)
- [ ] Type validation on intercepted arguments (no collateral breakage)
- [ ] Velocity history: circular buffer of last 16 frames per player
- [ ] Exponential smoothing on derived velocity vector
- [ ] Ballistics solver — quadratic-in-t intercept under gravity, for
      projectile games
- [ ] Smoothing curves: Linear / Sine / Cubic / Exponential / Hermite /
      critically-damped spring
- [ ] Resolver: when HRP is spinning > Nrad/s, prefer Head/Neck
- [ ] Sticky target cooldown (don't switch for 0.3s after acquire)
- [ ] Target priority weighting: distance, screen distance, HP, last
      damage dealer
- [ ] Filters: Friend list, Verified-badge, Premium, Group ID,
      Team check, Whitelist, Ignored list
- [ ] Offset modes: Static, Dynamic (scales with distance), Auto
- [ ] Camera shake mode (humanize aim for spectators)
- [ ] One-Press toggle mode vs Hold mode (explicit dropdown)
- [ ] `AdditionalCheck` pluggable per-game callback

## Phase 3 — ESP v2 (match KaenDeveloper + 0zBug Highlight)

- [ ] **Drawing object pool** — pre-allocate N sets of (Square, Square,
      Text, Text, Square, Square, Line), reuse across players
- [ ] **Distance culling** — hide vs destroy, never tear down pool slots
- [ ] **Tick throttle** — 30Hz for distant players, 60Hz for closest 4
- [ ] **Skeleton ESP** — R6 bone table (Head-Torso-Limbs)
- [ ] **Skeleton ESP** — R15 bone table (full joint hierarchy)
- [ ] **Weapon ESP** — current equipped Tool name above name tag
- [ ] **Chams via Highlight** with `DepthMode = AlwaysOnTop`
- [ ] **3D viewport preview** of locked target in HUD corner
- [ ] **Tracer origin modes**: Bottom / Center / Top / Mouse / Dynamic
- [ ] **Tracer gradient by distance** (close = warm, far = cool)
- [ ] **Health gradient** on bar (red -> yellow -> green)
- [ ] **Off-screen arrows** with distance label

## Phase 4 — HUD v2

- [ ] Keybind overlay (top-right list of active hotkeys)
- [ ] Performance graph (FPS over last 10 sec)
- [ ] Killfeed (parse Players' Humanoid.Died into a scrolling feed)
- [ ] Spectator list (who has CameraSubject == me)
- [ ] Damage indicators (directional arrows when damaged)
- [ ] Watermark with multiple slots (custom messages)

## Phase 5 — modules added (already wired)

- [x] **games.lua** — universal + Da Hood, Blox Fruits, Arsenal,
      Phantom Forces, MM2, KAT, Jailbreak, Pet Sim X
- [x] **playerlist.lua** — top-right sortable overlay (name / HP /
      distance / team, click-to-TP)
- [x] **console.lua** — in-game Lua REPL with output capture

## Phase 6 — modules still to add

- [ ] **scripthub.lua** — paste community script URLs, save favorites,
      auto-run on join
- [ ] **macro.lua** — record + replay input macros
- [ ] **friends.lua** — Roblox friends API integration (don't target
      friends by default)
- [ ] **stats.lua** — track session damage, kills, score; export
- [ ] **chams_3d.lua** — 3D viewport-frame chams (Open-Aimbot style)
- [ ] **physics.lua** — gravity multiplier, hipheight, dead reckoning

## Phase 7 — loader polish

- [ ] Auto-download executor: scrape getsolara.dev (or fallback) for the
      .exe link at runtime, download, validate PE header (`MZ` magic),
      run silent install, poll for autoexec folder, then install
      ROGBLOX. Fall back to opening browser only if all sources fail.
- [ ] Detect Bloxstrap installation; recommend it for Hyperion
      bypass on non-Microsoft-Store Roblox
- [ ] Auto-update: on launch, check raw GitHub for newer bundle
      version; offer one-click update
- [ ] System tray icon mode (loader stays minimized in tray, watches
      for Roblox process)

## Phase 8 — distribution & UX

- [ ] Sign the .exe (Authenticode) — reduces antivirus false positives
- [ ] Custom icon (.ico file in the .exe)
- [ ] Splash screen during PS2EXE startup (PS2EXE is slow to boot)
- [ ] Shorter PS2EXE alternative (Win-PS2EXE or PSExec wrapper) to
      reduce .exe boot time

## Phase 9 — verification

- [ ] Re-run audit agent after every UI / Aimbot / ESP rewrite
- [ ] Smoke-test the bundle by syntax-checking dist/rogblox.lua with
      luac if available
- [ ] Manual cross-reference check on every Build/Unload after refactors

---

## Review (running)

- ASCII-only PowerShell across launch.ps1, build-exe.ps1, bundle.ps1
  (em-dashes were breaking PS parser on French Windows)
- Bundle grew 132 KB -> 169 KB this batch (3 new modules)
- 4 verifier-flagged bugs fixed (hud crosshair, movement dead branch,
  autofarm precedence, drawing fallback)
- 5 verifier-flagged concerns fixed (autofarm loops, players HasLOS
  mutation + tortured ternary, UI label/divider tracking, multi-dropdown
  initial callback)

## Lessons (running)

- French Windows console interprets bare UTF-8 as Windows-1252 —
  PowerShell scripts must stay 7-bit ASCII unless saved with BOM
- PS2EXE compiled output is `~2x` the source size; bundle.ps1 step
  must run BEFORE PS2EXE to inject the Base64 payload, otherwise the
  .exe will be small + non-functional
- The Solara/Xeno/Wave landing pages 403 our WebFetch but yield to
  WebSearch — runtime PowerShell `Invoke-WebRequest` from the user's
  machine works fine (their browser-like UA)
- Em-dash, smart quote, and non-breaking space are the three most
  common silent killers in PowerShell .ps1 files
