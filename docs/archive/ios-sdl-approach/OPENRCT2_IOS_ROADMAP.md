# OpenRCT2 iOS: Development Roadmap & Task Breakdown

Quick reference guide for implementation. See `OPENRCT2_IOS_INITIATIVE.md` for detailed scope.

---

## Quick Facts

| Aspect | Status |
|--------|--------|
| **SDL→Metal Mandatory?** | ❌ **No** - Optional for Phase 2+ |
| **Core C++ Reuse** | ✅ 100% - No game logic rewrite |
| **MVP Timeline** | 2-3 weeks (if focused) |
| **Skill Requirements** | C++ (basic), Swift, XCode, CMake |
| **Budget Estimate** | ~200 developer hours over 13 weeks |
| **Success Metrics** | Park loads, runs 60 FPS, touch works |

---

## 🎯 Phase 1: Proof-of-Concept (Weeks 1-3)

**Goal**: Get OpenRCT2 rendering to iOS screen at 60 FPS.

### Task Checklist

#### P1.1: Swift Package & Module Setup

- [ ] **P1.1.1** Create SPM package structure
  - Location: `OpenRCT2-iOS/` root
  - Create: `Package.swift`, `Sources/OpenRCT2Core/`, `Sources/OpenRCT2App/`
  - Effort: 30 min
  - Dependencies: None
  - Owner: Lead Developer

- [ ] **P1.1.2** Write `module.modulemap`
  - Location: `Sources/OpenRCT2Core/include/module.modulemap`
  - Expose: `OpenRCT2.h` (public C header)
  - Effort: 15 min
  - Template: See `OPENRCT2_IOS_IMPLEMENTATION_GUIDE.md` Part 1.1
  - Owner: Lead Developer

- [ ] **P1.1.3** Write `OpenRCT2.apinotes` for C→Swift mapping
  - Location: `Sources/OpenRCT2Core/include/OpenRCT2.apinotes`
  - Map: Opaque pointers → Swift classes, return ownership
  - Effort: 30 min
  - Template: See `OPENRCT2_IOS_IMPLEMENTATION_GUIDE.md` Part 1.2
  - Owner: Swift Expert

- [ ] **P1.1.4** Create public C header (`OpenRCT2.h`)
  - Location: `Sources/OpenRCT2Core/include/OpenRCT2.h`
  - Expose minimal API: Create, Initialize, RunFrame, GetFrameBuffer, Destroy
  - Effort: 45 min
  - Template: See `OPENRCT2_IOS_IMPLEMENTATION_GUIDE.md` Part 1.3
  - Owner: Lead Developer + C++ Expert

- [ ] **P1.1.5** Verify SPM can build clean
  - Command: `swift build --product OpenRCT2Core`
  - Should succeed (no runtime yet)
  - Effort: 30 min
  - Owner: Lead Developer

**Subtask Effort**: 2.5 hours  
**Deliverable**: Compiling Swift package with C header imports

---

#### P1.2: C++ Shim Layer

- [ ] **P1.2.1** Create OpenRCT2Shim.cpp wrapper
  - Location: `Sources/OpenRCT2Core/OpenRCT2Shim.cpp`
  - Bridge: Public C API → OpenRCT2 C++ Context class
  - Implement: See `OPENRCT2_IOS_IMPLEMENTATION_GUIDE.md` Part 2
  - Effort: 3 hours
  - Owner: C++ Expert
  - Requires: Understanding of Context.cpp, X8DrawingEngine.cpp

- [ ] **P1.2.2** Implement lifecycle functions
  ```cpp
  OpenRCT2_CreateContext()         // 30 min
  OpenRCT2_Initialize()           // 1 hour (handles subsystem init)
  OpenRCT2_RunFrame()             // 30 min
  OpenRCT2_DestroyContext()       // 15 min
  ```
  - Effort: 2 hours
  - Owner: C++ Expert
  
- [ ] **P1.2.3** Implement buffer access
  ```cpp
  OpenRCT2_GetFrameBuffer()       // 30 min
  OpenRCT2_GetPalette()           // 20 min
  ```
  - Effort: 50 min
  - Owner: C++ Expert
  - Note: Return pointer to X8DrawingEngine's `_bits` buffer + metadata

