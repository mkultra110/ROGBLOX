# Build the C++ loader: rogblox-loader.exe
# Bundles the Lua script as an embedded byte array at build time so
# the .exe is fully self-contained (no external files needed).

set(BUNDLE_LUA "${CMAKE_SOURCE_DIR}/../dist/rogblox.lua")
set(BUNDLE_HPP "${CMAKE_CURRENT_BINARY_DIR}/bundle_data.hpp")
set(BUNDLE_CPP "${CMAKE_CURRENT_BINARY_DIR}/bundle_data.cpp")
set(EMBED_PY   "${CMAKE_CURRENT_SOURCE_DIR}/embed_bundle.py")

if(NOT EXISTS "${BUNDLE_LUA}")
    message(FATAL_ERROR
        "Lua bundle not found: ${BUNDLE_LUA}\n"
        "Run 'python bundle.py' from the repo root first, or use build-exe.bat which does it for you.")
endif()

# Write the header once - it never changes
file(WRITE "${BUNDLE_HPP}"
"#pragma once
#include <cstddef>
extern \"C\" {
extern const unsigned char ROGBLOX_BUNDLE[];
extern const size_t        ROGBLOX_BUNDLE_SIZE;
}
")

# Locate a Python interpreter for the embedding step
find_package(Python3 COMPONENTS Interpreter QUIET)
if(NOT Python3_EXECUTABLE)
    # Fall back to plain `python` on PATH (windows-latest has it)
    find_program(Python3_EXECUTABLE NAMES python3 python REQUIRED)
endif()

# Generate the embedded bundle .cpp via a custom command that re-runs
# whenever the bundle changes. Tied as a source dep of the loader target.
add_custom_command(
    OUTPUT  "${BUNDLE_CPP}"
    COMMAND "${Python3_EXECUTABLE}" "${EMBED_PY}" "${BUNDLE_LUA}" "${BUNDLE_CPP}"
    DEPENDS "${BUNDLE_LUA}" "${EMBED_PY}"
    COMMENT "Embedding ${BUNDLE_LUA} into bundle_data.cpp"
    VERBATIM
)

add_executable(rogblox-loader WIN32
    main.cpp
    "${BUNDLE_CPP}"
)

target_include_directories(rogblox-loader PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}
)

target_link_libraries(rogblox-loader PRIVATE
    gdiplus.lib
    shlwapi.lib
    shell32.lib
    user32.lib
    gdi32.lib
    dwmapi.lib
    ole32.lib
    advapi32.lib
    winhttp.lib
    msimg32.lib
    comctl32.lib
)

set_target_properties(rogblox-loader PROPERTIES
    OUTPUT_NAME "rogblox-loader"
)
