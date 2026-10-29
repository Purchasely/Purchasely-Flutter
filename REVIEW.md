# REVIEW.md

The review and merge rules of the Purchasely SDKs: Android, iOS, React Native, Flutter and
Cordova. Each repo has a copy of this file. Sections 1 to 4 are the same in each copy. Section 5
is the part of that repo.

We cannot replace a released SDK version. Maven Central, npm and pub.dev keep each published
version, and the integrating apps keep the version they shipped in the stores. A fix is a new
version, and each app developer must ship an app update to get it. A backend flag can limit
some failures before that update. So we control a change before the merge, and again before the
release.

Words in this file:

- **Author**: the person who wrote the change, or who drove the agent that wrote it.
- **Platform reviewer**: an engineer of the platform that the change affects, who is not the
  author. For a bridge change (React Native, Flutter, Cordova), an engineer of the native SDK
  that the change affects.
- **SDK lead**: the lead of the mobile SDKs (`kherembourg`).

## 1. Tiers

The behavior that a change can break sets the tier. The author and the size of the diff do not.
Each tier includes the checks of the lower tiers.

| Tier | Meaning | Before merge | Before release |
|------|---------|--------------|----------------|
| **T0** | No effect on an integrating app at runtime, at build time or in its store review. | The required checks ran on the head commit and passed. All review threads are resolved. One approval from a team member who is not the author. | No test for this change. The release checklist of the repo still applies to every release. |
| **T1** | A contained runtime change that QA can see. | The approval comes from a platform reviewer. | Smoke test of the sample app on the affected area. |
| **T2** | Can break integrating apps, revenue or app start; or QA cannot easily see it; or an app needs an update to recover. | The SDK lead is the author or approves. A deep AI review of the final code (Greptile, or a Codex review at high effort), with its threads resolved. The PR body fills **Integrator impact** and **Mitigation after release**. | A row in the release test plan of the repo for each affected flow (purchase, restore, paywall display, start), run in the release QA. A release candidate when the change touches purchase or start. Migration steps in the version note when an app must change. |
| **T3** | Controls publication, artifact integrity, signing, credentials, release permissions or a required check. Also a change that deletes data on purpose with no way to recover it. | A second approval from a person who is not the author. An engineer of another SDK platform can give it. Do not use the admin bypass. | The release checklist of the repo, with a record of the artifact, its destination, its version and the publication permissions. A dry run where the registry has one. |

## 2. The matrix

The highest tier of all the rows that a PR matches is the tier of the PR. When a file matches
two rows, the more specific row wins. Section 5 gives the paths of each area in the repo.

