# Flip7

Flip7 is a digital press-your-luck card game about drawing cards, building a score, and deciding when to stop.

The interface and artwork must be original. Do not publicly distribute the app under the Flip 7 name until the owner confirms the required trademark and licensing rights.

This repository currently contains a native SwiftUI app for iOS and iPadOS.

## Requirements

Development requires Xcode 26.6 or newer and Swift 6.0 or newer. The app supports iOS and iPadOS 18.0 or newer.

## Build and test

Run core tests:

```sh
swift test -Xswiftc -warnings-as-errors
```

Build the app without signing:

```sh
xcodebuild -project flip7.xcodeproj -scheme flip7 -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/flip7-derived-data CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES build
```

## Architecture

- `flip7/Core`: deterministic, UI-independent game rules
- `flip7`: SwiftUI application and presentation code
- `Tests/Flip7CoreTests`: fast rules-engine tests
- `docs`: product, architecture, and delivery decisions

See the [complete product contract](docs/PRODUCT.md), [architecture](docs/ARCHITECTURE.md), and [issue workflow](docs/WORKFLOW.md).
