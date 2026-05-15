// Thread identity manipulation. Roblox threads carry an integer
// identity (1-8) that gates access to privileged APIs like
// getrawmetatable, hookmetamethod, and gethui. Executors raise their
// own threads to identity 7 or 8 so user scripts can use those.
//
// The identity is stored in the lua_State's "extra space" (per Luau
// custom). Offsets vary per Roblox build.

#include "shared/luau_headers.hpp"
#include "shared/offsets.hpp"

#include <cstdint>

namespace rogblox::bridge {

uint32_t get_identity(lua_State* L) {
    if (!L) return 0;
    auto* extra = (uint8_t*)L + rogblox::offsets::k_state_identity;
    return *(uint32_t*)extra;
}

void set_identity(lua_State* L, uint32_t identity) {
    if (!L) return;
    auto* extra = (uint8_t*)L + rogblox::offsets::k_state_identity;
    *(uint32_t*)extra = identity;
}

}  // namespace rogblox::bridge
