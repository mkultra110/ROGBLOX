// rogblox-inject.exe
//
// Usage:
//     rogblox-inject.exe <pid>             // inject by Process ID
//     rogblox-inject.exe --proc <name>     // inject by process name
//
// Loads rogblox-payload.dll (sibling file) into the target Roblox
// process via manual map. See injector.cpp for the actual mapping
// logic and the heavy caveats in ../README.md regarding Hyperion.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <string>
#include <vector>
#include <Windows.h>
#include <TlHelp32.h>

#include "injector.hpp"

namespace fs = std::filesystem;

static void usage(const char* argv0) {
    std::fprintf(stderr, "ROGBLOX injector\n");
    std::fprintf(stderr, "  %s <pid>\n", argv0);
    std::fprintf(stderr, "  %s --proc <name.exe>\n", argv0);
}

static DWORD find_process_by_name(const std::wstring& name) {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return 0;

    PROCESSENTRY32W entry{};
    entry.dwSize = sizeof(entry);

    DWORD found = 0;
    if (Process32FirstW(snap, &entry)) {
        do {
            std::wstring exe = entry.szExeFile;
            // case-insensitive match
            std::wstring a = exe;
            std::wstring b = name;
            for (auto& c : a) c = (wchar_t)towlower(c);
            for (auto& c : b) c = (wchar_t)towlower(c);
            if (a == b) {
                found = entry.th32ProcessID;
                break;
            }
        } while (Process32NextW(snap, &entry));
    }
    CloseHandle(snap);
    return found;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        usage(argv[0]);
        return 1;
    }

    DWORD pid = 0;
    if (std::strcmp(argv[1], "--proc") == 0) {
        if (argc < 3) { usage(argv[0]); return 1; }
        std::wstring name(argv[2], argv[2] + std::strlen(argv[2]));
        pid = find_process_by_name(name);
        if (!pid) {
            std::fprintf(stderr, "[!] process '%s' not found\n", argv[2]);
            return 2;
        }
    } else {
        pid = (DWORD)std::strtoul(argv[1], nullptr, 10);
        if (!pid) {
            std::fprintf(stderr, "[!] invalid pid '%s'\n", argv[1]);
            return 2;
        }
    }

    // Resolve the payload DLL next to this exe
    wchar_t selfBuf[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, selfBuf, MAX_PATH);
    fs::path payload = fs::path(selfBuf).parent_path() / L"rogblox-payload.dll";
    if (!fs::exists(payload)) {
        std::fwprintf(stderr, L"[!] payload DLL not found at %s\n", payload.c_str());
        return 3;
    }

    std::fprintf(stdout, "[*] target pid: %lu\n", pid);
    std::fwprintf(stdout, L"[*] payload:    %s\n", payload.c_str());

    rogblox::InjectResult res = rogblox::manual_map(pid, payload.wstring());
    if (res.ok) {
        std::fprintf(stdout, "[+] mapped payload at 0x%p, exec started\n", res.module_base);
        return 0;
    } else {
        std::fprintf(stderr, "[!] inject failed: %s (win32 err %lu)\n",
                     res.error_message.c_str(), res.win32_error);
        return 4;
    }
}