| Area | Typical signals | Tier |
|------|-----------------|------|
| Docs, README, code comments | `docs/`, `*.md`, comments only | T0 |
| Process docs | `AGENTS.md`, `REVIEW.md`, release docs | T1. The SDK lead is the author or approves. |
| Sample app UI | screens and texts of the sample apps | T0 |
| Sample app configuration | API key, backend host, Builder options, application id, signing, install scripts | T1 |
| Tests: new tests, corrected tests | test folders | T0 |
| Tests: a removed test or a weaker assertion | test folders | The tier of the risk that the test controls. |
| Internal refactor, no behavior change, no public declaration changed | internal code only | T1 |
| Logs and debug tools | logger, log levels | T1. T2 if it runs on the main thread or logs user data. |
| Paywall rendering, layout, components, localization | renderer, layout engine, fonts, images, string files | T1. T2 if it can block a display or a purchase, crash the app, change the format arguments of a string, or change action handling, flow navigation or TV focus. |
| Media player | video and audio players | T1 for the appearance. T2 for lifecycle, threads, the shared audio session or resource ownership. |
| Backend API contract | request and response models, parsers, endpoints | T1. T2 if a parse failure can block a display or a purchase. |
| Network and security | TLS, hosts, proxy, API key and headers, interceptors, compression, timeouts, retries | T2: a failure affects every call of every app. |
| Analytics and SDK events | event names, properties, triggers, identity, delivery, deduplication | T2: a wrong event corrupts dashboards and A/B test results, and QA does not see it. T1 for an implementation change that keeps all of these. |
| Public API | any public declaration that an integrating app can use (section 5) | T2. A breaking change also needs migration steps in the version note, and a major version or an exception that the SDK lead writes in the PR body. |
| Purchase, restore, entitlements, receipts and tokens | store billing clients, transaction observers, sync with the backend, web checkout | T2 |
| User identity | login, logout, anonymous ID, purchase transfer, the cache of each user | T2 |
| Start, lifecycle, threads | `start()`, application hooks, coroutines and dispatchers, main thread work, background tasks | T2: a crash or an ANR at start hits every user of every integrating app. |
| Local data and migrations | SharedPreferences, DataStore, UserDefaults, Keychain, caches, file formats | T2: we cannot roll back data on a device. |
| Deeplinks and webviews | deeplink routing, redemption links, preview links, webview settings and navigation | T2: input from outside the app. |
| Campaigns and triggers | trigger evaluation, capping, exposure | T2: an error can show a paywall to every user. |
| Consent and privacy | consent, legal basis, data processing purposes, redaction, data export | T2: legal risk that QA does not see. |
| Crash handler and telemetry | uncaught exception handler, telemetry exporter | T2: it can hide crashes of the app or send data to the wrong place. |
| Backend configuration and its defaults | the configuration model and its default values | T2: it is the rollback path of rule 5. |
| Build compatibility and runtime dependencies | min OS, compile SDK, language and toolchain versions, store billing libraries, any dependency of a published artifact (also transitive) | T2 |
| Build-only and test-only dependencies | test libraries, build plugins with no effect on the published artifact | T1 |
| Consumer rules, library manifest, consumer lint | `consumer-rules.pro`, the `AndroidManifest.xml` of a library, published lint checks | T2: they act only in the build or the release build of the app. |
| Privacy manifest, required-reason APIs, permissions | `PrivacyInfo.xcprivacy`, manifest permissions | T2: the store review of the app can reject it. |
| Generated or rewritten files | files that a script builds or rewrites | T2 |
| Hybrid bridge, contained change | bridge code that keeps the arguments, defaults, type mappings, errors, results, callbacks and listener lifetime | T1 |
| Hybrid bridge, contract change | a change to one of the items above, or to purchase, restore, identity or entitlement behavior, also with no signature change | T2 |
| Native SDK version in a bridge | the native pins: `build.gradle`, `.podspec`, `Package.swift`, `plugin.xml`, lockfiles | T2 minimum, or the highest tier of the native changes that the new version brings. Keep all native pins at the same version. |
| CI: comments and formatting | workflow files, no behavior change | T0 |
| CI: tests and reports | test workflows, CI scripts, Actions version bumps | T1 |
| Publication, signing, credentials, required checks | publish workflows and scripts, signing, secrets, `permissions:`, the composition of the published artifact, a required check | T3, wherever the code is. |
| The release | version tag, GitHub release, publication to the registry | T3 |

## 3. Rules

1. **Do not count the author as a reviewer.** Do not count an agent as a reviewer. Its review
   is evidence for the human reviewers.
2. **Bind the checks to the head commit.** Before the merge, the required checks ran on the
   head commit and passed. A skipped check is not a pass: start the run again (section 5 says
   how).
3. **Keep or renew the approval after new commits.**
   - For T2 and T3, a new commit that changes production code, build files or CI needs a new
     approval from the platform reviewer.
   - A commit that changes only T0 files or process docs keeps the approval.
   - A rebase keeps the approval when `git range-diff <old-base>..<old-head> <new-base>..<new-head>`
     shows no change in the commits of the PR. Write the old and new head SHAs and the result in a
     PR comment. Then run the required checks on the new head.
   - The repos do not dismiss stale approvals automatically. The person who merges checks the
     approval against these rules.
4. **Change a tier with a reason.** Anyone, and an AI review, can propose a higher tier. A human
   reviewer confirms the tier. To lower a tier, write the reason in the PR body and get the
   agreement of the SDK lead and of a reviewer who is not the author. Do not go below a row of
   the matrix.
5. **Add a kill switch when you can.** Give a T2 feature a backend configuration flag that turns
   it off, and test the off state. In the PR, write the flag path, the off value, the platforms
   and any app setting that overrides it. The SDK reads the configuration only after the
   configuration response of `start()`. So a flag cannot stop code that runs before it: the
   start path, data migrations, the crash handler. Examples:
   - `telemetry.mode` = `"disabled"`: Android and iOS.
   - `user_subscription_auto_fetch_activated` = `false`: Android and iOS. It stops only the
     automatic subscription fetch.
   - `allow_campaigns` = `false`: Android and iOS. On iOS, an explicit app setting overrides it.
   - `request_body_gzip_enabled` = `false`: Android.

