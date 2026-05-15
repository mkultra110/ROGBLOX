// Closure-related UNC functions: checkcaller, iscclosure, islclosure,
// newcclosure, hookfunction, hookmetamethod, getrawmetatable,
// getnamecallmethod, setreadonly.
//
// Each of these manipulates a Closure object's flags or a metatable
// pointer at the C struct level. Production implementations require
// the exact byte offsets for the current Roblox build.

#include "shared/luau_headers.hpp"
#include "bridge/luau_bridge.hpp"

#include <cstdint>
#include <unordered_map>

namespace rogblox::api {

// Per-script thread-identity tag for checkcaller()
static thread_local int g_caller_depth = 0;

extern "C" int l_checkcaller(lua_State* L) {
    // Returns true if the call came from executor code, false if
    // from game code. Production: read a tag on the current thread
    // set by the bridge before/after every user-script invocation.
    lua_pushboolean(L, g_caller_depth > 0 ? 1 : 0);
    return 1;
}

extern "C" int l_iscclosure(lua_State* L) {
    // Reads the Closure::isC flag of the function at index 1.
    // Stub: pretend everything's C - real code reads
    //   ((Closure*)clvalue(L->base))->isC.
    lua_pushboolean(L, 1);
    return 1;
}

extern "C" int l_islclosure(lua_State* L) {
    lua_pushboolean(L, 0);
    return 1;
}

extern "C" int l_newcclosure(lua_State* L) {
    // Wraps a Lua function in a CClosure trampoline so iscclosure
    // returns true. See bridge/luau_bridge.cpp::push_newcclosure
    // for the placeholder behavior here.
    lua_pushvalue(L, 1);
    return 1;
}

extern "C" int l_getrawmetatable(lua_State* L) {
    // Reads the raw metatable pointer of the object at index 1
    // without honoring __metatable. Production: lua_getmetatable
    // semantics but bypassing the read-only check.
    //
    // Stub: push nil.
    lua_pushnil(L);
    return 1;
}

extern "C" int l_setreadonly(lua_State* L) {
    // Flip the Table::readonly flag. Stub.
    return 0;
}

extern "C" int l_getnamecallmethod(lua_State* L) {
    // Returns the method name when called inside a __namecall
    // metamethod. Production: read from the active thread's
    // namecall slot.
    lua_pushstring(L, "");
    return 1;
}

extern "C" int l_hookfunction(lua_State* L) {
    // Replace one Closure's code with another. Caller passes
    // (target, hook). Production: swap LClosure::p / CClosure::f
    // and return a wrapper to the original.
    //
    // Stub: returns the second argument as the "original" so
    // user scripts don't crash.
    lua_pushvalue(L, 2);
    return 1;
}

extern "C" int l_hookmetamethod(lua_State* L) {
    // (object, method_name, hook) -> original
    // Wraps getrawmetatable + hookfunction on the named metamethod.
    lua_pushvalue(L, 3);
    return 1;
}

void register_closures(lua_State* L) {
    rogblox::bridge::register_global(L, "checkcaller",       l_checkcaller);
    rogblox::bridge::register_global(L, "iscclosure",        l_iscclosure);
    rogblox::bridge::register_global(L, "islclosure",        l_islclosure);
    rogblox::bridge::register_global(L, "newcclosure",       l_newcclosure);
    rogblox::bridge::register_global(L, "getrawmetatable",   l_getrawmetatable);
    rogblox::bridge::register_global(L, "setreadonly",       l_setreadonly);
    rogblox::bridge::register_global(L, "getnamecallmethod", l_getnamecallmethod);
    rogblox::bridge::register_global(L, "hookfunction",      l_hookfunction);
    rogblox::bridge::register_global(L, "hookmetamethod",    l_hookmetamethod);
}

}  // namespace rogblox::api
