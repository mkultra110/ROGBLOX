// Per-Roblox-build internal offsets.
//
// THESE CHANGE EVERY ROBLOX UPDATE. Production executors maintain
// a dump tool that regenerates these on every release. The values
// here are placeholders and serve only to keep the skeleton compiling
// — they will not match any specific Roblox build.
//
// Source patterns for keeping these fresh:
//   - TaaprWareV2's Addresses.cpp (archived but illustrative)
//   - RbxStu V3's Scanner.cpp signatures
//   - Pixeluted/HyperionDumper for dumping the decrypted module first
//
// Best practice for production: load these from a JSON manifest
// keyed by Roblox client version (game.PlaceVersion-equivalent) and
// re-validate via AOB scan on attach.

#pragma once

#include <cstdint>

namespace rogblox::offsets {

// DataModel signature - the chunk of bytes we scan for in
// RobloxPlayerBeta.exe to find the DataModel singleton.
//
// "DataModel" appears as a string near a known function. AOB scans
// look for that string then walk to the nearest call.
constexpr const char* k_datamodel_string = "DataModel";

// TaskScheduler offsets from the DataModel base
constexpr uintptr_t k_dm_to_scheduler   = 0x1F0;   // placeholder
constexpr uintptr_t k_scheduler_to_jobs = 0x140;   // placeholder

// LuaState offsets within a job entry
constexpr uintptr_t k_job_to_lua_state  = 0x90;    // placeholder

// Thread identity field offset inside lua_State extra space
constexpr uintptr_t k_state_identity    = 0x18;    // placeholder

// Scan range hints
constexpr uintptr_t k_text_scan_start   = 0x1000;
constexpr uintptr_t k_text_scan_max     = 0x4000000;  // 64 MB worst case

}  // namespace rogblox::offsets
