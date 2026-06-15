# iOS App

SwiftUI MVP for `What Did You Do Today`.

Open `WhatDidYouDo.xcodeproj` in Xcode.

## Stack

- SwiftUI
- MVVM
- Mock data first
- iOS 17+

## Structure

- `Sources/App`: app entry and root navigation.
- `Sources/DesignSystem`: card, button, text field, color, and typography foundations.
- `Sources/Features`: MVP feature views.
- `Sources/Models`: local view models for MVP UI state.
- `Sources/Mock`: free core chore items and sample family data.
- `Resources`: asset catalog and app resources.
- `Tests`: unit and UI test files.

## MVP Screens

- `LoginView`
- `CreateFamilyView`
- `HomeView`
- `ChoreSelectionView`

## Local Validation

If Xcode's iOS simulator runtime is installed, build the app with:

```sh
xcodebuild -project apps/ios/WhatDidYouDo.xcodeproj -scheme WhatDidYouDo -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Source typecheck:

```sh
xcrun --sdk iphonesimulator swiftc -target x86_64-apple-ios17.0-simulator -swift-version 6 -typecheck $(find apps/ios/Sources -name '*.swift' | sort)
```
