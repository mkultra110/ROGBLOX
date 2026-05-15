// AOB (Array Of Bytes) pattern scanning. Used to locate Roblox
// internal functions and data by byte signatures since they don't
// export symbols. Production executors maintain a database of these
// patterns keyed by Roblox version.

#pragma once

#include <cstdint>
#include <vector>

namespace rogblox::scanner {

// Pattern syntax: hex bytes separated by spaces, ?? for wildcards.
//   "48 8B ?? ?? ?? ?? ?? 48 85 C0"
// Returns nullptr if not found.
uint8_t* find_pattern(const char* pattern, void* base = nullptr, size_t size = 0);

// Find a literal C string in the .text or .rdata section of a module.
// Returns a pointer to the start of the string, or nullptr.
uint8_t* find_string(const char* needle, void* module_base = nullptr);

// Walk forward from `start` looking for the next `call` or `jmp`
// instruction, return its target. Used after finding a string to
// locate the function that references it.
uint8_t* nearest_call_target(uint8_t* start, size_t max_scan = 0x200);

}  // namespace rogblox::scanner
