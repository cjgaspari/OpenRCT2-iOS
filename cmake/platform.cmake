# Helpers for linking platform specific libraries

function(target_link_platform_libraries target)

if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
    # iOS uses UIKit instead of Cocoa
    target_link_libraries(${target} "-framework UIKit -framework Foundation -framework CoreFoundation -framework CoreText")
elseif (APPLE)
    target_link_libraries(${target} "-framework Cocoa -framework CoreServices")
elseif(WIN32)
    target_link_libraries(${target} gdi32)
endif ()

endfunction()
