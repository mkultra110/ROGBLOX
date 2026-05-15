// PE loader helpers. Parses the DLL's PE headers, walks sections,
// applies base relocations, resolves the import table, and writes
// the result into the target process. Pattern: RMMInject /
// Thorioum's RbxMMap, simplified.

#pragma once

#include <Windows.h>
#include <cstdint>
#include <vector>

namespace rogblox::pe {

struct LoadedPe {
    std::vector<uint8_t> bytes;             // file bytes loaded from disk
    IMAGE_DOS_HEADER*    dos      = nullptr;
    IMAGE_NT_HEADERS64*  nt       = nullptr;
    IMAGE_SECTION_HEADER* sections= nullptr;
};

// Load + validate a DLL from disk into memory. Does no remote work.
bool load_from_file(const wchar_t* path, LoadedPe& out);

// Build the "in-memory image" of the DLL by copying its headers and
// each section into a fresh buffer at the correct VirtualAddress.
// Output buffer must be at least SizeOfImage bytes.
void build_image(const LoadedPe& pe, uint8_t* image_out, size_t image_size);

// Apply base relocations to image_out, fixing addresses for the new
// allocation base (remote_base).
void apply_relocations(const LoadedPe& pe, uint8_t* image_out,
                       uint64_t remote_base);

// Resolve the Import Address Table. We resolve via LoadLibrary +
// GetProcAddress in OUR process, then write the resolved pointers
// into the image buffer at the right IAT slots. The remote process
// must have the same DLLs loaded (a safe assumption for kernel32,
// user32, etc. - which Roblox already imports).
bool resolve_imports(const LoadedPe& pe, uint8_t* image_out);

// Convenience: SizeOfImage from headers.
inline uint32_t size_of_image(const LoadedPe& pe) {
    return pe.nt ? pe.nt->OptionalHeader.SizeOfImage : 0;
}

// Convenience: AddressOfEntryPoint.
inline uint32_t entry_rva(const LoadedPe& pe) {
    return pe.nt ? pe.nt->OptionalHeader.AddressOfEntryPoint : 0;
}

}  // namespace rogblox::pe
