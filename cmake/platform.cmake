# Helpers for linking platform specific libraries

function(target_link_platform_libraries target)

if (OPENRCT2_IOS)
    target_link_libraries(${target} "-framework CoreText" "-framework Foundation" "-framework UIKit")
elseif (OPENRCT2_MACOS)
    target_link_libraries(${target} "-framework Cocoa -framework CoreServices")
elseif(WIN32)
    target_link_libraries(${target} gdi32)
endif ()

endfunction()
