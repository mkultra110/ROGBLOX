// Instance-related UNC: fireclickdetector, fireproximityprompt,
// fireserver, firesignal, firetouchinterest, getconnections,
// getcallbackvalue, gethiddenproperty, sethiddenproperty, gethui,
// getinstances, getnilinstances, isscriptable, setscriptable.
//
// These need a working bridge to RobloxInstance* objects in memory.
// Skeleton stubs included for the most-used ones.

#include "shared/luau_headers.hpp"
#include "bridge/luau_bridge.hpp"

namespace rogblox::api {

extern "C" int l_gethui(lua_State* L) {
    // Returns the hidden CoreGui parent that survives ResetOnSpawn
    // and is invisible to game-side anti-cheat scans. Production:
    // create a stub LayerCollector + cache it on first call.
    lua_pushnil(L);
    return 1;
}

extern "C" int l_getconnections(lua_State* L) {
    // Returns a table of connection handles for the given signal.
    // Each handle has Disable / Enable / Disconnect / Fire methods.
    // Production: walk RBXScriptSignal::Connections.
    lua_pushnil(L);
    return 1;
}

extern "C" int l_firesignal(lua_State* L) {
    // Bypasses RemoteEvent filtering by directly firing the
    // signal's callback handlers with the user-supplied args.
    return 0;
}

extern "C" int l_fireclickdetector(lua_State* L) {
    // Triggers a ClickDetector's MouseClick / MouseHoverEnter event
    // server-side regardless of distance. Production: walk the
    // event's __namecall chain and call FireServer manually.
    return 0;
}

extern "C" int l_fireproximityprompt(lua_State* L) {
    // Same idea for ProximityPrompt::TriggerEnded.
    return 0;
}

extern "C" int l_firetouchinterest(lua_State* L) {
    // Trigger BasePart.Touched on a remote part without actually
    // physically touching it.
    return 0;
}

void register_instances(lua_State* L) {
    rogblox::bridge::register_global(L, "gethui",              l_gethui);
    rogblox::bridge::register_global(L, "getconnections",      l_getconnections);
    rogblox::bridge::register_global(L, "firesignal",          l_firesignal);
    rogblox::bridge::register_global(L, "fireclickdetector",   l_fireclickdetector);
    rogblox::bridge::register_global(L, "fireproximityprompt", l_fireproximityprompt);
    rogblox::bridge::register_global(L, "firetouchinterest",   l_firetouchinterest);
}

}  // namespace rogblox::api
