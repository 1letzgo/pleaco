# AGENTS.md - pleaco Development Guide

## Overview

pleaco is a SwiftUI iOS/macOS application that interfaces with sex toys (The Handy, Oh., Intiface, and phone haptics). It provides real-time pattern control, audio-reactive modes, and FunScript import functionality.

## Project Structure

```
pleaco/
├── pleacoApp.swift          # App entry point
├── ContentView.swift        # Main tab view
├── Managers/                # Business logic (singleton managers)
│   ├── ButtplugManager.swift
│   ├── HandyManager.swift
│   ├── PatternEngine.swift
│   ├── ThemeManager.swift
│   ├── BackgroundAudioManager.swift
│   └── HapticManager.swift
├── DeviceManagers/
│   ├── DeviceManager.swift  # Central device orchestration
│   └── AudioReactiveManager.swift
├── Models/
│   └── FunScriptModels.swift
├── Views/
│   ├── HomeView.swift
│   ├── PlayerView.swift
│   └── SettingsView.swift
└── Resources/
```

---

## Build & Development Commands

### Building the Project

```bash
# Build for iOS Simulator
xcodebuild -project pleaco.xcodeproj -scheme pleaco -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Build for macOS
xcodebuild -project pleaco.xcodeproj -scheme pleaco -configuration Debug -destination 'platform=macOS' build

# Build release
xcodebuild -project pleaco.xcodeproj -scheme pleaco -configuration Release build
```

### Running the App

Open `pleaco.xcodeproj` in Xcode and run on a simulator or device.

### Code Signing

For device deployment, you'll need to configure code signing in Xcode:
- Select the `pleaco` target
- Set your Development Team
- Ensure the Bundle Identifier matches your provisioning profile

### Running Tests

**No tests currently exist in this project.** If tests are added:

```bash
# Run all tests
xcodebuild -project pleaco.xcodeproj -scheme pleaco test

# Run a single test class
xcodebuild -project pleaco.xcodeproj -scheme pleaco test -only-testing:MyTestClass

# Run a single test method
xcodebuild -project pleaco.xcodeproj -scheme pleaco test -only-testing:MyTestClass/testMethod
```

### Linting

No SwiftLint configuration exists. Standard Xcode warnings are enabled.

---

## Code Style Guidelines

### General Conventions

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI with UIKit interop where needed
- **Architecture**: MVVM with singleton Managers
- **Minimum Deployment**: iOS 16.0

### File Organization

1. **File Header**: Standard copyright comment
   ```swift
   //
   //  Filename.swift
   //  pleaco
   //
   ```

2. **Imports**: Grouped at top, stdlib first, then frameworks
   ```swift
   import Foundation
   import SwiftUI
   import Combine
   ```

3. ** MARK Comments**: Use `// MARK:` for section organization
   ```swift
   // MARK: - Public Methods
   
   // MARK: - Private Methods
   
   // MARK: - Subcomponents
   ```

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Types (struct, class, enum) | PascalCase | `DeviceManager`, `FunScriptData` |
| Functions | PascalCase | `func connect(completion:)` |
| Properties/Variables | camelCase | `isConnected`, `serverAddress` |
| Constants | camelCase | `let maxRetry = 3` |
| Enums cases | camelCase | `case .handy`, `case audioReactive` |
| Files | PascalCase matching type | `DeviceManager.swift` |

### Type Guidelines

- **Prefer `struct` over `class`** for data models
- **Use `enum`** for related constants and state
- **Use `@Published`** for ObservableObject properties
- **Use `@State`** for view-local state
- **Use `@ObservedObject`** for shared singleton state
- **Avoid force unwrapping** (`!`) - use optional binding instead
- **Avoid force casts** (`as!`) - use conditional casts

### Access Control

- Use `private` for implementation details
- Use `fileprivate` for test access if needed
- Default to internal (no modifier needed)
- Use `static` for singleton instances

### Singleton Pattern

```swift
class DeviceManager: ObservableObject {
    static let shared = DeviceManager()
    
    private init() { }  // Prevents instantiation
    
    // ...
}
```

### Property Declaration Order

1. Static properties
2. @Published properties
3. Other instance properties
4. Computed properties
5. Methods

### SwiftUI View Guidelines

- Use `some View` for view computed properties
- Prefer `@ObservedObject` over `@EnvironmentObject` for managers
- Use `.buttonStyle(.plain)` for custom button styling
- Use `GeometryReader` sparingly for layout calculations
- Group related subviews in nested structs with `// MARK:` comments

### Error Handling

- Use `guard` for early returns on invalid state
- Use `do-catch` for operations that can throw
- Provide meaningful error messages in alerts
- Log errors with context: `NSLog("🔔 Context: \(error)")`

### Property Wrappers

| Wrapper | Use Case |
|---------|----------|
| `@State` | View-local mutable state |
| `@Binding` | Two-way binding to parent state |
| `@Published` | ObservableObject published properties |
| `@ObservedObject` | Reference to shared ObservableObject |
| `@StateObject` | Create and own ObservableObject lifecycle |

### Color Definitions

All app colors are defined as `static` properties on `Color` extension in `ThemeManager.swift`:

```swift
extension Color {
    static let appMagenta = Color(red: 204/255.0, green: 0/255.0, blue: 136/255.0)
    static let appBackground = Color(uiColor: UIColor { ... })
    // ...
}
```

### Persistence

- Use `UserDefaults` for simple key-value settings
- Use `JSONEncoder`/`JSONDecoder` for complex objects
- Store device configs and custom scripts via `Codable`

### Logging

- Use `NSLog` with emoji prefix for important events: `NSLog("🔔 DeviceManager: Connected")`
- Use `print` for debug-only verbose logging (avoid in release)

### Async Patterns

- Use completion handlers for async operations
- Use `DispatchQueue.main.async` for UI updates from background callbacks
- Use Combine for reactive data streams

---

## Common Development Patterns

### Device Manager Pattern

All device interactions flow through `DeviceManager.shared`:

```swift
// Start playback
DeviceManager.shared.start()

// Apply preset
DeviceManager.shared.applyPreset(.wave)

// Import FunScript
DeviceManager.shared.applyFunScript(script)
```

### Pattern Engine

`PatternEngine` provides static methods for pattern generation:

```swift
// Sample a FunScript curve
let points = PatternEngine.sampleFunScriptCurve(script, pointCount: 40)

// Get cached curves for presets
let curves = PatternEngine.cachedCurves[.foreplay]
```

### View Updates

Views observe `DeviceManager.shared` and automatically refresh:

```swift
@ObservedObject var deviceManager = DeviceManager.shared
```

---

## Key Dependencies

- **No external dependencies** - uses native frameworks only
- SwiftUI, Combine, Foundation, UIKit
- URLSession for WebSocket (Buttplug)
- AVFoundation for audio
- CoreHaptics for phone vibration
- UniformTypeIdentifiers for document import

---

## Testing Guidelines

When adding tests:

1. Place tests in a `pleacoTests/` directory
2. Use XCTest framework
3. Test manager classes in isolation
4. Mock WebSocket and hardware connections
5. Use `@MainActor` for tests involving UI updates
