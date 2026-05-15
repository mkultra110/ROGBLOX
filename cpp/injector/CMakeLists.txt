add_executable(rogblox-inject
    main.cpp
    injector.cpp
    pe_loader.cpp
    thread_hijack.cpp
)

target_include_directories(rogblox-inject PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# Link Win32 libraries used by the injector
target_link_libraries(rogblox-inject PRIVATE
    psapi.lib
    advapi32.lib
)

set_target_properties(rogblox-inject PROPERTIES
    OUTPUT_NAME "rogblox-inject"
)
