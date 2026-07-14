# OpenRCT2 Touch iPad application shell.

if (NOT TARGET SDL2::SDL2main)
    message(FATAL_ERROR "SDL2 did not provide the UIKit SDL2main target")
endif ()

add_executable(openrct2-touch MACOSX_BUNDLE
    "${CMAKE_CURRENT_LIST_DIR}/App/AppLifecycle.iOS.mm"
    "${CMAKE_CURRENT_LIST_DIR}/platform/RCT2Importer.iOS.mm")

target_link_libraries(openrct2-touch PRIVATE
    SDL2::SDL2main
    OpenRCT2::openrct2-ui)
target_link_options(openrct2-touch PRIVATE
    "LINKER:-ObjC"
    "LINKER:-force_load,$<TARGET_FILE:openrct2-ui>"
    "LINKER:-no_warn_duplicate_libraries")

set_target_properties(openrct2-touch PROPERTIES
    OUTPUT_NAME "OpenRCT2Touch"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_LIST_DIR}/App/Info.plist"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED NO
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "2")

add_custom_target(openrct2-touch-stage
    COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${ROOT_DIR}/assets/engine"
        "$<TARGET_BUNDLE_DIR:openrct2-touch>"
    COMMENT "Staging redistributable OpenRCT2 engine assets"
    DEPENDS openrct2-touch)
