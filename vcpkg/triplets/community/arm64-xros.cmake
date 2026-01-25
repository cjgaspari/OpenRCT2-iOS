set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME xros)
set(VCPKG_CMAKE_SYSTEM_VERSION 2.0)
set(VCPKG_ENV_PASSTHROUGH PATH)

# visionOS/xrOS specific settings
set(VCPKG_C_FLAGS "-mmacosx-version-min=13.5 -fPIC")
set(VCPKG_CXX_FLAGS "-mmacosx-version-min=13.5 -fPIC")
