# Flutter SwiftPM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the Flutter v6 plugin build with Swift Package Manager while retaining CocoaPods support.

**Architecture:** `Package.swift` exposes the existing Swift bridge, links the Purchasely iOS package and Flutter generated artifacts, and declares only required source/resource/privacy metadata. CI builds the SwiftPM example path and continues the CocoaPods build path.

**Tech Stack:** SwiftPM, Swift, Xcode, Flutter plugin tooling, CocoaPods, GitHub Actions.

**Enhanced:** 2026-07-14  
**Reviewed:** 2026-07-14  
**Completed:** Pending

---

### Task 1: Define the Swift package

**Files:**
- Create: `purchasely/ios/Package.swift`
- Modify: `purchasely/ios/Classes/*` only for package-safe imports if compilation requires it.

- [ ] Add a package manifest with the plugin's iOS minimum target, the Purchasely iOS package dependency, existing Swift bridge source path, and framework linkage matching the podspec.
- [ ] Add resources or privacy metadata only after verifying they are owned by the plugin target rather than the Purchasely SDK target.
- [ ] Run `swift package dump-package` and a simulator build against the generated Flutter SwiftPM integration.
- [ ] Commit with `feat(ios): add Flutter plugin SwiftPM manifest`.

### Task 2: Preserve and validate both dependency managers

**Files:**
- Modify: `.github/workflows/ci.yml`, `purchasely/example/ios/Podfile` only if setup requires explicit selection.

- [ ] Add a macOS SwiftPM build job for the example without removing the `pod install` and `Runner.xcworkspace` test path.
- [ ] Run the CocoaPods simulator build and the SwiftPM simulator build locally or on CI.
- [ ] Validate workflow YAML and commit with `ci(ios): build Flutter plugin with SwiftPM`.
