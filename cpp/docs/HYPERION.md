# Hyperion / Byfron - what it is, what it does, why bypass is out of scope

## Background

Hyperion is anti-tamper software developed by Byfron Technologies, a
subsidiary of Roblox Corporation since October 2022. Rolled out to
the 64-bit Roblox Player on **May 3, 2023**. It is *not* an
anti-cheat in the traditional pattern-matching sense - it's an
anti-tamper layer that detects external processes / modules tampering
with the Roblox process and crashes the client when it sees
unauthorized activity. ([Roblox Wiki: Hyperion](https://roblox.fandom.com/wiki/Hyperion))

## What it actually does (technical)

1. **Working-set scanning** - periodically calls `QueryWorkingSetEx`
   on its own process, walks resident pages, and crashes if it finds
   `PAGE_EXECUTE_*` pages outside the Roblox-signed module whitelist.
   See https://blog.nestra.tech/bypassing-hyperions-working-set-detections/
2. **Instrumentation callback abuse** - registers a kernel
   instrumentation callback (`PEB->InstrumentationCallback`) so every
   syscall return lands in Hyperion code first. Hyperion inspects R10
   (saved return address); if it points outside Roblox's whitelisted
   `.text`, the process is killed. See https://dx9.uk/posts/wave-roblox-reveral/
3. **Selective thread spawning** - hides Hyperion's own scanner
   threads from `NtQueryInformationProcess(ThreadList)`. See
   https://blog.nestra.tech/reverse-engineering-hyperion-selective-thread-spawning/
4. **VMProtect + opaque predicates** - Hyperion ships heavily
   virtualized and obfuscated to slow reverse engineering. Dumping
   it requires a tool like https://github.com/Pixeluted/HyperionDumper
   that resolves opaque branches after in-process unpacking.
5. **CFG enforcement** - newer builds enforce Control Flow Guard on
   the Roblox process; manual mappers that allocate `RWX` pages get
   killed unless they restore CFG bitmap entries.

## What it ISN'T

- **Not kernel mode.** Hyperion runs entirely in user mode. ([WeAreDevs
  forum](https://forum.wearedevs.net/t/29424))
- **Not a content-scanner.** It doesn't read your Lua scripts or
  inspect what your hub does at the script level. The wall is at the
  *executor attach* layer, not the script layer. Once an executor has
  somehow attached, the Lua hub itself is safe from Hyperion.

## Bypass status (May 2026)

Per the May-2026 survey agent:

- **Solara, Wave (paid), Xeno, Bunni, Volt** are all currently working
  against Hyperion. Bypasses are patched **within hours to days** of
  every Roblox update.
- **Public open-source bypasses do not exist** for production Roblox.
  Every "Hyperion bypass" repo on GitHub is either out-of-date
  research code (TaaprWareV2, RMMInject) or outright scam pages.
- **Roblox Studio is Hyperion-free** by design - the dev tool can't
  load anti-tamper into edit mode without false-flagging legitimate
  plugins. ([DevForum](https://devforum.roblox.com/t/hyperion-incorrectly-bans-developers-for-permitted-anticheat-testing-on-edit-enabled-experiences/4527239))

## Why this skeleton doesn't bypass it

Defeating Hyperion is a continuous, high-skill engagement:

- Each Roblox client update breaks current bypasses (typically every
  1-2 weeks)
- VMProtect packing changes pattern between releases
- The CFG, instrumentation-callback, and working-set layers each
  require independent solutions
- Sustained development requires a paid team

ROGBLOX is a **Lua hub** that runs on top of any UNC-compliant
executor. Building our own production-grade executor is intentionally
out of scope. The C++ skeleton in this directory is for:

1. Education - learning how the injector/payload layer works.
2. Studio research - testing Luau VM internals in a Hyperion-free
   environment.
3. A reference for users who want to fork and invest the effort to
   build a real executor.

If you want a Roblox cheat that actually attaches to the production
client today, install Solara/Wave/Xeno and use the ROGBLOX Lua hub
on top of them - that's the supported path.

## Further reading

- https://blog.nestra.tech/ - Nestra's full Hyperion reverse-engineering series
- https://dx9.uk/posts/wave-roblox-reveral/ - dx9's reversing of Wave
- https://github.com/Pixeluted/HyperionDumper - module dumper
- https://github.com/SecondNewtonLaw/RbxStu-V3 - open-source Studio executor
- https://github.com/Deccatron/RMMInject - manual-map reference
- https://roblox.fandom.com/wiki/Hyperion - community wiki
