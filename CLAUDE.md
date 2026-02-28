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

### Project File Tree
```
Tessasaurus/
├── TessasaurusApp.swift                    # App entry point (@main)
├── ContentView.swift                        # Root view — FloatingTabBar + opacity-based tab switching
├── Info.plist
├── Tessasaurus.entitlements
├── Assets.xcassets/
│   ├── AppIcon.appiconset/
│   ├── AccentColor.colorset/
│   └── Colors/                              # TessaPrimary, TessaPink, TessaOrange, Gold, Coral, Cream, Background, PrimaryLight
├── Core/
│   ├── Theme/
│   │   ├── TessaColors.swift                # Color tokens — NEVER hardcode colors
│   │   ├── TessaGradients.swift             # Gradient tokens — NEVER hardcode gradients
│   │   └── TessaTypography.swift            # Typography tokens — NEVER hardcode fonts
│   ├── Components/
│   │   ├── FloatingTabBar.swift             # Custom tab bar (used in ContentView)
│   │   ├── GlassCard.swift                  # Glassmorphism card component
│   │   ├── ShimmerModifier.swift            # Shimmer loading effect
│   │   └── GradientBackground.swift         # Reusable gradient background
│   └── Services/
│       ├── CloudKitPhotoService.swift        # iCloud photo sync (singleton)
│       ├── PhotoStorageService.swift         # Local photo storage (singleton)
│       ├── ImageCacheService.swift           # In-memory image cache (singleton)
│       ├── HapticService.swift              # Haptic feedback patterns (singleton)
│       ├── PersistenceService.swift         # UserDefaults persistence
│       └── DateService.swift                # Date calculations for countdown
├── Models/
│   ├── Photo.swift                          # Photo model (CloudKit-backed)
│   ├── GiftHint.swift                       # Blind box hint model
│   └── Occasion.swift                       # Countdown occasion model
└── Features/
    ├── Home/
    │   └── HomeView.swift
    ├── BlindBox/
    │   ├── BlindBoxView.swift               # Main blind box countdown UI
    │   ├── BlindBoxViewModel.swift          # @Observable VM (no @MainActor)
    │   ├── GiftBoxView.swift                # Individual gift box component
    │   ├── DayProgressView.swift            # Day progress indicator
    │   ├── CountdownBanner.swift            # Countdown display
    │   └── ConfettiView.swift               # Celebration animation
    ├── PhotoWall/
    │   ├── PhotoWallView.swift              # Main photo constellation UI
    │   ├── PhotoWallViewModel.swift         # @Observable @MainActor VM (CloudKit async)
    │   ├── ConstellationCanvasView.swift    # Zoomable/pannable canvas
    │   ├── ConstellationLayout.swift        # Layout algorithm
    │   ├── ConstellationLinesView.swift     # Connecting lines between photos
    │   ├── PhotoBubble.swift                # Individual photo bubble
    │   ├── PhotoDetailView.swift            # Full photo detail sheet
    │   ├── AddPhotoSheet.swift              # Photo upload sheet
    │   └── StarfieldBackground.swift        # Animated star background
    └── Onboarding/
        ├── OnboardingView.swift
        └── OnboardingMessages.swift

TessasaurusTests/
└── TessasaurusTests.swift                   # Swift Testing framework (@Test, async/await)

TessasaurusUITests/
├── TessasaurusUITests.swift                 # XCTest UI tests (XCUIApplication)
└── TessasaurusUITestsLaunchTests.swift      # Launch performance tests
```

### Established Patterns (MUST follow in all new code)

1. **`@Observable` macro** (NOT `ObservableObject`/`@Published`) — `BlindBoxViewModel.swift:9`, `PhotoWallViewModel.swift:10`

2. **`@MainActor` on ViewModels with async/CloudKit work** — `PhotoWallViewModel.swift:11` uses `@MainActor` because it does async CloudKit operations. Lighter VMs like `BlindBoxViewModel` omit it.

3. **Singleton services via `static let shared`** — All services use this pattern:
   - `HapticService.shared` — `HapticService.swift:9`
   - `CloudKitPhotoService.shared` — `CloudKitPhotoService.swift:10`
   - `PhotoStorageService.shared` — `PhotoStorageService.swift:9`
   - `ImageCacheService.shared` — `ImageCacheService.swift:9`

4. **Design system tokens** — `TessaColors`, `TessaGradients`, `TessaTypography` enums. NEVER hardcode colors, gradients, or font styles.

5. **Custom `FloatingTabBar` with opacity-based tab switching** — `ContentView.swift:18-23`. Tabs are always mounted; visibility is controlled via `.opacity()` and `.zIndex()`.

