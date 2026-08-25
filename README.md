# Flip 7 for iOS

A native SwiftUI implementation of the base 94-card press-your-luck game. The first playable milestone is a local pass-and-play experience for 3–9 people on one iPhone or iPad.

This repository is an implementation prototype. It uses an original interface and must not be publicly distributed under the Flip 7 name or with commercial artwork until the owner confirms the necessary trademark and licensing rights.

## Requirements

- Xcode 26.6 or newer
- Swift 6.0 or newer
- iOS or iPadOS 18.0 or newer

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

See [MVP scope](docs/MVP.md), [architecture](docs/ARCHITECTURE.md), and [issue workflow](docs/WORKFLOW.md).

## Roadmap

Work is tracked in [GitHub issues](https://github.com/jxcg/flip7/issues). The sequenced MVP runs from issue [#1](https://github.com/jxcg/flip7/issues/1) through [#10](https://github.com/jxcg/flip7/issues/10). Every issue contains its dependencies, acceptance criteria, and context-reset protocol.
