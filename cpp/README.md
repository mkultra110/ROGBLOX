# ROGBLOX C++ Executor Skeleton

A reference implementation of a Roblox executor written in C++.
Demonstrates manual map injection, Roblox task-scheduler discovery,
Luau VM bridging, and custom C-closure registration (the surface
that exposes `hookmetamethod`, `getrawmetatable`, `Drawing`, etc. to
user-side Luau scripts).

## Honest scope statement

**This code does NOT bypass Hyperion (Byfron) on the protected Roblox
client.** That is a continuously-evolving anti-tamper system maintained
by a Roblox-acquired company (Byfron Technologies) with full-time
employees. Defeating it requires either (a) a paid subscription cheat
team or (b) deep reverse-engineering work that gets patched within days
to weeks of every Roblox client update.

What this skeleton **does** do:

- Compile on Windows with MSVC 2022 + CMake 3.20+
- Build two artifacts: `rogblox-inject.exe` (the loader / injector) and
  `rogblox-payload.dll` (the injected DLL)
- Demonstrate **manual map injection** primitives (PE parsing, section
  copy, IAT fixups, base relocations, thread-hijack execution start)
  patterned on RMMInject and Thorioum's RbxMMap
- Demonstrate **Luau VM bridging** — locate the `lua_State*`, push C
  closures onto the global table, expose a tiny custom API
- Demonstrate **scheduler discovery** via AOB pattern scanning, with
  per-Roblox-build offsets configurable in `payload/shared/offsets.h`

It will:

- ✅ Work on **Roblox Studio** (no Hyperion present) for learning,
  inspection, and protocol experimentation in your own places
- ✅ Build cleanly on a stock Windows + VS 2022 + Luau headers
- ❌ NOT attach to the production Roblox player on Windows (Hyperion
  immediately terminates any uninvited module map)
- ❌ NOT provide a working production cheat

Real production executors (Solara, Wave, Volt) are paid closed-source
projects that update weekly. Replicating their attach reliability is a
team-scale ongoing engagement — see `docs/HYPERION.md`.

## Why does the rest of ROGBLOX use Lua then?

Because **the cheat that runs inside the executor is always Lua/Luau**
— that's what Roblox's task scheduler can execute. The C++ side is the
*injector + bridge*; the Lua side is the *cheat itself*. ROGBLOX's main
deliverable is the Lua side, which runs on any UNC-compliant executor
the user installs (Solara, Wave, Xeno, etc.). The C++ skeleton in this
directory is for users who want to build their own executor to host
ROGBLOX.

## Repository layout

```
cpp/
├── README.md                ← you are here
├── CMakeLists.txt           ← top-level project; builds injector + payload
├── docs/
│   ├── HYPERION.md          ← what Hyperion does and why bypass is hard
│   ├── BUILD.md             ← Windows build instructions
│   └── ARCHITECTURE.md      ← layer-by-layer walk through the code
├── injector/
│   ├── CMakeLists.txt
│   ├── main.cpp             ← `rogblox-inject.exe <pid>`
│   ├── injector.cpp/.hpp    ← manual map orchestrator
│   ├── pe_loader.cpp/.hpp   ← PE parsing, IAT, relocations
│   └── thread_hijack.cpp/.hpp ← stealth exec start
└── payload/
    ├── CMakeLists.txt
    ├── dllmain.cpp          ← DllMain + setup
    ├── shared/
    │   ├── luau_headers.hpp ← Luau C API forward decls
    │   └── offsets.hpp      ← Roblox internal struct offsets (per-build)
    ├── scanner/
    │   ├── signatures.cpp/.hpp ← AOB scans
    │   └── scheduler.cpp/.hpp  ← task scheduler discovery
    ├── bridge/
    │   ├── luau_bridge.cpp/.hpp ← lua_State* exposure, closures
    │   └── identity.cpp/.hpp    ← thread-identity manipulation
    ├── api/
    │   ├── closures.cpp     ← hookmetamethod, getrawmetatable, etc.
    │   ├── filesystem.cpp   ← readfile, writefile
    │   ├── instances.cpp    ← gethui, getinstances
    │   ├── drawing.cpp      ← Drawing primitives (Direct2D-backed)
    │   └── input.cpp        ← mouse1click, keypress
    └── overlay/
        ├── overlay.cpp/.hpp ← optional in-game ImGui overlay
        └── d3d11_hook.cpp/.hpp ← Present hook for the overlay
```

## Build (Windows)

See [`docs/BUILD.md`](docs/BUILD.md). TL;DR:

```powershell
# Prereqs: Visual Studio 2022 (Desktop C++ workload), CMake 3.20+, git.
git clone <repo>
cd ROGBLOX\cpp
cmake -S . -B build -A x64
cmake --build build --config Release
# Output:
#   build\Release\rogblox-inject.exe
#   build\Release\rogblox-payload.dll
```

## Usage (Roblox Studio only — see scope statement)

```powershell
# Launch Roblox Studio, open any place, then:
.\rogblox-inject.exe <Studio's PID>
```

The payload DLL maps itself in, finds the Luau state, and registers
`print(_G.ROGBLOX_VERSION)` as a smoke-test global. Open Studio's
output window and run a script to verify it's hooked.

## License + caveats

MIT for the code in this directory. The author is **not** responsible
for misuse against the Roblox production client (which is forbidden by
Roblox ToS and will get accounts banned). This is research code.

For more on what Hyperion does and why production-grade bypass is out
of scope for a hobby project, read [`docs/HYPERION.md`](docs/HYPERION.md).
