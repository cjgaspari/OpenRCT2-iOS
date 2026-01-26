set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_CMAKE_SYSTEM_VERSION 2.0)
set(VCPKG_ENV_PASSTHROUGH PATH)
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/../../../cmake/visionos-simulator.toolchain.cmake")

# visionOS Simulator specific settings
set(VCPKG_C_FLAGS "-fPIC -Qunused-arguments")
set(VCPKG_CXX_FLAGS "-fPIC -Qunused-arguments")
