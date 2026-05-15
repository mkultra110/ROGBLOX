// Bridge between the C++ payload and Roblox's embedded Luau VM.
// Wraps the dirty work of locating lua_State*, manipulating its
// stack, and registering C closures at the global level.

#pragma once

#include "shared/luau_headers.hpp"

namespace rogblox::bridge {

// Given a scheduler pointer (from scanner::find_scheduler), drill
// down to the lua_State the script runtime actually uses. Returns
// nullptr if anything along the path fails.
lua_State* get_lua_state(void* scheduler);

// Register a single C closure as a global by name. Convenience.
void register_global(lua_State* L, const char* name, lua_CFunction fn);

// Push a "newcclosure"-like wrapper: a CClosure whose Closure::isC
// flag is forged so iscclosure(f) returns true even when f wraps a
// Lua function. Critical for anti-detection.
//
// Returns the registered identity of the wrapper for unhook later.
int push_newcclosure(lua_State* L, lua_CFunction fn);

}  // namespace rogblox::bridge
