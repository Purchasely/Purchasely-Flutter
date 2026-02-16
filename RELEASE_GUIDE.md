# Purchasely Flutter SDK Release Guide

This document describes the complete process for releasing a new version of the Purchasely Flutter SDK.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Release Process](#release-process)
4. [Files Reference](#files-reference)
5. [Troubleshooting](#troubleshooting)

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

---

## Release Process

### Step 1: Prepare the Release

Run the publish script in dry-run mode to update all version numbers and changelogs:

```bash
sh publish.sh {VERSION}
```

For example:
```bash
sh publish.sh 5.6.2
```

This script will automatically:
- Update `version` in all `pubspec.yaml` files
- Update the SDK bridge version in iOS and Android native plugins
- Add a changelog entry for the new version in all `CHANGELOG.md` files (if not already present)
- Run `flutter pub publish --dry-run` to validate

> **Note:** The `--dry-run` for `purchasely_google` will fail because it depends on `purchasely_flutter ^{VERSION}` which isn't published yet. This is expected.

> **Known issues with publish.sh:**
> - The changelog URL is hardcoded to `/changelog/56`. You must manually update it to match the version (e.g., `/changelog/57` for 5.7.0).
> - The bridge version lines use tab indentation, but the codebase uses spaces. Fix the indentation in `SwiftPurchaselyFlutterPlugin.swift` and `PurchaselyFlutterPlugin.kt` after running the script.
> - The changelog entries only contain the link. Add a brief package-specific summary of changes (see Step 1b).

### Step 1b: Update Changelogs

After running `publish.sh`, update each `CHANGELOG.md` with:
1. The correct changelog URL for this version
2. A brief summary of changes relevant to each package

For example:
- `purchasely/CHANGELOG.md`: mention iOS SDK, Android SDK, and bridge version updates
- `purchasely_google/CHANGELOG.md`: mention Google Play SDK update only
- `purchasely_android_player/CHANGELOG.md`: mention Player SDK update only


### Step 2: Update iOS SDK Version (if needed)

If the iOS Purchasely SDK version needs to be updated, edit the podspec file:

**File:** `purchasely/ios/purchasely_flutter.podspec`

```ruby
s.dependency 'Purchasely', '5.6.4'
```

### Step 3: Update Android SDK Version (if needed)

If the Android Purchasely SDK version needs to be updated, edit the `build.gradle` file in **each package folder** and the example app:

**Plugin files to update:**
- `purchasely/android/build.gradle` — `io.purchasely:core`
- `purchasely_google/android/build.gradle` — `io.purchasely:google-play`
- `purchasely_android_player/android/build.gradle` — `io.purchasely:player`

**Example app file to update:**
- `purchasely/example/android/app/build.gradle` — `io.purchasely:google-play` and `io.purchasely:player`

### Step 3b: Check Android minSdkVersion (if needed)

When bumping the native Android SDK, check if the new version requires a higher `minSdkVersion`. If so, update it in **all** `build.gradle` files:

- `purchasely/android/build.gradle`
- `purchasely_google/android/build.gradle`
- `purchasely_android_player/android/build.gradle`
- `purchasely/example/android/app/build.gradle`

> **Example:** `io.purchasely:core:5.7.0` raised the minimum from 21 to 23.

### Step 4: Update VERSIONS.md

Add a new row to `VERSIONS.md` at the root of the repository:

```markdown
| 5.6.2   | 5.6.4       | 5.6.0           |
```

Format: `| Flutter Version | iOS Version | Android Version |`

### Step 5: Refresh Dependencies

```bash
# Main package
cd purchasely
flutter pub get

# Update iOS pods
cd example/ios
pod update
cd ../..

# Return to root
cd ..
```

### Step 6: Run Tests

```bash
cd purchasely
flutter test
flutter analyze lib/
cd ..
```

### Step 7: Commit and Push

```bash
git add -A
git commit -m "Release {VERSION}: Update iOS SDK to X.X.X

## SDK Updates
- Bump Flutter SDK version to {VERSION}
- Update iOS Purchasely SDK to X.X.X
- Update Android Purchasely SDK to X.X.X (if applicable)"

git push -u origin version/{VERSION}
```

### Step 8: Create Pull Request

Create a PR against `main` and wait for CI to pass.

### Step 9: Publish

Once CI passes and the PR is approved, publish by running:

```bash
sh publish.sh {VERSION} true
```

This will publish all three packages to pub.dev.

### Step 10: Merge and Tag

After publishing:

1. Merge the PR to `main`
2. Create a release tag:

```bash
git checkout main
git pull origin main
git tag -a v{VERSION} -m "Release {VERSION}"
git push origin v{VERSION}
```

---

## Files Reference

### Files Updated by publish.sh

| File | What is Updated |
|------|-----------------|
| `purchasely/pubspec.yaml` | `version` field |
| `purchasely_google/pubspec.yaml` | `version` field, `purchasely_flutter` dependency |
| `purchasely_android_player/pubspec.yaml` | `version` field, `purchasely_flutter` dependency |
| `purchasely/ios/Classes/SwiftPurchaselyFlutterPlugin.swift` | Bridge version |
| `purchasely/android/.../PurchaselyFlutterPlugin.kt` | Bridge version |
| `purchasely/CHANGELOG.md` | New version entry |
| `purchasely_google/CHANGELOG.md` | New version entry |
| `purchasely_android_player/CHANGELOG.md` | New version entry |

### Files to Update Manually

| File | When to Update |
|------|----------------|
| `VERSIONS.md` | Always - add new version row |
| `purchasely/ios/purchasely_flutter.podspec` | When iOS SDK version changes |
| `purchasely/android/build.gradle` | When Android SDK version changes (dependency + minSdkVersion) |
| `purchasely_google/android/build.gradle` | When Android SDK version changes (dependency + minSdkVersion) |
| `purchasely_android_player/android/build.gradle` | When Android SDK version changes (dependency + minSdkVersion) |
| `purchasely/example/android/app/build.gradle` | When Android SDK version changes (google-play + player deps, minSdkVersion) |
| All `CHANGELOG.md` files | Fix URL and add package-specific summaries after publish.sh |
| `SwiftPurchaselyFlutterPlugin.swift` | Fix tab→space indentation after publish.sh |
| `PurchaselyFlutterPlugin.kt` | Fix tab→space indentation after publish.sh |

---

## Troubleshooting

### Pod install fails

```bash
cd purchasely/example/ios
pod deintegrate
pod cache clean --all
pod install
```

### Flutter pub get fails

```bash
flutter clean
flutter pub cache repair
flutter pub get
```

### Build fails after SDK update

1. Clean all builds: `flutter clean`
2. Remove iOS build folder: `rm -rf purchasely/example/ios/build`
3. Remove Android build folder: `rm -rf purchasely/example/android/build`
4. Re-run `flutter pub get` and `pod update`

### Publish fails

- Ensure you're logged in: `flutter pub login`
- Check package score: `flutter pub publish --dry-run`
- Verify all dependencies are published first

---

## Quick Reference Checklist

```
□ Run: sh publish.sh {VERSION}
□ Fix changelog URLs (publish.sh hardcodes /changelog/56)
□ Add package-specific changelog summaries
□ Fix tab→space indentation in SwiftPurchaselyFlutterPlugin.swift and PurchaselyFlutterPlugin.kt
□ Update purchasely/ios/purchasely_flutter.podspec (iOS SDK version, if needed)
□ Update all build.gradle files (Android SDK version, if needed)
□ Update purchasely/example/android/app/build.gradle (Android SDK deps, if needed)
□ Check Android minSdkVersion requirements (if Android SDK version changed)
□ Update VERSIONS.md with new version row
□ Run: flutter pub get && pod update (in example/ios)
□ Run: flutter test && flutter analyze lib/
□ Commit, push, create PR
□ Wait for CI to pass
□ Run: sh publish.sh {VERSION} true
□ Merge PR and create git tag
```

---

## Contact

For questions about the release process, contact the Purchasely engineering team.