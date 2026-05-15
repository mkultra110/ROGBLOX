#include "signatures.hpp"

#include <Windows.h>
#include <Psapi.h>
#include <cstring>

namespace rogblox::scanner {

// Parse a hex pair like "48" or "??" into (byte, is_wildcard).
static bool parse_pair(const char* s, uint8_t& byte_out, bool& wildcard_out) {
    if (s[0] == '?') {
        wildcard_out = true;
        byte_out = 0;
        return true;
    }
    auto hex = [](char c) -> int {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        if (c >= 'A' && c <= 'F') return c - 'A' + 10;
        return -1;
    };
    int hi = hex(s[0]), lo = hex(s[1]);
    if (hi < 0 || lo < 0) return false;
    byte_out = (uint8_t)((hi << 4) | lo);
    wildcard_out = false;
    return true;
}

static void parse_pattern(const char* pattern,
                          std::vector<uint8_t>& bytes,
                          std::vector<bool>& wildcards) {
    while (*pattern) {
        while (*pattern == ' ') ++pattern;
        if (!*pattern) break;
        if (pattern[0] == '?' && pattern[1] == '?') {
            bytes.push_back(0);
            wildcards.push_back(true);
            pattern += 2;
        } else {
            uint8_t b = 0; bool w = false;
            if (!parse_pair(pattern, b, w)) return;
            bytes.push_back(b);
            wildcards.push_back(w);
            pattern += 2;
        }
    }
}

static void module_range(void* hint, uint8_t*& start, size_t& size) {
    HMODULE hmod = hint ? (HMODULE)hint : GetModuleHandle(nullptr);
    MODULEINFO mi{};
    if (GetModuleInformation(GetCurrentProcess(), hmod, &mi, sizeof(mi))) {
        start = (uint8_t*)mi.lpBaseOfDll;
        size  = mi.SizeOfImage;
    } else {
        start = (uint8_t*)hmod;
        size  = 0x10000000;  // 256 MB fallback
    }
}

uint8_t* find_pattern(const char* pattern, void* base, size_t size) {
    std::vector<uint8_t> bytes;
    std::vector<bool>    wildcards;
    parse_pattern(pattern, bytes, wildcards);
    if (bytes.empty()) return nullptr;

    uint8_t* start; size_t span;
    if (base && size) { start = (uint8_t*)base; span = size; }
    else              { module_range(nullptr, start, span); }

    size_t plen = bytes.size();
    if (span < plen) return nullptr;
    for (size_t i = 0; i + plen <= span; ++i) {
        bool match = true;
        for (size_t j = 0; j < plen; ++j) {
            if (wildcards[j]) continue;
            if (start[i + j] != bytes[j]) { match = false; break; }
        }
        if (match) return start + i;
    }
    return nullptr;
}

uint8_t* find_string(const char* needle, void* module_base) {
    uint8_t* start; size_t size;
    module_range(module_base, start, size);
    size_t nlen = std::strlen(needle);
    for (size_t i = 0; i + nlen + 1 <= size; ++i) {
        if (std::memcmp(start + i, needle, nlen) == 0 &&
            start[i + nlen] == '\0') {
            return start + i;
        }
    }
    return nullptr;
}

uint8_t* nearest_call_target(uint8_t* start, size_t max_scan) {
    for (size_t i = 0; i < max_scan; ++i) {
        // E8 rel32: call near
        if (start[i] == 0xE8) {
            int32_t rel = *(int32_t*)&start[i + 1];
            return start + i + 5 + rel;
        }
        // E9 rel32: jmp near
        if (start[i] == 0xE9) {
            int32_t rel = *(int32_t*)&start[i + 1];
            return start + i + 5 + rel;
        }
    }
    return nullptr;
}

}  // namespace rogblox::scanner
