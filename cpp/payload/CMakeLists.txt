add_library(rogblox-payload SHARED
    dllmain.cpp
    scanner/signatures.cpp
    scanner/scheduler.cpp
    bridge/luau_bridge.cpp
    bridge/identity.cpp
    api/closures.cpp
    api/filesystem.cpp
    api/instances.cpp
    api/drawing.cpp
    api/input.cpp
)

target_include_directories(rogblox-payload PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/shared
)

# Win32 libraries used by the payload
target_link_libraries(rogblox-payload PRIVATE
    user32.lib
    d3d11.lib
    d2d1.lib
    dwrite.lib
)

set_target_properties(rogblox-payload PROPERTIES
    OUTPUT_NAME "rogblox-payload"
    PREFIX ""
)
