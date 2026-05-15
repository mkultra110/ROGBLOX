#include "luau_bridge.hpp"
#include "shared/offsets.hpp"

#include <cstdint>

namespace rogblox::bridge {

lua_State* get_lua_state(void* scheduler) {
    if (!scheduler) return nullptr;
    // Each Roblox build's offset chain is different; the values in
    // offsets.hpp are placeholders. Production:
    //   1. scheduler -> jobs array
    //   2. find the script-runner job (named, has a specific vtable)
    //   3. read lua_State* from a known field
    // Here we just return nullptr because we don't know the offsets
    // for any specific Roblox build.
    auto* sched = (uint8_t*)scheduler;
    auto* jobs  = *(uint8_t**)(sched + rogblox::offsets::k_scheduler_to_jobs);
    if (!jobs) return nullptr;
    auto* L     = *(lua_State**)(jobs + rogblox::offsets::k_job_to_lua_state);
    return L;
}

void register_global(lua_State* L, const char* name, lua_CFunction fn) {
    if (!L || !fn || !name) return;
    lua_pushcclosure(L, fn, name, 0);
    lua_setglobal(L, name);
}

int push_newcclosure(lua_State* L, lua_CFunction fn) {
    // For a true `newcclosure` you'd allocate a CClosure object,
    // set Closure::isC = 1, install fn as its callee, and stash the
    // original somewhere accessible. Production executors do this
    // via direct memory writes to the Closure struct.
    //
    // Here we approximate by pushing a regular cclosure - good enough
    // for the skeleton; an actual hub that needs true newcclosure
    // would replace this implementation with offset-aware code.
    lua_pushcclosure(L, fn, "rogblox_ncc", 0);
    return 0;
}

}  // namespace rogblox::bridge
