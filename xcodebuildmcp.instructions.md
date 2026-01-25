# XcodeBuildMCP Agent Guide

Instructions for agents using xcodebuildmcp MCP server with the {{YOUR_APP_HERE}} project.

## Quick Start

1. **Set session defaults first** (required before any build/test commands):
   ```json
   {
     "scheme": "{{YOUR_APP_HERE}}",
     "project": "/Users/cjgaspari/Developer/{{YOUR_APP_HERE}}/{{YOUR_APP_HERE}}.xcodeproj"
   }
   ```

2. **Discover available devices/simulators**:
   - Physical devices: `mcp_xcodebuildmcp_list_devices`
   - Simulators: `xcrun simctl list devices available` (via terminal)

3. **Choose the right tool** using the decision tree below

---

## iOS Simulator Commands

### Build for Simulator

**Tool:** `mcp_xcodebuildmcp_build_sim`

**Parameters:**
```json
{}
```

**Optional Parameters:**
```json
{
  "derivedDataPath": "/path/to/DerivedData",
  "preferXcodebuild": true,
  "extraArgs": ["ADDITIONAL_BUILD_FLAG"]
}
```

---

### Build and Run on Simulator

**Tool:** `mcp_xcodebuildmcp_build_run_sim`

**Parameters:**
```json
{}
```

**Optional Parameters:**
```json
{
  "derivedDataPath": "/path/to/DerivedData",
  "preferXcodebuild": true,
  "extraArgs": ["ADDITIONAL_BUILD_FLAG"]
}
```

---Decision Tree: Choosing the Right Tool

### Step 1: Determine Platform
- **iOS Simulator** → `*_sim` tools (default, no deviceId needed)
- **macOS** → `*_macos` tools
- **Physical Device** → `*_device` tools (requires `deviceId` from `list_devices`, `platform: "iOS"` or `"visionOS"`)

### Step 2: Determine Action
- **Build only** → `build_*`
- **Build and run** → `build_run_*`
- **Test** → `test_*`
- **Clean** → `clean` with `platform` parameter

### Step 3: Add Test Filtering (if testing)
- All tests → `{}`
- Specific suite → `{extraArgs: ["-only-testing:{{YOUR_APP_HERE}}Tests/SUITENAME"]}`
- Single test → `{extraArgs: ["-only-testing:{{YOUR_APP_HERE}}Tests/SUITE/testName"]}`
- Skip test → `{extraArgs: ["-skip-testing:{{YOUR_APP_HERE}}Tests/SUITE/testName"]}`

### Step 4: Add Optional Flags (if needed)
- Clean build → `preferXcodebuild: true` or run `clean` first
- Environment vars → `testRunnerEnv: {KEY: "value"}` (auto-prefixed with `TEST_RUNNER_`)

---

## Tool Reference

### iOS Simulator Tools
| Tool | Parameters |
|------|------------|
| `mcp_xcodebuildmcp_build_sim` | `{}` |
| `mcp_xcodebuildmcp_build_run_sim` | `{}` |
| `mcp_xcodebuildmcp_test_sim` | `{}` or `{extraArgs: [...]}` |

### macOS Tools
| Tool | Parameters |
|------|------------|
| `mcp_xcodebuildmcp_build_macos` | `{}` |
| `mcp_xcodebuildmcp_build_run_macos` | `{}` |
| `mcp_xcodebuildmcp_test_macos` | `{}` or `{extraArgs: [...]}` |

### Physical Device Tools
| Tool | Required Parameters |
|------|---------------------|
| `mcp_xcodebuildmcp_build_device` | `{deviceId: "...", platform: "iOS"/"visionOS"}` |
| `mcp_xcodebuildmcp_build_run_device` | `{deviceId: "...", platform: "iOS"/"visionOS"}` |
| `mcp_xcodebuildmcp_test_device` | `{deviceId: "...", platform: "iOS"/"visionOS"}` |

