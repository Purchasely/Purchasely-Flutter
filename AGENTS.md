# AGENTS.md

## Overview

Purchasely Flutter SDK: a Flutter plugin for in-app purchases and subscriptions (App Store, Google Play, Huawei AppGallery). It wraps the native Purchasely iOS and Android SDKs (version map in `VERSIONS.md`).

## Packages

All three share one version number and are released together.

- `purchasely/`: main plugin (Dart, iOS Swift, Android Kotlin). Pub name `purchasely_flutter`.
- `purchasely_google/`: Google Play extension (Android only).
- `purchasely_android_player/`: Android video player extension.
- `purchasely/example/`: example app, also hosts the native unit tests and `integration_test/` E2E tests.

## Commands

Run each from the package directory (`purchasely`, `purchasely_google`, `purchasely_android_player`).

```bash
flutter pub get
flutter test                          # single file: flutter test test/bridge_test.dart
flutter analyze --no-fatal-infos --no-fatal-warnings
dart format --set-exit-if-changed .
```

`purchasely_google` needs a local override of `purchasely_flutter` (`path: ../purchasely`) in a `pubspec_overrides.yaml`, as CI does.

Native tests:

```bash
# Android (build once first to generate the gradle wrapper)
cd purchasely/example && flutter build apk --debug
cd android && ./gradlew :purchasely_flutter:testDebugUnitTest
# iOS (hostless RunnerTests bundle)
cd purchasely/example/ios && pod install --repo-update
xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=<an installed iPhone>' -only-testing:RunnerTests
```

## Architecture

- Dart (`purchasely/lib/`): `purchasely_flutter.dart` is the public `Purchasely` class and types. `native_view_widget.dart` is the platform view. `src/` holds the v6 builders and models (`purchasely_builder`, `presentation_builder`, `presentation_request`, `bridge`, `action_interceptor`, `transition`, `web_redemption`, and others).
- Channels: MethodChannel `purchasely`. EventChannels `purchasely-events`, `purchasely-purchases`, `purchasely-user-attributes`, `purchasely-presentation-events`, `purchasely-web-redemption`. Change both native sides when you change a channel contract.
- iOS (`purchasely/ios/purchasely_flutter/Classes/`): `SwiftPurchaselyFlutterPlugin.swift` handles all calls, `PLY*+ToMap.swift` convert native types to maps, `NativeView*.swift` is the platform view. Packaged for CocoaPods (`purchasely/ios/purchasely_flutter.podspec`, iOS 13.4) and SwiftPM (`purchasely/ios/purchasely_flutter/Package.swift`). Keep both in step.
- Android (`purchasely/android/src/main/kotlin/io/purchasely/purchasely_flutter/`): `PurchaselyFlutterPlugin.kt` handles all calls, `NativeView*.kt` is the platform view. Kotlin 2.3.21, JVM 17, minSdk 23, compileSdk 36. The build opts out of AGP 9 built-in Kotlin, so keep that setting.
- `VERSIONS.md` maps each Flutter SDK version to its native iOS and Android versions.

## Release

Full checklist in `RELEASE_GUIDE.md`. Run `sh publish.sh {VERSION}` for a dry run (`sh publish.sh {VERSION} true` publishes locally). It updates:
- the `version:` of the three `pubspec.yaml` files
- the bridge version in `SwiftPurchaselyFlutterPlugin.swift` (`.sdkBridgeVersion(...)`) and `PurchaselyFlutterPlugin.kt` (`Purchasely.sdkBridgeVersion`)
- the three `CHANGELOG.md` files

Update by hand:
- a new `VERSIONS.md` row
- the iOS SDK version in `purchasely_flutter.podspec` (`s.dependency`, and `s.version`) and in `Package.swift` (`exact:`)
- the Android SDK version in the `build.gradle` of all three packages (`io.purchasely:core`, `google-play`, `player`)

Publishing is automated: pushing a tag `v{VERSION}` runs `publish.yml`, which checks that all versions and the tag match, then publishes the three packages to pub.dev with OIDC (environment `pub.dev`).

## Testing scope of the bridge

The bridge tests its own code and its calls to the native SDK. The native SDK tests its own behavior after the bridge calls it.

Test these three things:

1. **The bridge code.** Argument parsing, type conversion, default values, validation, error mapping, and the no-op of a platform-specific method.
2. **The call to the native SDK.** The JS, TypeScript or Dart call reaches the native bridge with the expected method name and argument format, and the native bridge accepts that format.
3. **The result that the bridge can see.** When the call has a completion (callback, promise, `Future` result or returned value), check it on a real device in the E2E suite: success or error, and the returned value. Examples: `setUserAttribute` has a listener callback, and `getUserAttribute` returns the value that was set. When the call has no completion (for example `emit`), stop at points 1 and 2.

Do not test:

- What the native SDK does after the call: network requests, backend reception, event delivery, StoreKit or Google Play Billing behavior. The native SDK owns this part.
- The backend or an analytics database (for example ClickHouse) to prove that a call worked.
- New iOS tests that swizzle a native SDK method. Existing swizzle tests stay.

## CI

- `ci.yml` (PRs and pushes to main, master, develop): format, analyze, Dart tests, Android and iOS native tests, iOS (CocoaPods and SwiftPM) and Android builds, a Flutter 3.44 / AGP 9 job, version consistency. Dart and iOS jobs use Flutter 3.24.x. Android jobs use Flutter 3.44.0 and Java 17.
- Keep `minSdk = 23` in `purchasely/example/android/app/build.gradle`. A local `flutter build` rewrites it, and `version-check` fails when it is gone. Restore it before you commit.
- `e2e-android.yml` and `e2e-ios.yml` run on a real backend. They start when a PR opens and on the `run-ci` label, not on every push. Read the test log, not only the job status. The test catalog is `purchasely/example/integration_test/E2E_TEST_INDEX.md`.

## Conventions

- Lint config: `purchasely/analysis_options.yaml`. CI runs analyze without fatal infos or warnings, but format is strict.
- Tests are Dart (`purchasely/test/`), Kotlin or Java with Mockito (Android), and XCTest (iOS).
