// Thread hijacking primitive for stealthier remote execution.
// Used instead of CreateRemoteThread, which Hyperion hooks via the
// NtCreateThreadEx instrumentation callback.
//
// We pick a Roblox worker thread, suspend it, swap RIP to point at a
// shellcode stub in remote memory that calls our entry point, then
// restore the saved RIP so the victim thread continues normally.

#pragma once

#include <Windows.h>
#include <cstdint>

namespace rogblox {

// Returns the TID of a thread inside `pid` that's currently in user-mode
// and looks safe to hijack. Returns 0 on failure.
uint32_t find_hijack_candidate(uint32_t pid);

// Build a small shellcode that:
//   - pushes the saved RIP
//   - calls `entry` with arg `argument`
//   - returns to the saved RIP (via the pushed value)
// Returns the bytes; caller VirtualAllocEx's a remote page, writes the
// shellcode there, and points the hijacked thread at it.
struct Shellcode {
    uint8_t* bytes;
    size_t   size;
};
Shellcode build_call_and_return_shellcode(void* entry, void* argument,
                                          uint64_t saved_rip);

// Performs the full hijack dance: opens the thread, suspends, swaps
// RIP to `remote_shellcode`, resumes. Returns true on success.
bool hijack_and_jump(uint32_t tid, void* remote_shellcode);

}  // namespace rogblox
