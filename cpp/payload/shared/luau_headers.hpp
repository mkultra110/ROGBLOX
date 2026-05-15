// Minimal Luau C API forward declarations. The real headers come
// from https://github.com/luau-lang/luau and you should add them as
// a CMake dependency for production work. Here we declare just the
// pointer types and functions we use to keep the skeleton standalone.

#pragma once

#include <cstddef>
#include <cstdint>

extern "C" {

typedef struct lua_State lua_State;
typedef int (*lua_CFunction)(lua_State* L);

// Stack
lua_State* lua_newthread(lua_State* L);
void       lua_close(lua_State* L);
int        lua_gettop(lua_State* L);
void       lua_settop(lua_State* L, int idx);
void       lua_pushnil(lua_State* L);
void       lua_pushnumber(lua_State* L, double n);
void       lua_pushboolean(lua_State* L, int b);
void       lua_pushlstring(lua_State* L, const char* s, size_t len);
void       lua_pushstring(lua_State* L, const char* s);
void       lua_pushcclosurek(lua_State* L, lua_CFunction fn, const char* debugname,
                             int nup, lua_CFunction cont);
void       lua_pushvalue(lua_State* L, int idx);

#define lua_pushcclosure(L, fn, dbg, n) lua_pushcclosurek(L, fn, dbg, n, nullptr)
#define lua_pushcfunction(L, fn)        lua_pushcclosure(L, fn, "", 0)

// Get / set
void       lua_setfield(lua_State* L, int idx, const char* k);
void       lua_getfield(lua_State* L, int idx, const char* k);
void       lua_setglobal(lua_State* L, const char* name);
void       lua_getglobal(lua_State* L, const char* name);
int        lua_type(lua_State* L, int idx);
const char* lua_tolstring(lua_State* L, int idx, size_t* len);
double     lua_tonumberx(lua_State* L, int idx, int* isnum);
int        lua_toboolean(lua_State* L, int idx);

// Pseudo-indices
#define LUA_GLOBALSINDEX  (-10002)
#define LUA_ENVIRONINDEX  (-10001)
#define LUA_REGISTRYINDEX (-10000)

// Compile + load Luau bytecode
int luau_compile(const char* source, size_t source_len, void* opts,
                 char** bytecode, size_t* bytecode_len);
int luau_load(lua_State* L, const char* chunkname,
              const char* bytecode, size_t bytecode_len, int env);

// Pcall
int lua_pcall(lua_State* L, int nargs, int nresults, int errfunc);

}  // extern "C"
