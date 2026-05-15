# Build the C++ loader: rogblox-loader.exe
# Bundles dist/rogblox.lua as a Windows RC RESOURCE - compiled by
# rc.exe in milliseconds, no Python or codegen at build time.

set(BUNDLE_LUA "${CMAKE_SOURCE_DIR}/../dist/rogblox.lua")

if(NOT EXISTS "${BUNDLE_LUA}")
    message(FATAL_ERROR
        "Lua bundle not found: ${BUNDLE_LUA}\n"
        "Run 'python bundle.py' from the repo root first, or use build-exe.bat / the CI workflow which does it for you.")
endif()

# RC compiler interprets relative paths from the working dir, not the
# .rc file's dir. Generate a bundle.rc with the absolute path baked
# in so it always resolves correctly.
file(TO_NATIVE_PATH "${BUNDLE_LUA}" BUNDLE_LUA_NATIVE)
string(REPLACE "\\" "\\\\" BUNDLE_LUA_RC "${BUNDLE_LUA_NATIVE}")
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/bundle.rc.in"
    "${CMAKE_CURRENT_BINARY_DIR}/bundle.rc"
    @ONLY
)

add_executable(rogblox-loader WIN32
    main.cpp
    "${CMAKE_CURRENT_BINARY_DIR}/bundle.rc"
)

target_include_directories(rogblox-loader PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
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
    msimg32.lib
    comctl32.lib
)

set_target_properties(rogblox-loader PROPERTIES
    OUTPUT_NAME "rogblox-loader"
)
