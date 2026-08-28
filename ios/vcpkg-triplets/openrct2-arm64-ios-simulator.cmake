set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME iOS)
set(VCPKG_OSX_SYSROOT iphonesimulator)
set(VCPKG_OSX_DEPLOYMENT_TARGET 15.0)

# See openrct2-arm64-ios.cmake. The SDK distinguishes this Simulator slice;
# the explicit host/build tuples keep Autoconf in cross-compilation mode.
set(VCPKG_MAKE_BUILD_TRIPLET "--host=aarch64-apple-ios;--build=aarch64-apple-darwin")
set(VCPKG_MAKE_CONFIGURE_OPTIONS "icu_cv_host_frag=mh-darwin")