- [ ] **P1.2.4** Test compilation & linking
  - Link against OpenRCT2 core library (pre-built or CMake)
  - Resolve symbol conflicts
  - Effort: 1.5 hours
  - Owner: Build Engineer

**Subtask Effort**: 7 hours  
**Deliverable**: Compiled C++ shim; can be called from Swift tests

---

#### P1.3: iOS App Shell & Display

- [ ] **P1.3.1** Create AppDelegate & main Swift app structure
  - Location: `Sources/OpenRCT2App/AppDelegate.swift` (or `@main` in SwiftUI)
  - Create: UIWindow, GameViewController, basic navigation
  - Effort: 45 min
  - Owner: iOS Developer
  - Template: See Part 3.3

- [ ] **P1.3.2** Create GameViewController
  - Location: `Sources/OpenRCT2App/GameViewController.swift`
  - Features:
    - MTKView (Metal rendering view)
    - CADisplayLink for 60 FPS updates
    - Auto-layout constraints
  - Effort: 1 hour
  - Owner: iOS Developer
  - Template: See Part 3.2

- [ ] **P1.3.3** Create GameRenderer class
  - Location: `Sources/OpenRCT2App/GameRenderer.swift`
  - Features:
    - Initialize OpenRCT2 context
    - Call `OpenRCT2_RunFrame()` each frame
    - Get frame buffer; upload to Metal texture
    - Render textured quad to screen
  - Effort: 2 hours
  - Owner: Graphics/iOS Developer
  - Complexity: Palette→RGBA conversion, Metal texture setup

- [ ] **P1.3.4** Implement palette-to-RGBA conversion
  - Function: `convertPaletteToRGBA()`
  - Input: `uint8_t* palette8`, `uint8_t* palette` (256×3 RGB)
  - Output: `uint32_t* rgba`
  - Simple loop; later optimize with SIMD
  - Effort: 45 min
  - Owner: Graphics Developer
  - Template: See Part 3.1

- [ ] **P1.3.5** Render to screen via Metal
  - Create MTLTexture from RGBA buffer
  - Simple vertex/fragment shaders (textured quad)
  - Draw to drawable
  - Effort: 2 hours
  - Owner: Graphics/Metal Developer
  - Complexity: Metal API learning curve

- [ ] **P1.3.6** Verify 60 FPS display
  - Use Xcode Instruments (Time Profiler)
  - Target: 55+ FPS on iPhone simulator initially
  - Effort: 1 hour
  - Owner: Performance Engineer

**Subtask Effort**: 7.5 hours  
**Deliverable**: App launches; OpenRCT2 renders to Metal view; 60 FPS target

---

#### P1.4: Integration Testing

- [ ] **P1.4.1** Test on iOS Simulator (iPhone 12/13)
  - Verify no crashes on init
  - Verify frame rendering works
  - Effort: 30 min
  - Owner: QA

- [ ] **P1.4.2** Test on real device (iPhone 12 minimum)
  - Code signing setup
  - Verify performance (may be lower than simulator)
  - Effort: 1 hour
  - Owner: iOS Developer + QA

- [ ] **P1.4.3** Capture demo video/screenshots
  - Show park loading (or title screen)
  - Show frame rate counter
  - Effort: 30 min
  - Owner: Marketing

**Subtask Effort**: 2 hours  
**Deliverable**: Working PoC on device; demo video

---

### 🏁 Phase 1 Success Criteria

- ✅ App launches without crashing
- ✅ OpenRCT2 context initializes
- ✅ Park/scenario loads (or title screen)
- ✅ 60 FPS rendering to screen
- ✅ Stable for 10+ minutes

**Total Phase 1 Effort**: ~20 hours  
**Timeline**: 2-3 weeks (1 developer working ≈ 40 hrs/week)

---

## 🎮 Phase 2: Input & Interaction (Weeks 4-5)

**Goal**: Make park navigable via touch input.

### Task Checklist

#### P2.1: Touch Input Mapping

- [ ] **P2.1.1** Implement `OpenRCT2_SubmitInput()` C function
  - Location: Updated `OpenRCT2Shim.cpp`
  - Handle: mouse move, left/right click, wheel
  - Effort: 1 hour
  - Owner: C++ Expert
  - Reference: Input enum in ShimAPI; SDL mouse event conversion

