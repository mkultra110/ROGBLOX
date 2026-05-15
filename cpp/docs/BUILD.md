# Build instructions (Windows)

## Prerequisites

| Tool               | Version | Where to get it |
|--------------------|---------|-----------------|
| Visual Studio 2022 | 17.4+   | https://visualstudio.microsoft.com/ (Community is free) |
| Workload           | "Desktop development with C++" | VS Installer |
| CMake              | 3.20+   | https://cmake.org/download/ (or bundled with VS) |
| Git                | latest  | https://git-scm.com/ |
| Windows SDK        | 10.0.22621 or newer | bundled with VS workload |

## Build steps

```powershell
# From the repo root
cd cpp
cmake -S . -B build -A x64
cmake --build build --config Release -- /m
```

Outputs:

- `cpp\build\Release\rogblox-inject.exe`  - the injector / loader
- `cpp\build\Release\rogblox-payload.dll` - the injected payload

Place these two files side-by-side. The injector resolves the payload
DLL relative to its own location.

## Running

> **Read `docs/HYPERION.md` first.** Production Roblox client refuses
> the injection. Use Roblox Studio.

```powershell
# Method 1: by PID
.\rogblox-inject.exe 12345

# Method 2: by process name
.\rogblox-inject.exe --proc RobloxStudioBeta.exe
```

If the injection succeeds, the global `ROGBLOX_VERSION` will be set
inside Studio's Lua environment. Open Studio's Output window and
run:

```lua
print(ROGBLOX_VERSION)
```

If you see `0.5.0`, the bridge is wired up. From there, every UNC
function the payload registered (`hookmetamethod`, `getrawmetatable`,
`mouse1click`, `writefile`, etc.) is available.

## Troubleshooting

- **"payload DLL not found"** - make sure `rogblox-payload.dll` is in
  the same directory as `rogblox-inject.exe`.
- **"OpenProcess: Access is denied"** - either the target is
  Hyperion-protected (use Studio), or you need to run the injector
  elevated (right-click -> Run as Administrator).
- **"no hijack candidate thread"** - same root cause; Hyperion is
  hiding threads from Toolhelp32.
- **Build error: cannot find IMAGE_BASE_RELOCATION** - your Windows
  SDK is too old. Update to 10.0.22621 or newer.
- **Linker error on `D3D11`, `D2D1`, etc.** - the payload assumes the
  Direct3D headers are available; they ship with the Windows SDK.

## Cross-platform note

This project is Windows-only by design. Roblox executors only target
Windows since that's the only platform with the user-mode injection
surface they need.
