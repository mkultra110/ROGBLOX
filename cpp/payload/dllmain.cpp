// Payload DllMain. The manual-map injector calls our entry with the
// remote base as the only argument (no DLL_PROCESS_ATTACH because
// the loader didn't go through the normal Windows path).
//
// Boot sequence:
//   1. Find the Roblox task scheduler via signature scan
//   2. From there, find the global lua_State*
//   3. Register our C closures (hookmetamethod, getrawmetatable, etc.)
//   4. Set a global flag the user can read from Lua to confirm load

#include <Windows.h>
#include <cstdio>

#include "bridge/luau_bridge.hpp"
#include "scanner/scheduler.hpp"
#include "shared/luau_headers.hpp"

// Forward declarations for the per-API registrars (each .cpp file
// defines one of these to push its closures onto the table at -1).
namespace rogblox::api {
    void register_closures (lua_State* L);
    void register_filesystem(lua_State* L);
    void register_instances(lua_State* L);
    void register_drawing  (lua_State* L);
    void register_input    (lua_State* L);
}

static DWORD WINAPI boot_thread(LPVOID) {
    // Find the task scheduler and the L
    auto* scheduler = rogblox::scanner::find_scheduler();
    if (!scheduler) {
        // No scheduler means we're either too early (Roblox still
        // booting) or Hyperion ate us. Retry a few times.
        for (int i = 0; i < 30 && !scheduler; ++i) {
            Sleep(500);
            scheduler = rogblox::scanner::find_scheduler();
        }
    }
    if (!scheduler) {
        OutputDebugStringA("[rogblox] scheduler not found, bailing\n");
        return 1;
    }

    lua_State* L = rogblox::bridge::get_lua_state(scheduler);
    if (!L) {
        OutputDebugStringA("[rogblox] lua_State not found\n");
        return 2;
    }

    // Push our C API onto the globals
    rogblox::api::register_closures (L);
    rogblox::api::register_filesystem(L);
    rogblox::api::register_instances(L);
    rogblox::api::register_drawing  (L);
    rogblox::api::register_input    (L);

    // Mark our presence: _G.ROGBLOX_VERSION = "0.5.0"
    lua_pushstring(L, "0.5.0");
    lua_setglobal(L, "ROGBLOX_VERSION");

    OutputDebugStringA("[rogblox] payload boot complete\n");
    return 0;
}

// Manual-map entry point. Signature matches what our shellcode calls.
// First arg is the remote base address passed by the injector.
extern "C" __declspec(dllexport)
BOOL WINAPI ManualMapEntry(LPVOID /*base*/) {
    // Spawn a worker so the hijacked thread can continue immediately
    HANDLE h = CreateThread(nullptr, 0, boot_thread, nullptr, 0, nullptr);
    if (h) CloseHandle(h);
    return TRUE;
}

// Standard DllMain still defined for completeness (the manual-map
// injector doesn't call this — it calls ManualMapEntry above — but
// having it makes the DLL load-able via LoadLibrary too, useful for
// debugging in a controlled host process).
BOOL WINAPI DllMain(HINSTANCE, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(GetModuleHandle(nullptr));
        ManualMapEntry(nullptr);
    }
    return TRUE;
}