**Note:** Get `deviceId` from `mcp_xcodebuildmcp_list_devices`

### Clean Tool
| Platform String | Use Case |
|-----------------|----------|
| `"iOS Simulator"` | Clean simulator builds |
| `"iOS"` | Clean device builds |
| `"macOS"` | Clean macOS builds |
| `"visionOS"` | Clean Vision Pro builds |

**Usage:** `mcp_xcodebuildmcp_clean` with `{platform: "..."}
// Run different test suites (faster since build is cached)
await test_sim({ extraArgs: ["-only-testing:{{YOUR_APP_HERE}}Tests/FeedFeatureTests"] });
await test_sim({ extraArgs: ["-only-testing:{{YOUR_APP_HERE}}Tests/LibraryFeatureTests"] });
await test_sim({ extraArgs: ["-only-testing:{{YOUR_APP_HERE}}Tests/SettingsFeatureTests"] });
```

### Pattern 4: Test Across All Platforms

```javascript
// Test on iOS Simulator
await test_sim({ extraArgs: ["-only-testing:{{YOUR_APP_HERE}}Tests/FeedFeatureTests"] });

// Test on macOS
await test_macos({ extraArgs: ["-only-testing:{{YOUR_APP_HERE}}Tests/FeedFeatureTests"] });

// Test on physical device
await test_device({
  deviceId: "3EF174B1-23F4-5904-9DCE-65AA47DA0603",
  platform: "iOS",
  extraArgs: ["-only-testing:{{YOUR_APP_HERE}}Tests/FeedFeatureTests"]
});
```

---

## Test Filtering Syntax

### Run All Tests in a Test File
```
-only-testing:{{YOUR_APP_HERE}}Tests/FeedFeatureTests
```

### Run a Specific Test
```
-only-testing:{{YOUR_APP_HERE}}Tests/FeedFeatureTests/tappedRightAdvancesStoryIndex
```

### Run Multiple Specific Items (use multiple `-only-testing` flags)
```json
{
  "extraArgs": [
    "-only-testing:{{YOUR_APP_HERE}}Tests/FeedFeatureTests/tappedRightAdvancesStoryIndex",
    "-only-testing:{{YOUR_APP_HERE}}Tests/FeedFeatureTests/tappedLeftDecrementsStoryIndex"
  ]
}
```

### Skip Specific Tests (use `-skip-testing`)
```json
{
  "extraArgs": [
    "-skip-testing:{{YOUR_APP_HERE}}Tests/FeedFeatureTests/flakyTest"
  ]
}
```

---

## Decision Logic for Agents

When an agent needs to determine which command to use:

### 1. Determine Target Platform

- **iOS Simulator** → Use `*_sim` tools (no deviceId needed, uses default simulator)
- **Physical iOS Device** → Use `*_device` tools (requires deviceId + platform)
- **macOS** → Use `*_macos` tools
- **Not Specified** → Default to iOS simulator

### 2. Determine Action

- **Build only** → `build_*`
- **Build and run** → `build_run_*`
- **Test** → `test_*`
- **Clean** → `clean`

### 3. Determine Test Scope (if testing)

- **All tests** → No `extraArgs`
- **Specific suite** → `extraArgs: ["-only-testing:{{YOUR_APP_HERE}}Tests/SUITE"]`
- **Single test** → `extraArgs: ["-only-testing:{{YOUR_APP_HERE}}Tests/SUITE/TEST"]`
- **Skip tests** → `extraArgs: ["-skip-testing:{{YOUR_APP_HERE}}Tests/SUITE/TEST"]`

### 4. Check for Special Flags

- **Clean build needed** → Set `preferXcodebuild: true` or run `clean` first
- **Custom derived data** → Set `derivedDataPath`
- **Test environment vars** → Set `testRunnerEnv`

---

## Quick Reference Table

