# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build for iOS Simulator
xcodebuild -project PrivateSpace.xcodeproj -scheme PrivateSpace -configuration Debug -destination 'platform=iOS Simulator,name=iPhone' build

# Build for macOS
xcodebuild -project PrivateSpace.xcodeproj -scheme PrivateSpace -configuration Debug -destination 'platform=macOS' build

# List available simulators
xcrun simctl list devices available
```

## Project Architecture

This is a minimal SwiftUI application with no external dependencies (no SPM, no CocoaPods).

**Structure:**
- `PrivateSpace/` - Source directory containing SwiftUI views
  - `PrivateSpaceApp.swift` - App entry point with `@main`
  - `ContentView.swift` - Main content view
  - `Assets.xcassets/` - App assets (accent color, app icon)

**Key Build Settings:**
- Bundle ID: `quwaner.PrivateSpace`
- Deployment Target: iOS 26.2, macOS 26.2, xrOS 26.2
- Swift Version: 5.0
- Swift Concurrency: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- App Sandbox: Enabled with readonly file access
- App Groups: Enabled

**Xcode Project Notes:**
- Uses `PBXFileSystemSynchronizedRootGroup` for automatic directory synchronization
- No `project.yml` or custom XcodeGen configuration exists
- Build system: Standard Xcode build with `xcodeproj` (not `xcworkspace`)
