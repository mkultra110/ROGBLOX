#include "scheduler.hpp"
#include "signatures.hpp"

#include <atomic>

namespace rogblox::scanner {

static std::atomic<void*> g_cache{nullptr};

void* find_scheduler() {
    void* cached = g_cache.load(std::memory_order_acquire);
    if (cached) return cached;

    // Strategy 1: find a known scheduler-only string and walk to the
    // nearest call. Strings that have historically appeared near the
    // scheduler: "ClusterScheduler", "TaskScheduler", "FrameTime".
    // Real production cheats maintain a fallback chain of multiple
    // signatures so one Roblox update doesn't break attach.
    const char* candidates[] = {
        "ClusterScheduler",
        "TaskScheduler",
        "FrameTime",
        nullptr,
    };

    for (int i = 0; candidates[i]; ++i) {
        uint8_t* s = find_string(candidates[i], nullptr);
        if (!s) continue;

        // From the string's address, scan up to 256 bytes for a call.
        // The first call after the string-load typically targets the
        // scheduler factory.
        uint8_t* tgt = nearest_call_target(s + std::strlen(candidates[i]), 0x100);
        if (tgt) {
            // For a real implementation, you'd invoke the factory and
            // get back the scheduler pointer. Here we just stash the
            // function address as a placeholder so the rest of the
            // pipeline can be exercised.
            g_cache.store(tgt, std::memory_order_release);
            return tgt;
        }
    }
    return nullptr;
}

}  // namespace rogblox::scanner