| Action | Simulator | Device | macOS | Parameters |
|--------|-----------|--------|-------|------------|
| Build | `build_sim` | `build_device` | `build_macos` | `{}` or `{deviceId, platform}` |
| Build & Run | `build_run_sim` | `build_run_device` | `build_run_macos` | `{}` or `{deviceId, platform}` |
| All Tests | `test_sim` | `test_device` | `test_macos` | `{}` or `{deviceId, platform}` |
| Test Suite | `test_sim` | `test_device` | `test_macos` | `{extraArgs: ["-only-testing:{{YOUR_APP_HERE}}Tests/SUITE"]}` |
| Single Test | `test_sim` | `test_device` | `test_macos` | `{extraArgs: ["-only-testing:{{YOUR_APP_HERE}}Tests/SUITE/TEST"]}` |
| Clean | `clean` | `clean` | `clean` | `{platform: "iOS Simulator/iOS/macOS/visionOS"}` |

---

## Troubleshooting

### Error: "Missing required session defaults"
**Solution:** Run session setup first with scheme and project path.

### Error: "Device not found"
**Solution:** Run `mcp_xcodebuildmcp_list_devices` to get current device IDs. Device IDs can change.

### Tests Timeout or Hang
**Solution:** 
1. Try `preferXcodebuild: true`
2. Clean build products first
3. Check if simulator is responding

### Build Fails on Device
**Solution:**
1. Ensure device is unlocked and trusted
2. Check Developer Mode is enabled
3. Verify signing certificates

### Incremental Build Issues
**Solution:** Set `preferXcodebuild: true` to use standard xcodebuild instead of the faster incremental build system.

---

## Platform Values

Valid platform strings for commands:

- `"iOS"` - iPhone and iPad (physical devices)
- `"visionOS"` - Apple Vision Pro (physical device)
- `"iOS Simulator"` - iOS Simulator (for clean command)
- `"visionOS Simulator"` - visionOS Simulator (for clean command)
- `"macOS"` - macOS target (for clean command and macOS tools)

**Supported Platforms:** {{YOUR_APP_HERE}} supports iOS (iPhone/iPad), macOS, and visionOS.

---

## Performance Tips

1. **Use session defaults** - Set scheme/project once instead of passing it every time
2. **Build once, test many** - Build separately, then run multiple test suites
3. **Use incremental builds** - Default behavior is faster (only use `preferXcodebuild` if issues occur)
4. **Test priority order** - macOS (fastest) → iOS Simulator → Physical devices (slowest)
5. **Filter tests** - Run specific failing tests instead of entire suite during debugging
6. **Parallel testing** - Run tests on multiple platforms simultaneously for comprehensive coverage

---

## Examples for Common Agent Tasks

### Task: "Run the feed tests"
```json
Tool: mcp_xcodebuildmcp_test_sim
{
  "extraArgs": ["-only-testing:{{YOUR_APP_HERE}}Tests/FeedFeatureTests"]
}
```

### Task: "Build and run on iPhone"
```json
Tool: mcp_xcodebuildmcp_build_run_device
{
  "deviceId": "3EF174B1-23F4-5904-9DCE-65AA47DA0603",
  "platform": "iOS"
}
```

### Task: "Test this specific test that's failing"
```json
Tool: mcp_xcodebuildmcp_test_sim
{
  "extraArgs": ["-only-testing:{{YOUR_APP_HERE}}Tests/FeedFeatureTests/tappedRightAdvancesStoryIndex"]
}
```

### Task: "Clean and rebuild"
```json
// First clean
Tool: mcp_xcodebuildmcp_clean
{
  "platform": "iOS Simulator"
}

// Then build
Tool: mcp_xcodebuildmcp_build_sim
{}
```

### Task: "Run tests on macOS"
```json
Tool: mcp_xcodebuildmcp_test_macos
{}
```

### Task: "Build and run on macOS"
```json
Tool: mcp_xcodebuildmcp_build_run_macos
{}
```