- [ ] **P2.1.2** Map UIKit touches → game coordinates
  - Location: `GameViewController.swift`
  - Implement `handleTap()`, `handlePan()`
  - Convert screen pixels → game pixels (account for scaling)
  - Effort: 1 hour
  - Owner: iOS Developer

- [ ] **P2.1.3** Implement UIGestureRecognizers
  - Single-finger drag/pan → mouse move + left button
  - Double-tap or two-finger → right click
  - Pinch gesture → zoom (future)
  - Effort: 1.5 hours
  - Owner: iOS Developer

- [ ] **P2.1.4** Test input responsiveness
  - Tap buttons; verify click registered
  - Drag viewport; verify panning works
  - Long press; verify possible
  - Effort: 1 hour
  - Owner: QA

**Subtask Effort**: 4.5 hours  
**Deliverable**: Fully playable via touch; can navigate park

---

#### P2.2: Keyboard Input (Optional for MVP)

- [ ] **P2.2.1** iOS keyboard input
  - Software keyboard for text fields
  - Hardware keyboard support (if available)
  - Effort: 1 hour
  - Owner: iOS Developer
  - Priority: Low (many tasks doable mouse-only)

**Subtask Effort**: 1 hour (optional)

---

### 🏁 Phase 2 Success Criteria

- ✅ Touch panning/viewport movement works
- ✅ Button clicks registered
- ✅ UI responds to input
- ✅ No latency/lag in touch response

**Total Phase 2 Effort**: ~5-6 hours  
**Timeline**: 1 week

---

## 📦 Phase 3: Asset Loading & Persistence (Weeks 6-7)

**Goal**: Load RCT2 data; save/load parks.

### Task Checklist

#### P3.1: Asset Bundle Integration

- [ ] **P3.1.1** Extract RCT2 data files to iOS app bundle
  - Needed: `data/` folder (sprites, objects, landscapes)
  - Language files, music (optional for MVP)
  - Effort: 1 hour
  - Owner: Data Engineer
  - Note: Respect RCT2 copyright; user must provide game files

- [ ] **P3.1.2** Implement iOS sandbox-aware file path resolution
  - Use `Documents/` or `Application Support/` directories
  - Modify OpenRCT2 environment paths
  - Effort: 1.5 hours
  - Owner: C++ Expert

- [ ] **P3.1.3** Copy bundled assets to app sandbox on first launch
  - Similar to Android `MainActivity.copyAssets()`
  - Effort: 1 hour
  - Owner: iOS Developer

- [ ] **P3.1.4** Test asset loading
  - Verify park graphics render correctly
  - No missing sprites/corruption
  - Effort: 1 hour
  - Owner: QA

**Subtask Effort**: 4.5 hours  
**Deliverable**: Full game graphics visible; not placeholder grids

---

#### P3.2: Save/Load Functionality

- [ ] **P3.2.1** Implement save/load UI (SwiftUI list)
  - List saved parks
  - "New Game" button
  - Delete saves
  - Effort: 1.5 hours
  - Owner: iOS/UI Developer

- [ ] **P3.2.2** Hook up OpenRCT2 save/load C++ functions
  - Implement C wrappers: `OpenRCT2_SaveGame()`, `OpenRCT2_LoadGame()`
  - Effort: 1 hour
  - Owner: C++ Expert

- [ ] **P3.2.3** Test save/load cycle
  - Create new park
  - Make changes (build rides, set prices)
  - Save
  - Load → verify state preserved
  - Effort: 1 hour
  - Owner: QA

**Subtask Effort**: 3.5 hours  
**Deliverable**: Fully functional save/load system

---

### 🏁 Phase 3 Success Criteria

- ✅ Park loads with full graphics
- ✅ Can create/save/load parks
- ✅ No data corruption
- ✅ File I/O works in iOS sandbox

**Total Phase 3 Effort**: ~8 hours  
**Timeline**: 1-2 weeks

---

## ⚡ Phase 4: Optimization (Weeks 8-10)

**Goal**: Achieve smooth 60 FPS; optional Metal acceleration.

### Task Checklist

#### P4.1: Performance Profiling

