# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Tessasaurus is an iOS application built with SwiftUI using Xcode. The project uses the Swift Testing framework for unit tests and XCTest for UI tests.

**Target Platforms:** iOS (iphoneos, iphonesimulator)  
**Bundle Identifier:** personal.thanhhuynh.Tessasaurus

## Project Structure

```
Tessasaurus/               # Main application source code
  ├── TessasaurusApp.swift # App entry point (@main)
  └── ContentView.swift    # Root SwiftUI view
TessasaurusTests/          # Unit tests (Swift Testing framework)
TessasaurusUITests/        # UI tests (XCTest + XCUIApplication)
Tessasaurus.xcodeproj/     # Xcode project file
```

## Common Commands

### Building
```bash
# Build the project
xcodebuild -project Tessasaurus.xcodeproj -scheme Tessasaurus build

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

# Run a specific test
xcodebuild test -project Tessasaurus.xcodeproj -scheme Tessasaurus -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:TessasaurusTests/TessasaurusTests/example
```

### Running
```bash
# Open in Xcode
open Tessasaurus.xcodeproj

# List available simulators
xcrun simctl list devices available

# Build and run on simulator
xcodebuild -project Tessasaurus.xcodeproj -scheme Tessasaurus -destination 'platform=iOS Simulator,name=iPhone 16' run
```

### Project Information
```bash
# List schemes and targets
xcodebuild -list -project Tessasaurus.xcodeproj

# Show build settings
xcodebuild -showBuildSettings -project Tessasaurus.xcodeproj -scheme Tessasaurus
```

## Architecture Notes

### Testing Frameworks
- **Unit Tests:** Uses Swift Testing framework (import Testing) with async/await support and `@Test` attribute
- **UI Tests:** Uses XCTest framework with `XCUIApplication` for UI automation

### App Structure
- Entry point is `TessasaurusApp` struct with `@main` attribute
- Uses SwiftUI's `WindowGroup` scene
- `ContentView` is the root view of the application

## Development Conventions

### SwiftUI Previews
SwiftUI views include `#Preview` macros for Xcode canvas previews.

### Test Organization
- Unit tests in `TessasaurusTests` target use Swift Testing framework syntax
- UI tests in `TessasaurusUITests` target use XCTest and should include setup/teardown methods
- UI tests include launch performance tests and screenshot attachments