### Task: "Run on iPhone Air simulator"
```json
// Simulators are automatically selected by platform
// No need to specify deviceId for simulators
Tool: mcp_xcodebuildmcp_build_run_sim
{}
```

---

## Additional Resources

- **xcodebuildmcp documentation:** Check the server's GitHub repository
- **Xcode build settings:** Run `mcp_xcodebuildmcp_show_build_settings` for detailed settings
- **System info:** Run `mcp_xcodebuildmcp_doctor` for diagnostics
- **Device list:** Run `mcp_xcodebuildmcp_list_devices` for current devices

---

**Last Updated:** January 24, 2026  
**Project:** {{YOUR_APP_HERE}}  
**Xcode Version:** 26.1 (Build 17B55)
Test Filtering Patterns

```text
-only-testing:{{YOUR_APP_HERE}}Tests/SUITE              # All tests in suite
-only-testing:{{YOUR_APP_HERE}}Tests/SUITE/testName     # Single test
-skip-testing:{{YOUR_APP_HERE}}Tests/SUITE/testName     # Skip specific test
```

**Multiple filters:** Use array of strings in `extraArgs`

**Test suites in {{YOUR_APP_HERE}}:**
- `FeedFeatureTests`
- `LibraryFeatureTests`
- `CollectionEditorFeatureTests`
- `StoryEditorFeatureTests`
- `SettingsFeatureTests`

---

## Common Agent Workflows

### Run Specific Failing Test
```json
Tool: mcp_xcodebuildmcp_test_sim
{
  "extraArgs": ["-only-testing:{{YOUR_APP_HERE}}Tests/FeedFeatureTests/testName"]
}
```

### Run All Tests for a Feature
```json
Tool: mcp_xcodebuildmcp_test_sim
{
  "extraArgs": ["-only-testing:{{YOUR_APP_HERE}}Tests/FeedFeatureTests"]
}
```

### Test on macOS (fastest)
```json
Tool: mcp_xcodebuildmcp_test_macos
{}
```

### Test on Physical Device
```json
// 1. Get device ID
Tool: mcp_xcodebuildmcp_list_devices

// 2. Run test with discovered deviceId
Tool: mcp_xcodebuildmcp_test_device
{
  "deviceId": "<from list_devices>",
  "platform": "iOS"
}
```

### Clean Build When Issues Occur
```json
// 1. Clean
Tool: mcp_xcodebuildmcp_clean
{ "platform": "iOS Simulator" }

// 2. Build
Tool: mcp_xcodebuildmcp_build_sim
{}
```

### Test Across Platforms
```text
1. test_macos → fastest feedback
2. test_sim → iOS-specific validation  
3. test_device → real hardware verification (if needed)
```| Error | Solution |
|-------|----------|
| "Missing required session defaults" | Set session defaults first (scheme + project) |
| "Device not found" | Run `list_devices` to get current deviceId |
| Tests timeout/hang | Try `preferXcodebuild: true` or `clean` first |
| Build fails on device | Unlock device, enable Developer Mode, check signing |
| Incremental build issues | Set `preferXcodebuild: true` |

---

## Key Agent Guidelines

1. **Always set session defaults first** before any build/test command
2. **Default to iOS Simulator** (`*_sim` tools) when platform not specified
3. **Use macOS for fastest test iteration** when debugging
4. **Discover deviceIds dynamically** - don't hardcode UUIDs (they change)
5. **Filter tests** to specific suites/tests when debugging failures
6. **Clean builds** when seeing unexplained failures (`clean` + rebuild)
7. **Test priority**: macOS (fastest) → iOS Simulator → Physical devices (slowest)

---

## Supported Platforms

- **iOS** - iPhone/iPad (simulator + physical devices)
- **macOS** - Native macOS builds
- **visionOS** - Apple Vision Pro (physical device only