- [ ] **P4.1.1** Measure CPU time per frame
  - Use Xcode Time Profiler
  - Identify hot spots (palette conversion? dirty rect updates?)
  - Target: <16 ms/frame for 60 FPS
  - Effort: 1 hour
  - Owner: Performance Engineer

- [ ] **P4.1.2** Profile memory usage
  - Monitor with Instruments; set alerts
  - Target: <400 MB total
  - Effort: 1 hour
  - Owner: Performance Engineer

- [ ] **P4.1.3** Thermal & battery testing
  - Run for 1 hour; measure heat/battery drain
  - Document findings
  - Effort: 2 hours (mostly idle waiting)
  - Owner: QA/Performance Engineer

**Subtask Effort**: 4 hours  
**Deliverable**: Performance profile report; bottlenecks identified

---

#### P4.2: CPU-Side Optimization

These are done BEFORE Metal, to reduce CPU load:

- [ ] **P4.2.1** Optimize palette→RGBA conversion with SIMD
  - Replace naive loop with ARM NEON or Swift SIMD
  - Pre-allocate buffers; reduce allocations
  - Effort: 2 hours
  - Owner: Performance/SIMD Expert
  - Expected gain: 2-4× speedup

- [ ] **P4.2.2** Profile dirty rectangle optimization
  - Verify X8DrawingEngine is using dirty rects
  - May need tuning for iOS resolution
  - Effort: 1 hour
  - Owner: C++ Expert

- [ ] **P4.2.3** Reduce texture upload overhead
  - Batch texture updates
  - Use Metal blit commands (when Metal path added)
  - Effort: 1 hour
  - Owner: Graphics Developer

**Subtask Effort**: 4 hours  
**Deliverable**: CPU optimizations; ~20-30% speedup

---

#### P4.3: Metal Optimization Path (Only if needed)

**Decision**: If CPU profiling shows <55 FPS, prioritize this.

- [ ] **P4.3.1** Create MetalDrawingEngine backend
  - New class inheriting from `IDrawingEngine`
  - Implement: BeginDraw(), EndDraw(), PaintWindows()
  - Effort: 3 hours
  - Owner: Graphics/Metal Expert
  - Complexity: High; requires deep Metal knowledge

- [ ] **P4.3.2** GPU-accelerated palette conversion
  - Compute shader for 8-bit → RGBA
  - Eliminates CPU bottleneck
  - Effort: 2 hours
  - Owner: Shader Expert
  - Expected gain: 10-20× speedup on palette conversion

- [ ] **P4.3.3** Dirty rect → Metal blit pipeline
  - Update only changed regions
  - MTLBlitCommandEncoder for texture updates
  - Effort: 2 hours
  - Owner: Metal Expert

- [ ] **P4.3.4** Profile Metal path
  - Verify GPU utilization; measure power savings
  - Effort: 1 hour
  - Owner: Performance Engineer

**Subtask Effort**: 8 hours (conditional)  
**Timeline**: 3-5 days (if metrics warrant)

---

### 🏁 Phase 4 Success Criteria

- ✅ Consistent 60 FPS on iPhone 12+ (or 30 FPS minimum)
- ✅ Memory usage stable (<400 MB)
- ✅ <2 W power draw while idle (if Metal used)
- ✅ Profiling report with recommendations

**Total Phase 4 Effort**: 8-12 hours (+ optional 8 hrs Metal)  
**Timeline**: 2-3 weeks

---

## 🎨 Phase 5: Polish & App Store (Weeks 11-13)

**Goal**: App Store ready.

### Task Checklist

#### P5.1: App Metadata & Store Listing

- [ ] **P5.1.1** Create app icon (1024×1024 PNG)
  - Design/use OpenRCT2 logo derivative
  - Effort: 1 hour
  - Owner: Designer

- [ ] **P5.1.2** Create App Store description
  - Highlight: Classic game, open-source, park building
  - Include disclaimers (RCT2 data required, limited vs. desktop)
  - Effort: 1 hour
  - Owner: Marketing/PO

- [ ] **P5.1.3** Create screenshots (5-10)
  - Show: Title screen, park, touch controls
  - Highlight key features
  - Effort: 2 hours
  - Owner: Marketing

- [ ] **P5.1.4** Write privacy/help documentation
  - Privacy: Minimal data collection (log files)
  - Help: Getting RCT2 data, controls
  - Effort: 2 hours
  - Owner: Technical Writer