## 4. The PR body

Every PR body has these three sections:

```markdown
## Tier
<T0, T1, T2 or T3>: <the row of the matrix that sets it, and the evidence>.

## Integrator impact
What an integrating app sees or must do. Copy the "Impact for the application" line of the
version note when the repo has one. "None" when apps see no difference.

## Mitigation after release
How we limit the damage if this change is wrong in a released version: the backend flag
(rule 5), a hotfix release, a workaround for app developers. "Not needed" for T0.
```

Add them to the sections that the repo already asks for (section 5). Do not repeat a section
that the repo already has under another name. When the `pr-ready` skill writes the body, keep
its headings (`What`, `Why`, `How to verify`, `Notes`, `Deploy`, `Greptile`) and add the three
sections after `Why`. A PR body does not replace a required file (version note, feature doc).


## 5. This repo: Flutter

### Paths of each area

These paths are examples. Classify every other file by the behavior it can change.

| Area | Paths |
|------|-------|
| Public API | every public Dart declaration under the `lib/` folder of a published package. In `purchasely`: `lib/purchasely_flutter.dart` and the files that it exports from `lib/src/` (`action_interceptor`, `ply_models`, `presentation`, `presentation_builder`, `presentation_outcome`, `presentation_request`, `purchasely_builder`, `transition`, and three names of `web_redemption`), and `lib/native_view_widget.dart` (`PLYPresentationView`). Also `purchasely_google/lib/` and `purchasely_android_player/lib/`. `sdk_public_doc.md` is a reference, not the full list. |
| Hybrid bridge, Dart side | `purchasely/lib/purchasely_flutter.dart`, `purchasely/lib/src/` (`bridge.dart`, `ply_transformers.dart`), `purchasely/lib/native_view_widget.dart`, the `*_method_channel.dart` and `*_platform_interface.dart` files of `purchasely_google/lib/` and `purchasely_android_player/lib/` |
| Hybrid bridge, Android side | `purchasely/android/src/main/kotlin/io/purchasely/purchasely_flutter/` (`PurchaselyFlutterPlugin.kt`, `NativeView.kt`, `NativeViewFactory.kt`), `purchasely_google/android/src/main/kotlin/`, `purchasely_android_player/android/src/main/kotlin/` |
| Hybrid bridge, iOS side | `purchasely/ios/purchasely_flutter/Classes/` (`SwiftPurchaselyFlutterPlugin.swift`, `NativeView*.swift`, `PLY*+ToMap.swift`, `PurchaselyFlutterPlugin.h` and `.m`) |
| Channel contract | the MethodChannel `purchasely` and the EventChannels `purchasely-events`, `purchasely-purchases`, `purchasely-user-attributes`, `purchasely-presentation-events`, `purchasely-web-redemption`. A change on one side needs the same change on the two other sides. |
| Purchase and restore | the purchase, restore and synchronization methods in the three sides of the bridge, `purchasely_google/` |
| Native SDK version in a bridge | `purchasely/android/build.gradle` (`io.purchasely:core`), `purchasely_google/android/build.gradle` (`io.purchasely:google-play`), `purchasely_android_player/android/build.gradle` (`io.purchasely:player`), `purchasely/ios/purchasely_flutter.podspec` (`s.dependency 'Purchasely'`), `purchasely/ios/purchasely_flutter/Package.swift` (`exact:`), `purchasely/example/android/app/build.gradle`, `purchasely/example/ios/Podfile.lock`. The lockfiles `purchasely/pubspec.lock` and `purchasely/example/pubspec.lock` pin the Dart dependencies. |
| Build compatibility | the `environment:` and `dependencies:` of the three `pubspec.yaml` files, `purchasely/android/build.gradle` (Kotlin, `minSdk`, `compileSdk`, JVM target), `purchasely/android/gradle.properties`, the `build.gradle` files of the two extensions, `purchasely_flutter.podspec` (`s.platform`), `Package.swift` (`platforms:`) |
| Library manifest | `*/android/src/main/AndroidManifest.xml` of the three packages |
| Sample app UI | `purchasely/example/lib/` (screens and texts) |
| Sample app configuration | `purchasely/example/lib/main.dart` (API key and start options), `purchasely/example/android/app/build.gradle` (`applicationId`, `minSdk = 23`, signing), `purchasely/example/android/app/src/main/AndroidManifest.xml`, `purchasely/example/ios/Podfile`, `purchasely/example/ios/Runner/Info.plist`, `purchasely/example/ios/Runner/Runner.entitlements`, `purchasely/example/ios/Configuration.storekit`, `purchasely/example/integration_test/helpers/e2e_start.dart`. `purchasely_google/example/` and `purchasely_android_player/example/` contain only build files, not an app. |
| Tests | `purchasely/test/`, `purchasely_google/test/`, `purchasely_android_player/test/`, `purchasely/android/src/test/`, `purchasely/example/ios/RunnerTests/`, `purchasely/example/integration_test/` (also `tools/` and `E2E_TEST_INDEX.md`) |
| CI | `.github/workflows/ci.yml`, `.github/workflows/e2e-android.yml`, `.github/workflows/e2e-ios.yml`, `.github/scripts/`, `.github/dependabot.yml` |
| Publication | `.github/workflows/publish.yml` (on a `v*` tag, or by hand with `workflow_dispatch`, with OIDC to pub.dev, environment `pub.dev`), `publish.sh` (`sh publish.sh <version> true` publishes from a local machine), the `name:` and `version:` of the three `pubspec.yaml` files, `purchasely/.pubignore`. A change to the pinned `dart-lang/setup-dart` publish workflow is T3, also from Dependabot. |
| Process docs | `AGENTS.md`, `REVIEW.md`, `RELEASE_GUIDE.md`, `VERSIONS.md`, `MIGRATION-v6.md`, `.github/pull_request_template.md` |

