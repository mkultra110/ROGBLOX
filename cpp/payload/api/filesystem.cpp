// Filesystem UNC functions: readfile, writefile, isfile, isfolder,
// makefolder, appendfile, delfile, delfolder, listfiles, loadfile,
// dofile. Sandboxed to a per-executor workspace folder under
// %LOCALAPPDATA%\ROGBLOX\workspace\.

#include <Windows.h>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

#include "shared/luau_headers.hpp"
#include "bridge/luau_bridge.hpp"

namespace fs = std::filesystem;

namespace rogblox::api {

static fs::path workspace_root() {
    wchar_t* local = nullptr;
    size_t len = 0;
    _wdupenv_s(&local, &len, L"LOCALAPPDATA");
    fs::path p = local ? local : L".";
    free(local);
    return p / L"ROGBLOX" / L"workspace";
}

static fs::path resolve(const char* user_path) {
    fs::path root = workspace_root();
    fs::path rel  = fs::path(user_path).lexically_normal();
    // Refuse paths that escape the workspace
    fs::path joined = (root / rel).lexically_normal();
    auto root_s = root.wstring();
    auto j_s    = joined.wstring();
    if (j_s.rfind(root_s, 0) != 0) return root;  // collapsed back to root
    return joined;
}

extern "C" int l_readfile(lua_State* L) {
    size_t n = 0;
    const char* p = lua_tolstring(L, 1, &n);
    if (!p) { lua_pushnil(L); return 1; }
    std::ifstream f(resolve(p), std::ios::binary | std::ios::ate);
    if (!f) { lua_pushnil(L); return 1; }
    auto size = f.tellg();
    f.seekg(0);
    std::string s; s.resize((size_t)size);
    f.read(s.data(), size);
    lua_pushlstring(L, s.data(), s.size());
    return 1;
}

extern "C" int l_writefile(lua_State* L) {
    size_t pn = 0, cn = 0;
    const char* p = lua_tolstring(L, 1, &pn);
    const char* c = lua_tolstring(L, 2, &cn);
    if (!p || !c) return 0;
    auto path = resolve(p);
    fs::create_directories(path.parent_path());
    std::ofstream f(path, std::ios::binary);
    if (!f) return 0;
    f.write(c, cn);
    return 0;
}

extern "C" int l_isfile(lua_State* L) {
    size_t n = 0;
    const char* p = lua_tolstring(L, 1, &n);
    lua_pushboolean(L, p ? fs::is_regular_file(resolve(p)) : 0);
    return 1;
}

extern "C" int l_isfolder(lua_State* L) {
    size_t n = 0;
    const char* p = lua_tolstring(L, 1, &n);
    lua_pushboolean(L, p ? fs::is_directory(resolve(p)) : 0);
    return 1;
}

extern "C" int l_makefolder(lua_State* L) {
    size_t n = 0;
    const char* p = lua_tolstring(L, 1, &n);
    if (p) fs::create_directories(resolve(p));
    return 0;
}

extern "C" int l_delfile(lua_State* L) {
    size_t n = 0;
    const char* p = lua_tolstring(L, 1, &n);
    if (p) std::error_code ec; fs::remove(resolve(p), ec);
    return 0;
}

void register_filesystem(lua_State* L) {
    rogblox::bridge::register_global(L, "readfile",   l_readfile);
    rogblox::bridge::register_global(L, "writefile",  l_writefile);
    rogblox::bridge::register_global(L, "isfile",     l_isfile);
    rogblox::bridge::register_global(L, "isfolder",   l_isfolder);
    rogblox::bridge::register_global(L, "makefolder", l_makefolder);
    rogblox::bridge::register_global(L, "delfile",    l_delfile);
}

}  // namespace rogblox::api
