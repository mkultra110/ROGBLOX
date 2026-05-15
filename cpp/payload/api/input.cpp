// Synthetic input API: mouse1click, mouse1press, mouse1release,
// mouse2click, mousescroll, mousemoverel, mousemoveabs, keypress,
// keyrelease, isrbxactive.
//
// Backed by SendInput on Windows. Production executors sometimes
// inject at a lower layer to defeat games that filter SendInput
// origin, but for most use cases plain user32 SendInput works.

#include <Windows.h>
#include "shared/luau_headers.hpp"
#include "bridge/luau_bridge.hpp"

namespace rogblox::api {

static void mouse_event(DWORD flags, LONG dx = 0, LONG dy = 0, DWORD data = 0) {
    INPUT in{};
    in.type = INPUT_MOUSE;
    in.mi.dwFlags  = flags;
    in.mi.dx       = dx;
    in.mi.dy       = dy;
    in.mi.mouseData = data;
    SendInput(1, &in, sizeof(in));
}

extern "C" int l_mouse1press(lua_State*)   { mouse_event(MOUSEEVENTF_LEFTDOWN);  return 0; }
extern "C" int l_mouse1release(lua_State*) { mouse_event(MOUSEEVENTF_LEFTUP);    return 0; }
extern "C" int l_mouse1click(lua_State*) {
    mouse_event(MOUSEEVENTF_LEFTDOWN);
    mouse_event(MOUSEEVENTF_LEFTUP);
    return 0;
}
extern "C" int l_mouse2press(lua_State*)   { mouse_event(MOUSEEVENTF_RIGHTDOWN); return 0; }
extern "C" int l_mouse2release(lua_State*) { mouse_event(MOUSEEVENTF_RIGHTUP);   return 0; }
extern "C" int l_mouse2click(lua_State*) {
    mouse_event(MOUSEEVENTF_RIGHTDOWN);
    mouse_event(MOUSEEVENTF_RIGHTUP);
    return 0;
}
extern "C" int l_mousemoverel(lua_State* L) {
    int isnum = 0;
    LONG dx = (LONG)lua_tonumberx(L, 1, &isnum);
    LONG dy = (LONG)lua_tonumberx(L, 2, &isnum);
    mouse_event(MOUSEEVENTF_MOVE, dx, dy);
    return 0;
}
extern "C" int l_mousemoveabs(lua_State* L) {
    int isnum = 0;
    LONG x = (LONG)lua_tonumberx(L, 1, &isnum);
    LONG y = (LONG)lua_tonumberx(L, 2, &isnum);
    SetCursorPos(x, y);
    return 0;
}
extern "C" int l_mousescroll(lua_State* L) {
    int isnum = 0;
    LONG dz = (LONG)lua_tonumberx(L, 1, &isnum);
    mouse_event(MOUSEEVENTF_WHEEL, 0, 0, dz * WHEEL_DELTA);
    return 0;
}

extern "C" int l_keypress(lua_State* L) {
    int isnum = 0;
    WORD vk = (WORD)lua_tonumberx(L, 1, &isnum);
    INPUT in{};
    in.type = INPUT_KEYBOARD;
    in.ki.wVk = vk;
    SendInput(1, &in, sizeof(in));
    return 0;
}
extern "C" int l_keyrelease(lua_State* L) {
    int isnum = 0;
    WORD vk = (WORD)lua_tonumberx(L, 1, &isnum);
    INPUT in{};
    in.type = INPUT_KEYBOARD;
    in.ki.wVk = vk;
    in.ki.dwFlags = KEYEVENTF_KEYUP;
    SendInput(1, &in, sizeof(in));
    return 0;
}

extern "C" int l_isrbxactive(lua_State* L) {
    HWND fg = GetForegroundWindow();
    wchar_t title[256] = {};
    GetWindowTextW(fg, title, 256);
    lua_pushboolean(L, wcsstr(title, L"Roblox") != nullptr ? 1 : 0);
    return 1;
}

void register_input(lua_State* L) {
    rogblox::bridge::register_global(L, "mouse1press",   l_mouse1press);
    rogblox::bridge::register_global(L, "mouse1release", l_mouse1release);
    rogblox::bridge::register_global(L, "mouse1click",   l_mouse1click);
    rogblox::bridge::register_global(L, "mouse2press",   l_mouse2press);
    rogblox::bridge::register_global(L, "mouse2release", l_mouse2release);
    rogblox::bridge::register_global(L, "mouse2click",   l_mouse2click);
    rogblox::bridge::register_global(L, "mousemoverel",  l_mousemoverel);
    rogblox::bridge::register_global(L, "mousemoveabs",  l_mousemoveabs);
    rogblox::bridge::register_global(L, "mousescroll",   l_mousescroll);
    rogblox::bridge::register_global(L, "keypress",      l_keypress);
    rogblox::bridge::register_global(L, "keyrelease",    l_keyrelease);
    rogblox::bridge::register_global(L, "isrbxactive",   l_isrbxactive);
}

}  // namespace rogblox::api