6. **Spring animations** — `.spring(response: 0.35, dampingFraction: 0.8)` — `ContentView.swift:31`

7. **Error handling pattern** — `errorMessage: String?` + `showError: Bool` on ViewModel, surfaced via `.alert` modifier — `PhotoWallViewModel.swift:17-18`, `PhotoWallViewModel.swift:184-187`

8. **Haptic feedback via `HapticService.shared`** for user interactions — `BlindBoxViewModel.swift:56,64,70,79`

### Testing Frameworks
- **Unit Tests (`TessasaurusTests/`):** Uses Swift Testing framework with `import Testing`, `@Test` attribute, and async/await support
- **UI Tests (`TessasaurusUITests/`):** Uses XCTest framework with `XCUIApplication` for UI automation

### App Structure
- Entry point: `TessasaurusApp` struct with `@main` attribute
- Uses SwiftUI's `WindowGroup` scene
- `ContentView` is the root view

### SwiftUI Previews
Views include `#Preview` macros for Xcode canvas previews.

---

## Mandatory Workflow: Subagent Orchestration

**CRITICAL: Claude Code MUST follow this workflow for every non-trivial request.** Do not skip steps. Do not combine steps. Execute them in order.

```
User Request → [1] Explore → [2] Architecture + UI Plan (parallel) → [3] Review Gate → [4] Implement → [5] Verify
```

### Step 1: Explore & Understand

**Role:** Senior iOS Engineer
**Subagent type:** `Explore` (read-only — no edits)
**Model selection:**
- `haiku` — single-file lookup, simple question
- `sonnet` — multi-file tracing, understanding data flow
- `opus` — cross-cutting analysis, understanding system-wide impact