**Subtask Effort**: 6 hours  
**Deliverable**: App Store listing draft; ready for submission

---

#### P5.2: Testing & Bug Fixes

- [ ] **P5.2.1** QA on target devices
  - iPhone 12, 13, 14 (min iOS 15.0)
  - iPad 6th gen or later
  - Landscape and portrait orientation
  - Effort: 3 hours
  - Owner: QA

- [ ] **P5.2.2** Crash testing & fix
  - Load heavy parks (100+ rides)
  - Long play sessions (>1 hour)
  - Test all UI paths
  - Effort: 2 hours
  - Owner: QA/Dev

- [ ] **P5.2.3** Setup crash reporting
  - Firebase Crashlytics, Sentry, or custom
  - Monitor in production
  - Effort: 1 hour
  - Owner: DevOps/Dev

- [ ] **P5.2.4** Accessibility review
  - VoiceOver support (if time permits)
  - Text size scaling
  - Effort: 1 hour
  - Owner: Accessibility expert (optional)

**Subtask Effort**: 7 hours  
**Deliverable**: Bug list with severities; known issues documented

---

#### P5.3: Developer Account & Submission

- [ ] **P5.3.1** Apple Developer Program enrollment
  - Annual fee ($99/yr)
  - Account approval (48-72 hrs)
  - Effort: 30 min
  - Owner: PO

- [ ] **P5.3.2** Certificate/provisioning setup
  - Create signing certificates
  - Device UDIDs for testing
  - Effort: 1 hour
  - Owner: iOS Developer

- [ ] **P5.3.3** Create App on App Store Connect
  - Setup app record, pricing, localization
  - Configure version info
  - Effort: 1 hour
  - Owner: PO

- [ ] **P5.3.4** Build & submit for review
  - Archive build
  - Upload to App Store Connect
  - Submit for review
  - Effort: 30 min
  - Owner: iOS Developer

- [ ] **P5.3.5** Monitor review status & respond to feedback
  - Review typically takes 24-48 hrs
  - May need to address rejection
  - Effort: Variable (expect 2-4 hrs)
  - Owner: Lead Developer

**Subtask Effort**: 5 hours  
**Deliverable**: App on App Store (or TestFlight beta)

---

### 🏁 Phase 5 Success Criteria

- ✅ Listed on App Store
- ✅ 1000+ beta testers (optional: TestFlight)
- ✅ ≥100 downloads in first month
- ✅ ≥4.0 star rating (3+ reviews)
- ✅ <2% crash rate in production

**Total Phase 5 Effort**: ~18 hours  
**Timeline**: 2-3 weeks

---

## 📊 Full Project Summary

| Phase | Duration | Effort | Owner | Status |
|-------|----------|--------|-------|--------|
| **P1: PoC** | 2-3 wks | ~20 hrs | Lead Dev + Graphics Dev | 🎯 Priority |
| **P2: Input** | 1 wk | ~6 hrs | iOS Dev | High |
| **P3: Assets** | 1-2 wks | ~8 hrs | C++ Dev + iOS Dev | High |
| **P4: Optimization** | 2-3 wks | ~12-20 hrs | Perf Eng + Metal Dev | Medium |
| **P5: Polish** | 2-3 wks | ~18 hrs | Marketing + QA | Medium |
| **TOTAL** | ~13 wks | ~200 hrs | 1-2 developers | ✅ Feasible |

---

## 🚨 Risk Mitigation Checklist

### High-Risk Items

- [ ] **SDL2 iOS linking issues**
  - Mitigation: Pre-build SDL2 as framework; test early
  - Owner: Build Engineer
  - Timeline: Week 1

- [ ] **C++ ABI symbol conflicts**
  - Mitigation: Use clang with proper flags; test linking on real device early
  - Owner: C++ Expert
  - Timeline: Week 1

- [ ] **Performance regression**
  - Mitigation: Profile before/after each major change
  - Owner: Performance Engineer
  - Timeline: Ongoing

- [ ] **Asset copyright/licensing**
  - Mitigation: Document requirement for user-provided RCT2 data; include EULA
  - Owner: Legal
  - Timeline: Before Phase 3

### Medium-Risk Items

