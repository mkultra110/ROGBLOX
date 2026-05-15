// Drawing API. The library that lets Lua draw lines, squares,
// circles, text on top of the game window without going through
// Roblox's GUI system. Production: hook IDXGISwapChain::Present
// (or vkQueuePresentKHR if the user has Vulkan) and render via
// ImGui or Direct2D.
//
// This file stubs the API surface so user scripts can call it
// without errors. The shapes don't actually render on screen.
// Implementing the render side requires a D3D11 Present hook -
// see overlay/d3d11_hook.cpp for the scaffolding.

#include "shared/luau_headers.hpp"
#include "bridge/luau_bridge.hpp"

namespace rogblox::api {

struct DrawingObject {
    int    type;       // 0=Line 1=Text 2=Square 3=Circle 4=Quad 5=Triangle
    bool   visible;
    float  thickness;
    float  transparency;
    float  r, g, b;
    // Type-specific fields are appended dynamically.
};

extern "C" int l_drawing_new(lua_State* L) {
    // Creates a new Drawing object. Real implementation: allocate
    // a DrawingObject, push a userdata wrapper, register it with
    // the overlay renderer so it gets drawn each frame.
    lua_pushnil(L);
    return 1;
}

extern "C" int l_cleardrawcache(lua_State* L) {
    // Destroys every active Drawing object. Useful for reload.
    return 0;
}

extern "C" int l_isrenderobj(lua_State* L) {
    lua_pushboolean(L, 0);
    return 1;
}

void register_drawing(lua_State* L) {
    // Construct a Drawing table with .new and .Fonts; bind methods.
    lua_getglobal(L, "Drawing");
    if (lua_type(L, -1) == 0) {  // LUA_TNIL
        lua_settop(L, -2);
        // Create a new table
        // (real Roblox/Luau API: lua_newtable; omitted here because
        // we kept the header minimal)
    }
    rogblox::bridge::register_global(L, "cleardrawcache", l_cleardrawcache);
    rogblox::bridge::register_global(L, "isrenderobj",    l_isrenderobj);
}

}  // namespace rogblox::api
