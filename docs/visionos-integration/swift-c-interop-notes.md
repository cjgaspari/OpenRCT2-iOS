# Improving C library usability in Swift (Swift.org blog)

- Goal: project C headers into safer, more Swifty APIs using module maps, API notes, and bridging annotations—without changing the C implementation.

## Setup: module map and package layout

```
├── Package.swift
└── Sources
    └── WebGPU
        ├── include
        │   ├── webgpu.h
        │   └── module.modulemap
        └── WebGPU.c   // empty source to satisfy SwiftPM
```

`module.modulemap`:

```
module WebGPU {
  header "webgpu.h"
  export *
}
```

Import from Swift with `import WebGPU`.

## Inspecting the synthesized Swift interface

Use Swift 6.2+ tool to see how C maps into Swift:

```
xcrun swift-synthesize-interface -I . -module-name WebGPU \
  -target arm64-apple-macos15 \
  -sdk /Applications/Xcode.app/.../MacOSX26.0.sdk
```

## Enums: turn C enums into Swift enums

C:

```c
typedef enum {
  WGPUAdapterType_DiscreteGPU = 0x1,
  WGPUAdapterType_IntegratedGPU = 0x2,
  WGPUAdapterType_CPU = 0x3,
  WGPUAdapterType_Unknown = 0x4,
  WGPUAdapterType_Force32 = 0x7FFFFFFF
} WGPUAdapterType;
```

API notes:

```
Tags:
- Name: WGPUAdapterType
  EnumExtensibility: closed
```

Swift result:

```swift
@frozen public enum WGPUAdapterType: UInt32 {
  case discreteGPU = 1
  case integratedGPU = 2
  case CPU = 3
  case unknown = 4
  case force32 = 2147483647
}
```

## Reference-counted object types → Swift classes

C:

```c
typedef struct WGPUBindGroupImpl* WGPUBindGroup;
WGPU_EXPORT void wgpuBindGroupAddRef(WGPUBindGroup);
WGPU_EXPORT void wgpuBindGroupRelease(WGPUBindGroup);
```

API notes:

```
Tags:
- Name: WGPUBindGroupImpl
  SwiftImportAs: reference
  SwiftRetainOp: wgpuBindGroupAddRef
  SwiftReleaseOp: wgpuBindGroupRelease
```

Swift result: `WGPUBindGroupImpl` imports as a class; retains/releases are automatic.

If a factory returns ownership:

```
Functions:
- Name: wgpuDeviceCreateBindGroup
  SwiftReturnOwnership: retained
```

## Functions: methods, properties, initializers, labeled params

- Import as method:

```
Functions:
- Name: wgpuQueueWriteBuffer
  SwiftName: WGPUQueueImpl.writeBuffer(self:buffer:bufferOffset:data:size:)
```

Swift:

```swift
extension WGPUQueueImpl {
  func writeBuffer(buffer: WGPUBuffer!, bufferOffset: UInt64, data: UnsafeRawPointer!, size: Int)
}
```

- Import as property getters:

```
Functions:
- Name: wgpuQuerySetGetCount
  SwiftName: getter:WGPUQuerySetImpl.count(self:)
- Name: wgpuQuerySetGetType
  SwiftName: getter:WGPUQuerySetImpl.type(self:)
```

Swift:

```swift
extension WGPUQuerySetImpl {
  var count: UInt32 { get }
  var type: WGPUQueryType { get }
}
```

- Import constructors as initializers:

```
Functions:
- Name: wgpuCreateInstance
  SwiftReturnOwnership: retained
  SwiftName: WGPUInstanceImpl.init(descriptor:)
```

Swift:

```swift
let instance = WGPUInstance(descriptor: &desc)
```

- Add argument labels without changing C:

```
Functions:
- Name: wgpuQueueWriteBuffer
  SwiftName: wgpuQueueWriteBuffer(_:buffer:bufferOffset:data:size:)
```

Call site gains clarity:

```swift
wgpuQueueWriteBuffer(queue, buffer: buf, bufferOffset: 0, data: ptr, size: len)
```

## Custom booleans and option sets

- Wrap custom bools:

```
Typedefs:
- Name: WGPUBool
  SwiftWrapper: struct
```

Swift extension to allow literals:

```swift
extension WGPUBool: ExpressibleByBooleanLiteral {
  init(booleanLiteral value: Bool) { self.init(rawValue: value ? 1 : 0) }
}
```

- Wrap flags as option sets:

```
Typedefs:
- Name: WGPUBufferUsage
  SwiftWrapper: struct
  SwiftConformsTo: Swift.OptionSet

Globals:
- Name: WGPUBufferUsage_MapRead
  SwiftName: WGPUBufferUsage.mapRead
- Name: WGPUBufferUsage_MapWrite
  SwiftName: WGPUBufferUsage.mapWrite
```

Swift:

```swift
let usage: WGPUBufferUsage = [.mapRead, .mapWrite]
```

## Nullability cleanup

```
Functions:
- Name: wgpuCreateInstance
  SwiftReturnOwnership: retained
  SwiftName: WGPUInstanceImpl.init(descriptor:)
  Parameters:
  - Position: 0
    Nullability: O   # optional
  ResultType: "WGPUInstance _Nonnull"
```

Swift result: `init(descriptor: UnsafePointer<WGPUInstanceDescriptor>?)` returning non-optional instance—no implicitly unwrapped optionals.

## Automating API notes

- Large headers can be post-processed (regex or libclang) to emit `.apinotes` that add enum extensibility, reference types, Swift names, nullability, and option-set conformances. Example script loops over `webgpu.h` patterns and prints `WebGPU.apinotes`.

## Outcome

- Swift projections gain enums, classes with ARC, labeled methods/properties/inits, option sets, and proper nullability—yielding Swifty ergonomics while keeping the C library untouched.
