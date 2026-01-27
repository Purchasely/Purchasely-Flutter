# Purchasely Flutter SDK Release Guide

This document describes the complete process for releasing a new version of the Purchasely Flutter SDK.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Release Checklist](#release-checklist)
4. [Detailed Steps](#detailed-steps)
5. [Files to Update](#files-to-update)
6. [Testing](#testing)
7. [Publishing](#publishing)
8. [Post-Release](#post-release)

---

## Overview

The Purchasely Flutter SDK consists of three packages:

- **`purchasely`** - The main Flutter plugin
- **`purchasely_android_player`** - Android player extension
- **`purchasely_google`** - Google Play specific functionality

Each release may involve updating the Flutter SDK version and/or the underlying native SDK versions (iOS and Android).

---

## Prerequisites

Before starting a release, ensure you have:

- [ ] Access to the [Purchasely-Flutter GitHub repository](https://github.com/Purchasely/Purchasely-Flutter)
- [ ] Flutter SDK installed and configured
- [ ] Xcode installed (for iOS builds and CocoaPods)
- [ ] Android Studio installed (for Android builds)
- [ ] CocoaPods installed (`gem install cocoapods`)
- [ ] GitHub CLI installed (`brew install gh`)

---

## Release Checklist

### Quick Reference

```
□ Determine new version numbers (Flutter SDK, iOS SDK, Android SDK)
□ Update VERSIONS.md
□ Update purchasely/pubspec.yaml
□ Update purchasely_android_player/pubspec.yaml (if applicable)
□ Update purchasely_google/pubspec.yaml (if applicable)
□ Update purchasely/ios/purchasely_flutter.podspec (iOS SDK version)
□ Update purchasely/android/build.gradle (Android SDK version, if applicable)
□ Update native bridge versions in Swift and Kotlin plugins
□ Update all CHANGELOG.md files
□ Run flutter pub get
□ Run pod update in example/ios/
□ Run flutter test
□ Run flutter analyze
□ Build iOS example
□ Build Android example
□ Commit, push, and create PR
□ Merge PR after review
□ Tag release
□ Publish to pub.dev (if applicable)
```

---

## Detailed Steps

### Step 1: Determine Version Numbers

Check the latest native SDK releases:

- **iOS SDK**: Check [Purchasely iOS releases](https://github.com/Purchasely/Purchasely-iOS)
- **Android SDK**: Check [Purchasely Android releases](https://github.com/Purchasely/Purchasely-Android)

Determine the new Flutter SDK version following [semantic versioning](https://semver.org/):

- **Major**: Breaking API changes
- **Minor**: New features, backward compatible
- **Patch**: Bug fixes, SDK updates

### Step 2: Update Version Files

#### 2.1 VERSIONS.md

Add a new row to the version table at the root of the repository:

```markdown
| 5.6.2   | 5.6.4       | 5.6.0           |
```

Format: `| Flutter Version | iOS Version | Android Version |`

#### 2.2 purchasely/pubspec.yaml

Update the `version` field:

```yaml
version: 5.6.2
```

#### 2.3 purchasely_android_player/pubspec.yaml

Update the `version` field to match:

```yaml
version: 5.6.2
```

#### 2.4 purchasely_google/pubspec.yaml

Update the `version` field to match:

```yaml
version: 5.6.2
```

### Step 3: Update Native SDK Dependencies

#### 3.1 iOS SDK Version

Edit `purchasely/ios/purchasely_flutter.podspec`:

```ruby
s.dependency 'Purchasely', '5.6.4'
```

#### 3.2 Android SDK Version (if updating)

Edit `purchasely/android/build.gradle`:

```gradle
implementation 'io.purchasely:purchasely:5.6.0'
```

### Step 4: Update Native Bridge Versions

#### 4.1 iOS Bridge Version

Edit `purchasely/ios/Classes/SwiftPurchaselyFlutterPlugin.swift`:

```swift
Purchasely.setSdkBridgeVersion("5.6.2")
```

#### 4.2 Android Bridge Version

Edit `purchasely/android/src/main/kotlin/io/purchasely/purchasely_flutter/PurchaselyFlutterPlugin.kt`:

```kotlin
Purchasely.sdkBridgeVersion = "5.6.2"
```

### Step 5: Update Changelogs

Update all three CHANGELOG.md files with the same entry:

- `purchasely/CHANGELOG.md`
- `purchasely_android_player/CHANGELOG.md`
- `purchasely_google/CHANGELOG.md`

Standard format:

```markdown
## 5.6.2
- Updated iOS Purchasely SDK to 5.6.4

Full changelog available at https://docs.purchasely.com/changelog/56
```

If updating Android SDK as well:

```markdown
## 5.6.2
- Updated iOS Purchasely SDK to 5.6.4
- Updated Android Purchasely SDK to 5.6.1

Full changelog available at https://docs.purchasely.com/changelog/56
```

### Step 6: Refresh Dependencies

```bash
# Main package
cd purchasely
flutter pub get

# Update iOS pods
cd example/ios
pod update
cd ../..

# Android player package
cd ../purchasely_android_player
flutter pub get

# Google package
cd ../purchasely_google
flutter pub get
```

---

## Files to Update

### Summary Table

| File | What to Update |
|------|----------------|
| `VERSIONS.md` | Add new version row with Flutter, iOS, Android versions |
| `purchasely/pubspec.yaml` | Update `version` field |
| `purchasely/CHANGELOG.md` | Add release notes |
| `purchasely/ios/purchasely_flutter.podspec` | Update iOS SDK dependency version |
| `purchasely/android/build.gradle` | Update Android SDK dependency version (if applicable) |
| `purchasely/ios/Classes/SwiftPurchaselyFlutterPlugin.swift` | Update bridge version |
| `purchasely/android/.../PurchaselyFlutterPlugin.kt` | Update bridge version |
| `purchasely_android_player/pubspec.yaml` | Update `version` field |
| `purchasely_android_player/CHANGELOG.md` | Add release notes |
| `purchasely_google/pubspec.yaml` | Update `version` field |
| `purchasely_google/CHANGELOG.md` | Add release notes |
| `purchasely/example/ios/Podfile.lock` | Updated automatically by `pod update` |
| `purchasely/example/pubspec.lock` | Updated automatically by `flutter pub get` |

---

## Testing

### Run Unit Tests

```bash
cd purchasely
flutter test --coverage
```

All tests should pass. Current test suite includes 165+ tests.

### Run Static Analysis

```bash
# Main package
cd purchasely
flutter analyze lib/

# Android player
cd ../purchasely_android_player
flutter analyze lib/

# Google package
cd ../purchasely_google
flutter analyze lib/
```

Ensure no errors. Warnings and info messages are acceptable.

### Build Example Apps

#### iOS Simulator Build

```bash
cd purchasely/example
flutter build ios --simulator
```

#### Android APK Build

```bash
cd purchasely/example
flutter build apk --debug
```

### Manual Testing (Recommended)

1. Run the example app on iOS simulator
2. Run the example app on Android emulator
3. Verify SDK initialization works
4. Test presenting a paywall
5. Verify event callbacks are received

---

## Publishing

### Create Pull Request

```bash
# Stage all changes
git add -A

# Commit with descriptive message
git commit -m "Release 5.6.2: Update iOS SDK to 5.6.4

## SDK Updates
- Bump Flutter SDK version from 5.6.1 to 5.6.2
- Update iOS Purchasely SDK from 5.6.2 to 5.6.4

## Changes
- Updated VERSIONS.md
- Updated all CHANGELOG.md files
- Updated native bridge versions"

# Push to remote
git push -u origin version/5.6.2

# Create PR
gh pr create --title "Release 5.6.2: Update iOS SDK to 5.6.4" \
  --body "## Summary
This PR updates the Purchasely Flutter SDK to version 5.6.2.

## SDK Updates
- Bump Flutter SDK version from 5.6.1 to 5.6.2
- Update iOS Purchasely SDK from 5.6.2 to 5.6.4

## Testing
- ✅ All unit tests pass
- ✅ Static analysis passes for all packages
- ✅ iOS build successful
- ✅ Android build successful" \
  --base main
```

### Merge and Tag

After PR review and approval:

1. Merge the PR to `main`
2. Create a release tag:

```bash
git checkout main
git pull origin main
git tag -a v5.6.2 -m "Release 5.6.2"
git push origin v5.6.2
```

### Publish to pub.dev (Optional)

```bash
cd purchasely
flutter pub publish --dry-run  # Verify first
flutter pub publish

cd ../purchasely_android_player
flutter pub publish

cd ../purchasely_google
flutter pub publish
```

---

## Post-Release

### Verify Release

1. Check the [GitHub releases page](https://github.com/Purchasely/Purchasely-Flutter/releases)
2. Verify the tag is created
3. Check [pub.dev](https://pub.dev/packages/purchasely_flutter) for the new version (if published)

### Announce Release

1. Update documentation at [docs.purchasely.com](https://docs.purchasely.com)
2. Notify relevant teams/channels about the new release

### Monitor for Issues

- Watch for bug reports related to the new release
- Monitor GitHub issues
- Be prepared to release a hotfix if critical issues are found

---

## Troubleshooting

### Common Issues

#### Pod install fails

```bash
cd purchasely/example/ios
pod deintegrate
pod cache clean --all
pod install
```

#### Flutter pub get fails

```bash
flutter clean
flutter pub cache repair
flutter pub get
```

#### Build fails after SDK update

1. Clean all builds: `flutter clean`
2. Remove iOS build folder: `rm -rf purchasely/example/ios/build`
3. Remove Android build folder: `rm -rf purchasely/example/android/build`
4. Re-run `flutter pub get` and `pod update`

---

## Version History

| Date | Version | Notes |
|------|---------|-------|
| 2025-01-XX | 5.6.2 | Updated iOS SDK to 5.6.4 |
| 2025-01-XX | 5.6.1 | Updated iOS SDK to 5.6.2 |
| 2025-01-XX | 5.6.0 | Initial 5.6.x release |

---

## Contact

For questions about the release process, contact the Purchasely engineering team.