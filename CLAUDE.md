# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tessasaurus is an iOS application built with SwiftUI. The project uses Swift Testing framework for unit tests and XCTest for UI tests.

**Target Platform:** iOS
**Bundle Identifier:** personal.thanhhuynh.Tessasaurus

## Common Commands

### Building
```bash
# Build for simulator
xcodebuild -project Tessasaurus.xcodeproj -scheme Tessasaurus -sdk iphonesimulator build

# Clean build
xcodebuild -project Tessasaurus.xcodeproj -scheme Tessasaurus clean
```

### Testing
```bash
# Run all tests
xcodebuild test -project Tessasaurus.xcodeproj -scheme Tessasaurus -destination 'platform=iOS Simulator,name=iPhone 16'

# Run only unit tests
xcodebuild test -project Tessasaurus.xcodeproj -scheme Tessasaurus -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:TessasaurusTests

# Run only UI tests
xcodebuild test -project Tessasaurus.xcodeproj -scheme Tessasaurus -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:TessasaurusUITests

# Run a specific test (pattern: TargetName/TestClassName/testMethodName)
xcodebuild test -project Tessasaurus.xcodeproj -scheme Tessasaurus -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:TessasaurusTests/TessasaurusTests/example
```

### Running
```bash
# Open in Xcode
open Tessasaurus.xcodeproj

# List available simulators
xcrun simctl list devices available
```

## Architecture

### Testing Frameworks
- **Unit Tests (`TessasaurusTests/`):** Uses Swift Testing framework with `import Testing`, `@Test` attribute, and async/await support
- **UI Tests (`TessasaurusUITests/`):** Uses XCTest framework with `XCUIApplication` for UI automation

### App Structure
- Entry point: `TessasaurusApp` struct with `@main` attribute
- Uses SwiftUI's `WindowGroup` scene
- `ContentView` is the root view

### SwiftUI Previews
Views include `#Preview` macros for Xcode canvas previews.
