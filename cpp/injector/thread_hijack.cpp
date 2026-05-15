#include "thread_hijack.hpp"

#include <TlHelp32.h>
#include <cstring>
#include <cstdio>
#include <vector>

namespace rogblox {

uint32_t find_hijack_candidate(uint32_t pid) {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    if (snap == INVALID_HANDLE_VALUE) return 0;

    THREADENTRY32 entry{};
    entry.dwSize = sizeof(entry);
    uint32_t found = 0;

    if (Thread32First(snap, &entry)) {
        do {
            if (entry.th32OwnerProcessID != pid) continue;
            HANDLE th = OpenThread(THREAD_GET_CONTEXT | THREAD_SET_CONTEXT |
                                   THREAD_SUSPEND_RESUME | THREAD_QUERY_INFORMATION,
                                   FALSE, entry.th32ThreadID);
            if (!th) continue;
            // Looks usable. Roblox has many worker threads; the first
            // candidate is usually a render or job-pool worker.
            CloseHandle(th);
            found = entry.th32ThreadID;
            break;
        } while (Thread32Next(snap, &entry));
    }
    CloseHandle(snap);
    return found;
}

Shellcode build_call_and_return_shellcode(void* entry, void* argument,
                                          uint64_t saved_rip) {
    // x64 shellcode:
    //   mov  rcx, <argument>
    //   mov  rax, <entry>
    //   sub  rsp, 0x28        ; shadow space + alignment
    //   call rax
    //   add  rsp, 0x28
    //   mov  rax, <saved_rip>
    //   jmp  rax
    //
    // 48 B9 XX XX XX XX XX XX XX XX   mov rcx, imm64
    // 48 B8 XX XX XX XX XX XX XX XX   mov rax, imm64
    // 48 83 EC 28                     sub rsp, 28h
    // FF D0                            call rax
    // 48 83 C4 28                      add rsp, 28h
    // 48 B8 XX XX XX XX XX XX XX XX    mov rax, imm64
    // FF E0                            jmp rax
    static thread_local std::vector<uint8_t> buf;
    buf.clear();

    auto emit_u8  = [&](uint8_t v)  { buf.push_back(v); };
    auto emit_u64 = [&](uint64_t v) {
        for (int i = 0; i < 8; ++i) buf.push_back((uint8_t)((v >> (i * 8)) & 0xFF));
    };

    // mov rcx, argument
    emit_u8(0x48); emit_u8(0xB9); emit_u64((uint64_t)argument);
    // mov rax, entry
    emit_u8(0x48); emit_u8(0xB8); emit_u64((uint64_t)entry);
    // sub rsp, 0x28
    emit_u8(0x48); emit_u8(0x83); emit_u8(0xEC); emit_u8(0x28);
    // call rax
    emit_u8(0xFF); emit_u8(0xD0);
    // add rsp, 0x28
    emit_u8(0x48); emit_u8(0x83); emit_u8(0xC4); emit_u8(0x28);
    // mov rax, saved_rip
    emit_u8(0x48); emit_u8(0xB8); emit_u64(saved_rip);
    // jmp rax
    emit_u8(0xFF); emit_u8(0xE0);

    return {buf.data(), buf.size()};
}

bool hijack_and_jump(uint32_t tid, void* remote_shellcode) {
    HANDLE th = OpenThread(THREAD_GET_CONTEXT | THREAD_SET_CONTEXT |
                           THREAD_SUSPEND_RESUME, FALSE, tid);
    if (!th) return false;

    if (SuspendThread(th) == (DWORD)-1) {
        CloseHandle(th); return false;
    }

    CONTEXT ctx{};
    ctx.ContextFlags = CONTEXT_CONTROL | CONTEXT_INTEGER;
    if (!GetThreadContext(th, &ctx)) {
        ResumeThread(th); CloseHandle(th); return false;
    }

    // Save the real RIP - the shellcode jumps back here when our entry
    // returns. (We assume the caller built the shellcode with this RIP
    // already baked in.)
    ctx.Rip = (DWORD64)remote_shellcode;
    if (!SetThreadContext(th, &ctx)) {
        ResumeThread(th); CloseHandle(th); return false;
    }

    ResumeThread(th);
    CloseHandle(th);
    return true;
}

}  // namespace rogblox
