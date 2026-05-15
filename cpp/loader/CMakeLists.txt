# Build the C++ loader: rogblox-loader.exe
# Bundles the Lua script as an embedded byte array at build time so
# the .exe is fully self-contained (no external files needed).

# Step 1: convert dist/rogblox.lua to a C array at configure time.
set(BUNDLE_LUA "${CMAKE_SOURCE_DIR}/../dist/rogblox.lua")
set(BUNDLE_OUT "${CMAKE_CURRENT_BINARY_DIR}/bundle_data.cpp")

# CMake -E lets us write a tiny inline script that reads the lua file
# and emits a C++ source with the bytes as a literal initializer.
file(READ "${BUNDLE_LUA}" BUNDLE_HEX HEX)
string(LENGTH "${BUNDLE_HEX}" BUNDLE_HEXLEN)
math(EXPR BUNDLE_BYTES "${BUNDLE_HEXLEN} / 2")

# Generate a header + source with the embedded bytes
set(BUNDLE_HEADER "${CMAKE_CURRENT_BINARY_DIR}/bundle_data.hpp")
file(WRITE "${BUNDLE_HEADER}"
"#pragma once
#include <cstddef>
extern \"C\" {
extern const unsigned char ROGBLOX_BUNDLE[];
extern const size_t        ROGBLOX_BUNDLE_SIZE;
}
")

# Build the .cpp by chunking the hex string into 16-byte lines so the
# resulting source compiles in reasonable time.
set(BUNDLE_SRC "#include \"bundle_data.hpp\"\nextern \"C\" const unsigned char ROGBLOX_BUNDLE[] = {\n")
set(_idx 0)
set(_line "    ")
math(EXPR _last_idx "${BUNDLE_BYTES} - 1")
while(_idx LESS BUNDLE_BYTES)
    math(EXPR _pos "${_idx} * 2")
    string(SUBSTRING "${BUNDLE_HEX}" ${_pos} 2 _byte)
    set(_line "${_line}0x${_byte},")
    math(EXPR _idx "${_idx} + 1")
    math(EXPR _mod "${_idx} % 16")
    if(_mod EQUAL 0 OR _idx EQUAL BUNDLE_BYTES)
        set(BUNDLE_SRC "${BUNDLE_SRC}${_line}\n")
        set(_line "    ")
    endif()
endwhile()
set(BUNDLE_SRC "${BUNDLE_SRC}};\nextern \"C\" const size_t ROGBLOX_BUNDLE_SIZE = ${BUNDLE_BYTES};\n")
file(WRITE "${BUNDLE_OUT}" "${BUNDLE_SRC}")

add_executable(rogblox-loader WIN32
    main.cpp
    "${BUNDLE_OUT}"
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
)

set_target_properties(rogblox-loader PROPERTIES
    OUTPUT_NAME "rogblox-loader"
)
