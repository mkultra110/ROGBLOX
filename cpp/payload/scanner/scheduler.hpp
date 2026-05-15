// Roblox task scheduler discovery.
//
// The task scheduler is the heart of Roblox's per-frame execution.
// Finding it gives us access to every running script via the job
// list, and from there we can locate the global lua_State*.
//
// Discovery pattern (per Luau Internals 101 + RbxStu V3 Scanner.cpp):
//   1. AOB scan for a string only the scheduler uses ("ClusterScheduler"
//      or "TaskScheduler::run").
//   2. From that string, find the nearest function that references it.
//   3. That function returns the scheduler pointer.

#pragma once

#include <cstdint>

namespace rogblox::scanner {

// Returns a pointer to the Roblox task scheduler, or nullptr if not
// found. Cached on first success.
void* find_scheduler();

}  // namespace rogblox::scanner