- [ ] **Metal API complexity**
  - Mitigation: Start with software rendering (works!); Metal is Phase 4 optimization
  - Owner: All
  - Timeline: Phased approach

- [ ] **App Store review rejection**
  - Mitigation: Early feedback from community; follow guidelines
  - Owner: PO + Dev
  - Timeline: Phase 5

---

## 🔗 Dependency Graph

```
P1.1 (SPM Setup)
    ↓
P1.2 (C++ Shim) ← depends on: OpenRCT2 source code linkage
    ↓
P1.3 (iOS App Shell) ← depends on: P1.1 + P1.2
    ↓
P1.4 (Integration Test)
    ↓
P2.1 (Input Handling) ← depends on: P1
    ↓
P3.1 (Assets) ← depends on: P2 (basic playability)
    ↓
P4 (Optimization) ← depends on: P3 (for meaningful profiling)
    ↓
P5 (App Store) ← depends on: P4 (stable & decent perf)
```

---

## 💰 Resource Allocation Recommendation

**Minimum Viable Team**:
- **1 Lead Developer** (C++/iOS): ~12 wks, all phases
- **1 Graphics/Metal Developer**: P1.3 (2wks), P4.2-4.3 (2wks) = 4 weeks
- **1 QA/Test Engineer**: P1.4 onwards (spot checking)
- **Part-time: Designer, PO, Writer**: P5 only

**Total**: ~1.5 FTE for 13 weeks = **19.5 person-weeks**

**Alternative (Compressed)**:
- 2 full-time devs for 10 weeks = 20 person-weeks (can finish P1-P3 in 6-7 wks)

---

## 📅 Milestone Gates & Go/No-Go Decisions

| Gate | Criteria | Go Decision | Timeline |
|------|----------|-------------|----------|
| **End P1** | App runs 60 FPS with demo video | Green: Proceed to P2 | Week 3 |
| **End P2** | Touch controls fully functional | Green: Proceed to P3 | Week 5 |
| **End P3** | Full game playable; save/load works | Green: Proceed to P4 | Week 7 |
| **End P4** | 60 FPS stable; <400 MB RAM | Green: Proceed to P5 | Week 10 |
| **End P5** | App on App Store; ≥100 downloads | Success: Monitor post-launch | Week 13 |

---

## 🎓 Lessons Learned (Pre-project Notes)

1. **Swift C Interop is Mature**: Module maps + API notes work great; no hacks needed
2. **Software Rendering Viable**: OpenRCT2's CPU rendering is fast enough for MVP
3. **Android Pattern Applies**: Follow `openrct2-android` for similar integration
4. **Assets are Critical**: ~80% of user experience depends on RCT2 data availability
5. **Metal is Optional**: Don't gate MVP on Metal; add as Phase 4 optimization

---

## 📞 Key Contacts & Roles

| Role | Skill | Notes |
|------|-------|-------|
| **Lead Developer** | C++, iOS, Swift | Makes architectural decisions |
| **C++ Expert** | Context, X8Engine, CMake builds | Shim implementation |
| **Graphics Developer** | Metal, texture handling, SIMD | Rendering pipeline |
| **iOS Developer** | SwiftUI, UIKit, GestureRecognizers | App shell + touch |
| **QA/Tester** | Device testing, crash scenarios | Validation |
| **Performance Engineer** | Instruments, profiling, optimization | P4 focus |
| **Build/DevOps** | CMake, Xcode, app distribution | Infrastructure |

---

## 📚 Documentation References

- **High-Level Spec**: `OPENRCT2_IOS_INITIATIVE.md`
- **Implementation Guide**: `OPENRCT2_IOS_IMPLEMENTATION_GUIDE.md`
- **This Document**: `OPENRCT2_IOS_ROADMAP.md`
- **OpenRCT2 Docs**: [github.com/OpenRCT2/OpenRCT2](https://github.com/OpenRCT2/OpenRCT2)
- **Swift Blog**: [swift.org/blog/improving-usability-of-c-libraries-in-swift](https://www.swift.org/blog/improving-usability-of-c-libraries-in-swift/)

---

**Last Updated**: January 24, 2026  
**Status**: APPROVED FOR PHASE 1 KICKOFF  
**Next Review**: End of Week 2 (Phase 1 progress check)
