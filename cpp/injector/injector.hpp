// Manual-map injector public API. See injector.cpp for the
// implementation walk-through and pe_loader.cpp for PE specifics.

#pragma once

#include <cstdint>
#include <string>

namespace rogblox {

struct InjectResult {
    bool        ok            = false;
    void*       module_base   = nullptr;
    uint32_t    win32_error   = 0;
    std::string error_message;
};

// Manually maps `dll_path` into the process identified by `pid` and
// starts its entry point via thread hijacking (so CreateRemoteThread,
// which Hyperion hooks, is never used).
//
// On success, returns module_base = the remote base address of the
// mapped DLL inside the target. On failure, error_message contains a
// human-readable cause.
InjectResult manual_map(uint32_t pid, const std::wstring& dll_path);

}  // namespace rogblox
