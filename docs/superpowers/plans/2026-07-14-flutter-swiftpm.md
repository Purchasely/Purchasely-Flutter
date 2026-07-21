# Flutter SwiftPM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the Flutter v6 plugin build with Swift Package Manager while retaining CocoaPods support.

**Architecture:** `ios/purchasely_flutter/Package.swift` exposes the existing Swift bridge from the Flutter-required package location, links the Purchasely iOS package and Flutter generated artifacts, and declares no plugin resources or privacy manifest because neither is owned by this target. CI builds a disposable SwiftPM-only copy of the example and continues the CocoaPods build path.

**Tech Stack:** SwiftPM, Swift, Xcode, Flutter plugin tooling, CocoaPods, GitHub Actions.

**Enhanced:** 2026-07-14  
**Reviewed:** 2026-07-14  
**Completed:** 2026-07-14

---

### Task 1: Define the Swift package

**Files:**
- Create: `purchasely/ios/purchasely_flutter/Package.swift`
- Move: `purchasely/ios/Classes/*` → `purchasely/ios/purchasely_flutter/Classes/*`
- Modify: `purchasely/ios/purchasely_flutter.podspec`, `purchasely/pubspec.yaml`

- [x] Add a package manifest with the plugin's iOS minimum target, exact Purchasely iOS package dependency, existing Swift bridge source path, and static Flutter-generated package linkage.
- [x] Verify that the plugin owns neither resources nor a privacy manifest; the Purchasely SDK dependency provides its own privacy metadata.
- [x] Run `swift package dump-package` and a simulator build against the generated Flutter SwiftPM integration.
- [x] Include the manifest in the atomic SwiftPM commit.

### Task 2: Preserve and validate both dependency managers

**Files:**
- Modify: `.github/workflows/ci.yml`, `purchasely/example/ios/Runner.xcodeproj/project.pbxproj`, `purchasely/example/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`

- [x] Add a macOS SwiftPM build job for a disposable CocoaPods-deintegrated copy of the example without removing the `pod install` and `Runner.xcworkspace` test path.
- [x] Run the CocoaPods simulator build and the SwiftPM simulator build locally.
- [x] Validate workflow YAML and include it in the atomic SwiftPM commit.
