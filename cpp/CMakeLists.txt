cmake_minimum_required(VERSION 3.20)
project(rogblox_cpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT WIN32)
    message(FATAL_ERROR "ROGBLOX C++ is Windows-only (manual-map injection + Roblox client are Win64).")
endif()

# Both subprojects build the same way; share a few hardening flags.
add_compile_options(
    /W4         # warnings
    /permissive-
    /Zc:__cplusplus
    /utf-8
    $<$<CONFIG:Release>:/O2>
)
add_compile_definitions(
    _WIN32_WINNT=0x0A00
    NOMINMAX
    WIN32_LEAN_AND_MEAN
)

add_subdirectory(injector)
add_subdirectory(payload)

message(STATUS "ROGBLOX C++ configured. Build: cmake --build build --config Release")
