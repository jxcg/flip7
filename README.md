# Flip7

Flip7 is a digital press-your-luck card game. You draw cards to build your score and choose when to stop.

The interface and artwork must be original. Do not publicly distribute the app under the Flip 7 name until the owner confirms the required trademark and licensing rights.

## Build and test

This repository currently contains a native SwiftUI app for iOS and iPadOS. Development requires Xcode 26.6 or newer and Swift 6.0 or newer. The app supports version 18.0 or newer on both operating systems.

Test the game rules:

```sh
swift test -Xswiftc -warnings-as-errors
```

Build the app without signing:

```sh
xcodebuild -project flip7.xcodeproj -scheme flip7 -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/flip7-derived-data CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES build
```

## Project layout

- `flip7/Core`: game rules kept separate from the interface
- `flip7`: SwiftUI app and presentation code
- `Tests/Flip7CoreTests`: fast tests for the game rules
- `docs`: [product contract](docs/PRODUCT.md), [architecture](docs/ARCHITECTURE.md), and [issue workflow](docs/WORKFLOW.md)
