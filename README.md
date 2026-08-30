# Flip7

`Flip7` is the private working title for a digital press-your-luck card game. Draw cards to build your score, then choose whether to stay or risk another draw.

The rules aren't tied to one interface or platform.

## Current app

The current app is built natively with SwiftUI for iPhone and iPad. It supports iOS and iPadOS 18.0 or newer.

The repository and internal code names remain `flip7` and `Flip7Core` unless separately approved. The final app name will be chosen during release work while keeping the same gameplay mechanics.

The interface, artwork, card faces, logo, packaging, and wording will be original. Commercial assets and copy will not be used.

## Build and test

You need Xcode 26.6 or newer and Swift 6.0 or newer.

Test the game rules:

```sh
swift test -Xswiftc -warnings-as-errors
```

Build the app without signing:

```sh
xcodebuild -project flip7.xcodeproj -scheme flip7 -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/flip7-derived-data CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES build
```

## Inside the repository

- `flip7/Core`: game rules kept separate from the interface
- `flip7`: SwiftUI app and presentation code
- `Tests/Flip7CoreTests`: fast tests for the game rules
- `docs`: [product contract](docs/PRODUCT.md), [architecture](docs/ARCHITECTURE.md), and [issue workflow](docs/WORKFLOW.md)
