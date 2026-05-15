// Manual-map orchestrator. Pulls together the PE loader, remote
// allocation, relocation/IAT fixup, shellcode build, and thread
// hijack to land the payload DLL inside the target process.
//
// Failure modes you'll most commonly see:
//   - OpenProcess refused: target is Hyperion-protected (production
//     Roblox client). Use Roblox Studio for testing instead.
//   - WriteProcessMemory access denied: same root cause.
//   - find_hijack_candidate returned 0: target has no enumerable
//     threads via Toolhelp32 because Hyperion hid them; same fix.

#include "injector.hpp"
#include "pe_loader.hpp"
#include "thread_hijack.hpp"

#include <Windows.h>
#include <cstdio>
#include <cstring>
#include <string>

namespace rogblox {

static std::string last_error_message(DWORD err) {
    char buf[512] = {};
    FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                   nullptr, err, 0, buf, sizeof(buf), nullptr);
    // Strip trailing CRLF
    size_t n = std::strlen(buf);
    while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\r')) buf[--n] = 0;
    return std::string(buf);
}

InjectResult manual_map(uint32_t pid, const std::wstring& dll_path) {
    InjectResult res{};

    // 1. Load + parse the DLL from disk
    pe::LoadedPe pe{};
    if (!pe::load_from_file(dll_path.c_str(), pe)) {
        res.error_message = "load_from_file failed (bad PE?)";
        return res;
    }

    // 2. Open the target process with the rights we need
    HANDLE proc = OpenProcess(PROCESS_VM_OPERATION | PROCESS_VM_WRITE |
                              PROCESS_VM_READ | PROCESS_QUERY_INFORMATION,
                              FALSE, pid);
    if (!proc) {
        res.win32_error   = GetLastError();
        res.error_message = "OpenProcess: " + last_error_message(res.win32_error);
        return res;
    }

    // 3. Allocate a region big enough for SizeOfImage in the target
    uint32_t image_size = pe::size_of_image(pe);
    void* remote_base = VirtualAllocEx(proc, nullptr, image_size,
                                       MEM_COMMIT | MEM_RESERVE,
                                       PAGE_EXECUTE_READWRITE);
    if (!remote_base) {
        res.win32_error   = GetLastError();
        res.error_message = "VirtualAllocEx: " + last_error_message(res.win32_error);
        CloseHandle(proc);
        return res;
    }

    // 4. Build the in-memory image locally, fix up, then write it
    std::string image_local;
    image_local.resize(image_size, '\0');
    pe::build_image(pe, (uint8_t*)image_local.data(), image_size);
    pe::apply_relocations(pe, (uint8_t*)image_local.data(),
                          (uint64_t)remote_base);
    if (!pe::resolve_imports(pe, (uint8_t*)image_local.data())) {
        res.error_message = "resolve_imports failed";
        VirtualFreeEx(proc, remote_base, 0, MEM_RELEASE);
        CloseHandle(proc);
        return res;
    }

    SIZE_T written = 0;
    if (!WriteProcessMemory(proc, remote_base, image_local.data(),
                            image_size, &written) || written != image_size) {
        res.win32_error   = GetLastError();
        res.error_message = "WriteProcessMemory image: " +
                             last_error_message(res.win32_error);
        VirtualFreeEx(proc, remote_base, 0, MEM_RELEASE);
        CloseHandle(proc);
        return res;
    }

    // 5. Build a small shellcode that calls our DllMain-style entry
    //    with (DLL_PROCESS_ATTACH), then returns to the hijacked
    //    thread's original RIP.
    uint32_t tid = find_hijack_candidate(pid);
    if (!tid) {
        res.error_message = "no hijack candidate thread";
        VirtualFreeEx(proc, remote_base, 0, MEM_RELEASE);
        CloseHandle(proc);
        return res;
    }

    // Snapshot the thread's RIP so the shellcode can restore it
    HANDLE th = OpenThread(THREAD_GET_CONTEXT | THREAD_SUSPEND_RESUME,
                           FALSE, tid);
    if (!th) {
        res.win32_error = GetLastError();
        res.error_message = "OpenThread: " + last_error_message(res.win32_error);
        VirtualFreeEx(proc, remote_base, 0, MEM_RELEASE);
        CloseHandle(proc);
        return res;
    }
    SuspendThread(th);
    CONTEXT ctx{}; ctx.ContextFlags = CONTEXT_CONTROL;
    GetThreadContext(th, &ctx);
    uint64_t saved_rip = ctx.Rip;
    ResumeThread(th);
    CloseHandle(th);

    void* remote_entry = (uint8_t*)remote_base + pe::entry_rva(pe);
    Shellcode sc = build_call_and_return_shellcode(remote_entry,
                                                    /*arg*/ remote_base,
                                                    saved_rip);
    void* remote_sc = VirtualAllocEx(proc, nullptr, sc.size,
                                     MEM_COMMIT | MEM_RESERVE,
                                     PAGE_EXECUTE_READWRITE);
    if (!remote_sc) {
        res.win32_error = GetLastError();
        res.error_message = "VirtualAllocEx (sc): " +
                             last_error_message(res.win32_error);
        VirtualFreeEx(proc, remote_base, 0, MEM_RELEASE);
        CloseHandle(proc);
        return res;
    }
    WriteProcessMemory(proc, remote_sc, sc.bytes, sc.size, &written);

    // 6. Hijack the candidate thread to jump to our shellcode
    if (!hijack_and_jump(tid, remote_sc)) {
        res.error_message = "thread hijack failed";
        VirtualFreeEx(proc, remote_sc,   0, MEM_RELEASE);
        VirtualFreeEx(proc, remote_base, 0, MEM_RELEASE);
        CloseHandle(proc);
        return res;
    }

    res.ok          = true;
    res.module_base = remote_base;
    CloseHandle(proc);
    return res;
}

}  // namespace rogblox
