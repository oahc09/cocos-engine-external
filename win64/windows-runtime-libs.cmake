# Collects the installed VC++ runtime and UCRT DLLs for the selected toolchain
# into <out-var>, using CMake's official InstallRequiredSystemLibraries
# module for discovery (Visual Studio redist + Windows SDK; no machine-specific
# paths or versions are hardcoded here).
#
# Background: the legacy pinned tree external/win64/libs/msvcr ships a 14.29 CRT
# while actively used toolsets are newer; loading that stale msvcp140/ucrtbase
# next to freshly linked binaries crashes at startup (observed as
# std::mutex::lock inside glslang::InitializeProcess). Runtime DLLs must
# therefore always come from the toolchain's own redist/SDK, never from the
# pinned external copy.
#
# The function is deliberately scoped: CMAKE_INSTALL_SYSTEM_RUNTIME_* knobs are
# set locally, no install() rules are produced (SKIP=TRUE), and the caller's
# directory scope is left unchanged. Both release and debug CRT variants are
# collected, matching the previous all-config copy behavior.
function(cc_windows_collect_runtime_dlls out_var)
    set(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP TRUE)
    set(CMAKE_INSTALL_DEBUG_LIBRARIES TRUE)
    set(CMAKE_INSTALL_DEBUG_LIBRARIES_ONLY FALSE)
    set(CMAKE_INSTALL_UCRT_LIBRARIES TRUE)
    set(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS "")
    include(InstallRequiredSystemLibraries)
    if(NOT CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS)
        message(FATAL_ERROR
            "cc_windows_collect_runtime_dlls: InstallRequiredSystemLibraries found no runtime DLLs "
            "(toolset='${CMAKE_VS_PLATFORM_TOOLSET}', compiler='${CMAKE_CXX_COMPILER}'). "
            "Install the matching VC++ redistributable / Windows SDK; do NOT fall back to "
            "external/win64/libs/msvcr, whose pinned 14.29 CRT is incompatible with newer toolsets.")
    endif()
    # The official module warns and skips individual missing DLLs. A partially
    # populated result would leave stale app-local DLLs in an existing build.
    set(runtime_names "")
    foreach(runtime_dll IN LISTS CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS)
        get_filename_component(runtime_name "${runtime_dll}" NAME)
        list(APPEND runtime_names "${runtime_name}")
    endforeach()
    set(required_runtime_names ucrtbase.dll ucrtbased.dll)
    if(MSVC_VERSION GREATER_EQUAL 1900)
        list(APPEND required_runtime_names
            msvcp140.dll msvcp140d.dll vcruntime140.dll vcruntime140d.dll)
    endif()
    foreach(runtime_name IN LISTS required_runtime_names)
        if(NOT runtime_name IN_LIST runtime_names)
            message(FATAL_ERROR
                "Missing toolchain runtime '${runtime_name}'. Install the VC++ release/debug "
                "runtime and Windows SDK components; stale external CRT DLLs are not a fallback.")
        endif()
    endforeach()
    set(${out_var} "${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS}" PARENT_SCOPE)
endfunction()