**Prompt template:**
> You are a Senior iOS Engineer. Analyze the following request in the context of this SwiftUI codebase.
>
> Request: {user's request}
>
> Investigate:
> 1. Which files are affected?
> 2. What is the current data flow for the affected area?
> 3. Which established patterns (see CLAUDE.md Architecture section) apply?
> 4. What constraints or edge cases exist?
> 5. Are there any design system tokens (TessaColors, TessaGradients, TessaTypography) relevant?
>
> Return a structured analysis. Do NOT suggest solutions — only analyze the current state.

### Step 2: Architecture + UI Plan (TWO agents IN PARALLEL)

Launch **both** agents in a **single message** using parallel tool calls.

#### Step 2A — Senior iOS Engineer (Architecture Plan)

**Subagent type:** `Plan`
**Model selection:**
- `sonnet` — standard features, bug fixes
- `opus` — new features, architecture refactors

**Prompt template:**
> You are a Senior iOS Engineer planning changes to a SwiftUI app.
>
> Context from exploration: {Step 1 output}
> Request: {user's request}
>
> Create a file-by-file change plan covering:
> 1. Files to create/modify/delete
> 2. State management approach (which VM, @Observable, @MainActor decision)
> 3. Service layer changes (singleton pattern, CloudKit, persistence)
> 4. Data flow: how data moves from source → ViewModel → View
> 5. Dependencies between changes (ordering)
> 6. Error handling following the errorMessage/showError pattern
>
> Follow ALL established patterns in CLAUDE.md. Flag any deviation with justification.

#### Step 2B — Figma & Frontend SwiftUI Expert (UI Plan)

**Subagent type:** `Plan`
**Model selection:**
- `sonnet` — standard views, layout work
- `opus` — complex animations, custom transitions, gesture-heavy interactions

**Prompt template:**
> You are a Figma & Frontend SwiftUI Expert planning the UI for a SwiftUI app.
>
> Context from exploration: {Step 1 output}
> Request: {user's request}
>
> Create a UI implementation plan covering:
> 1. View hierarchy (parent → child relationships)
> 2. Design token usage (TessaColors, TessaGradients, TessaTypography — specify exact tokens)
> 3. Animation specifications (spring params, transitions, timing)
> 4. Layout strategy (GeometryReader, alignment, spacing)
> 5. Accessibility considerations (VoiceOver labels, Dynamic Type)
> 6. Haptic feedback points (which HapticService methods, when)
> 7. Component reuse (GlassCard, GradientBackground, ShimmerModifier)
>
> Follow ALL established patterns in CLAUDE.md. Reference existing views as precedent.

### Step 3: Plan Review Gate

**Role:** Expert Engineering Code Reviewer
**Subagent type:** `Plan`
**Model:** `opus` (ALWAYS — this is the quality gate, never downgrade)

**Prompt template:**
> You are an Expert Engineering Code Reviewer for a SwiftUI iOS app.
>
> Review the following implementation plans against the codebase.
>
> Architecture Plan: {Step 2A output}
> UI Plan: {Step 2B output}
> Original Request: {user's request}
>
> Evaluate against these 6 criteria:
> 1. **Pattern Conformance** — Does it follow ALL established patterns in CLAUDE.md? (@Observable not ObservableObject, singleton services, design tokens, etc.)
> 2. **Data Flow Integrity** — Is state management correct? No unnecessary @MainActor? Proper async/await?
> 3. **Architecture Soundness** — Does it fit the existing Feature/Core/Model structure? No unnecessary abstractions?
> 4. **UI Consistency** — Does it match existing animation styles, component usage, and design system?
> 5. **Edge Cases** — Error states, empty states, loading states, offline behavior?
> 6. **Testability** — Can the changes be unit tested? Are dependencies injectable?
>
> Return one of:
> - **APPROVED** — Plans are sound. Proceed to implementation.
> - **REVISIONS NEEDED** — List specific issues with each criterion that failed. Be actionable.

**If REVISIONS NEEDED:**
- Feed the reviewer's feedback back into Step 2 (re-run both 2A and 2B with the feedback).
- Maximum 3 revision iterations. If still not approved after 3 rounds, escalate to the user with a summary of unresolved concerns.

### Step 4: Implementation

Claude Code implements directly — no subagent. The full approved plan is in context.

**Rules:**
- Implement changes in dependency order (services → models → VMs → views).
- Build after each logical unit to catch errors early:
  ```bash
  xcodebuild -project Tessasaurus.xcodeproj -scheme Tessasaurus -sdk iphonesimulator build
  ```
- If a build fails, fix immediately before continuing.
- Follow the approved plan exactly. If you discover the plan needs adjustment during implementation, note the deviation and justify it.

### Step 5: Quality Verification

**Role:** App Platform Senior iOS Engineer
**Subagent type:** `Explore` (read-only — verify, don't modify)
**Model selection:**
- `sonnet` — standard verification
- `opus` — performance-critical code, complex animations, memory management concerns

**Prompt template:**
> You are an App Platform Senior iOS Engineer verifying a SwiftUI implementation.
>
> Review the changes that were just made for:
> 1. **Fluidity** — Animations use correct spring parameters? Transitions are smooth?
> 2. **Responsiveness** — No blocking main thread? Async work properly dispatched?
> 3. **Performance** — No unnecessary re-renders? Image caching used properly? No retain cycles?
> 4. **Memory Management** — Proper use of [weak self]? No leaked closures?
> 5. **Implementation Fidelity** — Does the code match the approved plan?
> 6. **Pattern Compliance** — All CLAUDE.md patterns followed?
>
> Return one of:
> - **PASS** — Implementation is solid.
> - **CRITICAL ISSUES** — List issues that must be fixed before shipping. (Claude Code fixes these and re-runs verification.)
> - **WARNINGS** — List non-blocking concerns to report to the user.

---

## Model Selection Quick Reference

| Scenario | Step 1: Explore | Step 2A: Arch Plan | Step 2B: UI Plan | Step 3: Review | Step 5: Verify |
|---|---|---|---|---|---|
| Simple bugfix | haiku | sonnet | sonnet | opus | sonnet |
| Standard feature | sonnet | sonnet | sonnet | opus | sonnet |
| New feature | sonnet | opus | sonnet | opus | sonnet |
| Complex animations | sonnet | sonnet | opus | opus | opus |
| Architecture refactor | opus | opus | sonnet | opus | opus |
| Theme/design changes | haiku | sonnet | opus | opus | sonnet |
| Performance work | sonnet | sonnet | haiku | opus | opus |

---

## Trivial Change Escape Hatch

For **clearly trivial** changes (typo fix, single constant change, comment update), Claude Code MAY skip directly to implementation with a one-line justification explaining why the full workflow is unnecessary.

The bar is high — if there is **any doubt**, run the full workflow. Examples of trivial:
- Fixing a typo in a string literal
- Changing a single numeric constant
- Adding/removing a comment

Examples of NOT trivial (run full workflow):
- Adding a new view or modifying view hierarchy
- Changing state management or data flow
- Adding/modifying animations
- Any change touching more than 2 files

---

## Parallel Execution Rules

- **Steps 2A + 2B:** ALWAYS launch in parallel (independent concerns, use a single message with two Task tool calls)
- **All other steps:** Sequential (each step depends on the output of the prior step)
- **Step 3 revision loops:** Re-run 2A + 2B in parallel with reviewer feedback
