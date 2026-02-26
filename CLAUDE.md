# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pleaco is a SwiftUI iOS app that controls sex toys (The Handy, Oh., Intiface/Buttplug, LoveSpouse, phone haptics) via real-time waveform patterns and FunScript playback.

- **Language**: Swift 5.9+, **UI**: SwiftUI, **Min Target**: iOS 16.0
- **No external dependencies** — native frameworks only (SwiftUI, Combine, CoreBluetooth, CoreHaptics, AVFoundation, URLSession)
- **No tests, no SwiftLint**

## Build Commands

```bash
# Build for iOS Simulator
xcodebuild -project pleaco.xcodeproj -scheme pleaco -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Build for macOS
xcodebuild -project pleaco.xcodeproj -scheme pleaco -configuration Debug \
  -destination 'platform=macOS' build
```

Open `pleaco.xcodeproj` in Xcode to run on device/simulator.

## Architecture

### Data & Control Flow

```
ContentView
  └── HomeView            ← pattern grid + PlayerCard (always visible footer)
  └── SettingsView        ← presented as sheet; device CRUD + stroke range

DeviceManager.shared      ← central orchestrator (ObservableObject singleton)
  ├── HandyManager.shared     (The Handy / Oh. — HTTPS REST API)
  ├── ButtplugManager.shared  (Intiface — WebSocket, Buttplug.io protocol)
  ├── LoveSpouseManager.shared (LoveSpouse — BLE Peripheral advertising)
  └── HapticManager.shared    (Phone — CoreHaptics)

PatternEngine             ← static: wave math, FunScript interpolation
ThemeManager              ← Color/LinearGradient extensions, ButtonStyles
FunScriptModels           ← FunScriptData, NamedFunScript, PatternGroup
```

### DeviceManager

The single source of truth. All views observe `DeviceManager.shared`. Key responsibilities:
- Manages the `devices: [SavedDevice]` list and the single `activeDevice`
- Owns the wave timer that samples patterns at device-appropriate rates (10 Hz for Handy/Oh., 5 Hz for LoveSpouse, up to 50 Hz for internal)
- Routes `sendLevel(_:)` to the correct hardware manager
- Persists state to `UserDefaults` (devices, active device, preset, stroke range, custom scripts)

### Pattern Modes (mutually exclusive)

1. **Software Preset** (`selectedPreset: DeviceWavePreset`) — math-generated waveform in `calculateWaveValue(time:)`
2. **FunScript** (`activeFunScript: FunScriptData`) — interpolated from timestamped position actions
3. **LoveSpouse Hardware Program** (`selectedLoveSpouseProgram: Int 1–9`) — BLE advertising only; software speed updates are suppressed to prevent command collisions

### Device Communication

| Device | Protocol | Key |
|--------|----------|-----|
| The Handy / Oh. | HTTPS REST (`handyfeeling.com/api/handy/v2`) | `X-Connection-Key` header, 5 s timeout |
| Intiface | WebSocket (`ws://host:12345`), Buttplug.io JSON | `serverAddress` |
| LoveSpouse | BLE Peripheral (iPhone acts as broadcaster) | reverse-engineered 16-bit service UUIDs |
| Phone | CoreHaptics | `HapticManager` |

### Theming

All colors are `static` properties on `Color` and `LinearGradient` in `ThemeManager.swift`. The accent color comes from the `AppTint` asset (`Color.appAccent`). Custom button styles: `ScaleButtonStyle`, `GlowButtonStyle`.

## Key Conventions

- **Singletons**: `static let shared = X()` with `private init()`. Views use `@ObservedObject var x = X.shared`.
- **UI updates from background**: always dispatch to `DispatchQueue.main.async`.
- **Logging**: `NSLog("🔔 ManagerName: message")` for significant events; `print` for verbose debug only.
- **Persistence**: `UserDefaults` for scalars; `JSONEncoder/Decoder` for `[SavedDevice]` and `[NamedFunScript]`.
- **FunScript actions** are sorted ascending by `at` (ms) on import.
- Adding a new `DeviceWavePreset` case requires updates in: `DeviceManager.timerInterval(for:)`, `DeviceManager.calculateWaveValue(time:)`, `PatternEngine.generateValue(_:time:)`, and optionally `FunScriptModels.PatternGroup`.
