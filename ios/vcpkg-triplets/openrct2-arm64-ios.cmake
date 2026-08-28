set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME iOS)
set(VCPKG_OSX_DEPLOYMENT_TARGET 15.0)

# vcpkg's community arm64-ios triplet reports both the arm64 macOS build host
# and arm64 iOS target as aarch64-apple-darwin. Autoconf then tries to execute
# target binaries. Use ICU's accepted iOS tuple to make the cross-build
# explicit while preserving the SDK and compiler selected by vcpkg.
set(VCPKG_MAKE_BUILD_TRIPLET "--host=aarch64-apple-ios;--build=aarch64-apple-darwin")
set(VCPKG_MAKE_CONFIGURE_OPTIONS "icu_cv_host_frag=mh-darwin")
