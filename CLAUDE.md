# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Purchasely Flutter SDK - a Flutter plugin for integrating In-App Purchases and Subscriptions across App Store, Google Play Store, and Huawei App Gallery.

## Package Structure

This is a multi-package Flutter plugin repository:

- **`purchasely/`** - Main Flutter plugin with iOS (Swift) and Android (Kotlin) native implementations
- **`purchasely_google/`** - Google Play Billing extension for Android
- **`purchasely_android_player/`** - Android video player extension
- **`purchasely/example/`** - Example app demonstrating SDK usage

All three packages share the same version number and must be updated together during releases.

## Common Commands

### Install dependencies
```bash
cd purchasely && flutter pub get
cd purchasely_google && flutter pub get
cd purchasely_android_player && flutter pub get
```

### Run tests
```bash
cd purchasely && flutter test
```

### Run a single test file
```bash
cd purchasely && flutter test test/purchasely_flutter_test.dart
```

### Run static analysis
```bash
cd purchasely && flutter analyze
```

### Check formatting
```bash
cd purchasely && dart format --set-exit-if-changed .
```

### Build example app
```bash
cd purchasely/example && flutter build ios --simulator
cd purchasely/example && flutter build apk --debug
```

### Run Android native unit tests
```bash
cd purchasely/example && flutter build apk --debug  # First build to generate gradle wrapper
cd purchasely/example/android && ./gradlew :purchasely_flutter:testDebugUnitTest
```

### Run iOS native unit tests
```bash
cd purchasely/example/ios && pod install --repo-update
xcodebuild test -workspace Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -only-testing:RunnerTests
```

### Update iOS CocoaPods
```bash
cd purchasely/example/ios && pod update
```

### Validate package before publishing
```bash
cd purchasely && flutter pub publish --dry-run
```

### Version update (dry run)
```bash
sh publish.sh {VERSION}
```

### Publish to pub.dev
```bash
sh publish.sh {VERSION} true
```

## Architecture

### Flutter/Dart Layer (`purchasely/lib/`)
- `purchasely_flutter.dart` - Main API surface exposing the `Purchasely` class with all SDK methods and type definitions
- `native_view_widget.dart` - Native platform view widget for rendering presentations

### Native Plugin Communication
Uses Flutter MethodChannel (`purchasely`) and EventChannels (`purchasely-events`, `purchasely-purchases`, `purchasely-user-attributes`) for Dart ↔ Native communication.

### iOS Native (`purchasely/ios/Classes/`)
- `SwiftPurchaselyFlutterPlugin.swift` - Main plugin implementation handling all MethodChannel calls
- `PLY*+ToMap.swift` - Extension files for converting native SDK types to Flutter-compatible dictionaries
- `NativeView*.swift` - Native view factory and implementation for platform views

### Android Native (`purchasely/android/src/main/kotlin/io/purchasely/purchasely_flutter/`)
- `PurchaselyFlutterPlugin.kt` - Main plugin implementation handling all MethodChannel calls
- `NativeView*.kt` - Native view factory and implementation
- `PLY*Activity.kt` - Activity wrappers for native SDK screens

### Native SDK Dependencies
- iOS: `Purchasely` CocoaPod (version in `purchasely/ios/purchasely_flutter.podspec`)
- Android: `io.purchasely:core` Maven dependency (version in `purchasely/android/build.gradle`)

The `VERSIONS.md` file tracks which native SDK versions correspond to each Flutter SDK version.

## Release Process

See `RELEASE_GUIDE.md` for the complete release checklist. Key files updated during releases:

**Automatic (via `publish.sh`):**
- All `pubspec.yaml` version fields
- Bridge version in `SwiftPurchaselyFlutterPlugin.swift` and `PurchaselyFlutterPlugin.kt`
- All `CHANGELOG.md` files

**Manual:**
- `VERSIONS.md` - Add new version row
- `purchasely/ios/purchasely_flutter.podspec` - iOS SDK version
- `purchasely/android/build.gradle`, `purchasely_google/android/build.gradle`, `purchasely_android_player/android/build.gradle` - Android SDK version
