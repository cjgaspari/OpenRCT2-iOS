# Metal-cpp detailed notes

- What it is: header-only C++17 interface mirroring Objective-C Metal APIs under `MTL::`; no wrapper containers or extra allocations; backward-compatible (`supports...()` returns `false` when selectors missing; weak-linked error-domain strings null when absent); same headers across iOS/iPadOS/macOS/tvOS.
- Prereqs: Xcode 9.3+ (C++17), add `metal-cpp/` to header search paths, set C++ language dialect to C++17+, link Foundation + QuartzCore + Metal frameworks.
- Download from https://developer.apple.com/metal/cpp/files/metal-cpp_26.zip

## Minimal setup (one translation unit does the impl)

```cpp
// MetalImplementation.cpp
#define NS_PRIVATE_IMPLEMENTATION
#define CA_PRIVATE_IMPLEMENTATION
#define MTL_PRIVATE_IMPLEMENTATION
#include <Foundation/Foundation.hpp>
#include <QuartzCore/QuartzCore.hpp>
#include <Metal/Metal.hpp>
```

- Only one `.cpp` should define the `*_PRIVATE_IMPLEMENTATION` macros; all other `.cpp` files just `#include` the headers without those defines.

## Using in the rest of the codebase

```cpp
#include <Foundation/Foundation.hpp>
#include <QuartzCore/QuartzCore.hpp>
#include <Metal/Metal.hpp>

int main() {
    using namespace MTL;
    NS::AutoreleasePool* pool = NS::AutoreleasePool::alloc()->init();
    auto device = CreateSystemDefaultDevice();
    auto commandQueue = device->newCommandQueue();
    // ... create buffers, pipelines, etc.
    commandQueue->release();
    device->release();
    pool->release();
}
```

- Names mirror Objective-C Metal; e.g., `MTL::Device::supportsRaytracing()` maps to `[MTLDevice supportsRaytracing]`.

## Single-header option

- Run from the extracted archive to emit a combined include:

```
SingleHeader/MakeSingleHeader.py Foundation/Foundation.hpp QuartzCore/QuartzCore.hpp Metal/Metal.hpp
```

- Use generated `SingleHeader/Metal.hpp`, but still generate the implementation once:

```cpp
#define NS_PRIVATE_IMPLEMENTATION
#define CA_PRIVATE_IMPLEMENTATION
#define MTL_PRIVATE_IMPLEMENTATION
#include <Metal/Metal.hpp>
```

## Memory management considerations

- Follows Cocoa/Cocoa Touch retain/release rules; C++ objects are not ARC-managed.
- Create/destroy via `retain()`/`release()` or use `NS::AutoreleasePool` scopes; avoid double-release.

## Downloads (per SDK)

- `metal-cpp_26.zip`
- `metal-cpp_macOS15.2_iOS18.2.zip`
- `metal-cpp_macOS15_iOS18.zip`
- `metal-cpp_macOS14.2_iOS17.2.zip`
- `metal-cpp_macOS13.3_iOS16.4.zip`
- `metal-cpp_macOS13_iOS16.zip`