pub.dev gets three packages: `purchasely_flutter` (folder `purchasely/`), `purchasely_google` and
`purchasely_android_player`. They have the same version.

### Checks of this repo

- **CI on the head commit:** `ci.yml` runs on each push to a PR. The `CI Success` job collects
  the result of the other jobs. `Validate Podspec` only gives a warning, and `CI Success` does
  not read it. To run `ci.yml` again on the same commit, use **Re-run jobs** in the Actions tab,
  or `gh run rerun <run id>`.
- **E2E on the head commit:** `e2e-android.yml` and `e2e-ios.yml` run when the PR opens, not
  at each push. After each push, add the `run-ci` label. The workflow removes the label at each
  run. On a Dependabot PR or a PR from a fork, remove the label by hand before you add it
  again. Read the test log, not only the job status.
- **Required checks:** `main` has none. Before the merge, the person who merges reads
  `CI Success` and the two E2E runs on the head commit.
- **Public API:** no API check in CI yet. The platform reviewer reads the diff of the exports
  of `purchasely_flutter.dart` and of every public declaration under the `lib/` folders.
- **Release checklist:** `RELEASE_GUIDE.md` (Quick Reference Checklist), a new row in
  `VERSIONS.md`, and the three `CHANGELOG.md` files. The repo has no release test plan file.
  The E2E catalog `purchasely/example/integration_test/E2E_TEST_INDEX.md` is the nearest
  equivalent. A T2 PR writes its manual test steps in **How to verify**.
- **Tier label:** put the label `tier:T0`, `tier:T1`, `tier:T2` or `tier:T3` on the PR. It
  repeats the **Tier** section of the body.
- **Reviewers:** `.github/CODEOWNERS` requests the owners of the T2 and T3 paths. Branch
  protection does not require a code owner review: the tier sets who must approve. For a T2 or
  T3 file that `CODEOWNERS` does not list, the author requests the reviewers.
- **The PR also has:** the `minSdk = 23` line in `purchasely/example/android/app/build.gradle`
  (CI fails without it); for a native SDK version change, the same version in all the pins of
  the table above and a new row in `VERSIONS.md`; screenshots for a UI change.

For the section 5 of the other repos, see the
[Android copy](https://github.com/Purchasely/Purchasely-Android-Sources/blob/develop/REVIEW.md).

### Not in place yet

- A public API check in CI (for example `dart_apitool`).
- Required checks on `main`. Today, `main` requires 1 approval and no check.
- Protection against force pushes to `main`: they are allowed today.
