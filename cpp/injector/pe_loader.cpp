#include "pe_loader.hpp"

#include <cstdio>
#include <cstring>
#include <fstream>

namespace rogblox::pe {

bool load_from_file(const wchar_t* path, LoadedPe& out) {
    std::ifstream f(path, std::ios::binary | std::ios::ate);
    if (!f) return false;

    auto size = (std::streamsize)f.tellg();
    if (size < (std::streamsize)sizeof(IMAGE_DOS_HEADER)) return false;
    f.seekg(0, std::ios::beg);

    out.bytes.resize((size_t)size);
    f.read((char*)out.bytes.data(), size);
    if (!f) return false;

    out.dos = (IMAGE_DOS_HEADER*)out.bytes.data();
    if (out.dos->e_magic != IMAGE_DOS_SIGNATURE) return false;

    out.nt = (IMAGE_NT_HEADERS64*)(out.bytes.data() + out.dos->e_lfanew);
    if (out.nt->Signature != IMAGE_NT_SIGNATURE) return false;
    if (out.nt->OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR64_MAGIC) return false;

    out.sections = IMAGE_FIRST_SECTION(out.nt);
    return true;
}

void build_image(const LoadedPe& pe, uint8_t* image_out, size_t image_size) {
    // Copy headers (SizeOfHeaders bytes from the file image)
    std::memcpy(image_out, pe.bytes.data(), pe.nt->OptionalHeader.SizeOfHeaders);

    // Copy each section to its VirtualAddress within image_out
    for (uint16_t i = 0; i < pe.nt->FileHeader.NumberOfSections; ++i) {
        const auto& s = pe.sections[i];
        if (s.SizeOfRawData == 0) continue;
        uint8_t* dst       = image_out + s.VirtualAddress;
        const uint8_t* src = pe.bytes.data() + s.PointerToRawData;
        size_t copy_size   = std::min<size_t>(s.SizeOfRawData, s.Misc.VirtualSize);
        if ((size_t)(dst - image_out) + copy_size > image_size) continue;
        std::memcpy(dst, src, copy_size);
    }
}

void apply_relocations(const LoadedPe& pe, uint8_t* image_out, uint64_t remote_base) {
    const auto& reloc_dir = pe.nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC];
    if (reloc_dir.Size == 0) return;

    int64_t delta = (int64_t)remote_base - (int64_t)pe.nt->OptionalHeader.ImageBase;
    if (delta == 0) return;

    auto* base = (IMAGE_BASE_RELOCATION*)(image_out + reloc_dir.VirtualAddress);
    auto* end  = (IMAGE_BASE_RELOCATION*)((uint8_t*)base + reloc_dir.Size);

    while (base < end && base->SizeOfBlock > 0) {
        uint32_t entries = (base->SizeOfBlock - sizeof(IMAGE_BASE_RELOCATION)) / 2;
        auto* slots = (uint16_t*)(base + 1);
        for (uint32_t i = 0; i < entries; ++i) {
            uint16_t type = slots[i] >> 12;
            uint16_t off  = slots[i] & 0x0FFF;
            if (type == IMAGE_REL_BASED_DIR64) {
                auto* target = (uint64_t*)(image_out + base->VirtualAddress + off);
                *target += (uint64_t)delta;
            }
        }
        base = (IMAGE_BASE_RELOCATION*)((uint8_t*)base + base->SizeOfBlock);
    }
}

bool resolve_imports(const LoadedPe& pe, uint8_t* image_out) {
    const auto& imp_dir = pe.nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
    if (imp_dir.Size == 0) return true;  // nothing to import

    auto* desc = (IMAGE_IMPORT_DESCRIPTOR*)(image_out + imp_dir.VirtualAddress);
    while (desc->Name) {
        const char* dll_name = (const char*)(image_out + desc->Name);
        HMODULE dll = LoadLibraryA(dll_name);
        if (!dll) {
            std::fprintf(stderr, "[pe] LoadLibraryA('%s') failed\n", dll_name);
            return false;
        }

        auto* thunk = (uint64_t*)(image_out +
            (desc->OriginalFirstThunk ? desc->OriginalFirstThunk : desc->FirstThunk));
        auto* iat   = (uint64_t*)(image_out + desc->FirstThunk);
        while (*thunk) {
            FARPROC fn = nullptr;
            if (*thunk & IMAGE_ORDINAL_FLAG64) {
                fn = GetProcAddress(dll, (LPCSTR)(*thunk & 0xFFFF));
            } else {
                auto* name_entry = (IMAGE_IMPORT_BY_NAME*)(image_out + *thunk);
                fn = GetProcAddress(dll, name_entry->Name);
            }
            if (!fn) return false;
            *iat = (uint64_t)fn;
            ++thunk;
            ++iat;
        }
        ++desc;
    }
    return true;
}

}  // namespace rogblox::pe
