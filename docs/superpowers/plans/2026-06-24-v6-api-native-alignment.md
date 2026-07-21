# v6 Public API ↔ Native Truth Alignment — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the Purchasely Flutter v6 public API with the authoritative native SDKs (Android v6.0.0-rc.2 `develop`, iOS v6): rename `PresentationOutcome`→`PLYPresentationOutcome`, type `outcome.plan` as `PLYPlan?`, reduce `CloseReason` to `{button, backSystem, programmatic}`, rename interceptor cleanup APIs, make `synchronize()` return `Future<bool>`, and replace `Transition.heightPercentage` with the Android dimension model (`width`/`height` as `PLYTransitionDimension`).

**Architecture:** Pure-Dart façade over MethodChannel/EventChannel bridging native iOS (Swift) and Android (Kotlin) plugins. v6 is BREAKING — no legacy compat. Wire verbs (`removeInterceptor`, `removeAllInterceptors`, `synchronize`, `display`) stay unchanged; only Dart public names and serialization shapes change.

**Tech Stack:** Dart/Flutter, Swift (CocoaPods), Kotlin (Gradle).

## Global Constraints

- BREAKING v6 — do NOT keep legacy aliases or `heightPercentage`.
- Native truth is fixed:
  - iOS `PLYCloseReason.rawDescription`: `none`→"none", `button`→"button", `interactiveDismiss`→"back_system", `programmatic`→"programmatic".
  - iOS `PLYDimension`: `case value(Int)` (pixels), `case percentage(Float)`. iOS dimension factories: `PLYDisplayMode.drawer(height: PLYDimension?, dismissible:)`, `.popin(width: PLYDimension?, height: PLYDimension?, dismissible:)`.
  - Android `PLYTransition(type, width: PLYTransitionDimension?, height: PLYTransitionDimension?, [heightPercentage @Deprecated — DO NOT SET], backgroundColors, dismissible=true)`; `PLYTransitionDimension(type: PLYDimensionType=PERCENTAGE, value: Float)`; `PLYDimensionType { PIXEL("pixel"), PERCENTAGE("percentage") }`.
  - Android `outcome.closeReason?.value` and `synchronize(onSuccess,onError)` already wired natively.
- Dart wire contract for a transition dimension: `{ 'type': 'pixel'|'percentage', 'value': double }`; omit null width/height.
- Verification gate: `cd purchasely && flutter analyze` (0 issues) AND `flutter test` (0 failures).

---

### Task 1: PLYPresentationOutcome model — rename, typed plan, reduced CloseReason

**Files:**
- Modify: `purchasely/lib/src/presentation_outcome.dart`
- Test: `purchasely/test/bridge_test.dart`

**Interfaces:**
- Produces: `class PLYPresentationOutcome { Presentation? presentation; PurchaseResult? purchaseResult; PLYPlan? plan; CloseReason? closeReason; PresentationError? error; }`; `enum CloseReason { button, backSystem, programmatic }`; `CloseReason? closeReasonFromString(String?)`.

Steps:
- [ ] Add `import 'ply_models.dart';` (for `PLYPlan`).
- [ ] Rename `class PresentationOutcome` → `class PLYPresentationOutcome` (ctor + toString).
- [ ] Change field `Map<String, dynamic>? plan;` → `PLYPlan? plan;`.
- [ ] Reduce enum to `enum CloseReason { button, backSystem, programmatic }` (remove `interactiveDismiss`).
- [ ] Rewrite `closeReasonFromString`: `'button'`→button, `'back_system'`→backSystem, `'programmatic'`→programmatic, default→null (drop `interactiveDismiss`/`interactive_dismiss`/`backSystem` camel cases).
- [ ] Run `flutter test test/bridge_test.dart` — expect compile failures elsewhere (handled in later tasks). This task's correctness is gated by the full-suite run in Task 9.

### Task 2: Transition — dimension model replaces heightPercentage

**Files:**
- Modify: `purchasely/lib/src/transition.dart`
- Test: `purchasely/test/transition_test.dart` (Create)

**Interfaces:**
- Produces: `enum PLYDimensionType { pixel, percentage }`; `class PLYTransitionDimension { PLYDimensionType type; double value; PLYTransitionDimension.pixel(double); PLYTransitionDimension.percentage(double); Map toMap(); }`; `class Transition { TransitionType type; PLYTransitionDimension? width; PLYTransitionDimension? height; bool? dismissible; TransitionColors? backgroundColors; Transition.fullScreen(); Transition.modal({dismissible}); Transition.push(); Map toMap(); }`.

Steps:
- [ ] Add `enum PLYDimensionType { pixel, percentage }`.
- [ ] Add `class PLYTransitionDimension` with `final PLYDimensionType type; final double value;` const generic ctor + `const PLYTransitionDimension.pixel(this.value): type = PLYDimensionType.pixel;` + `const PLYTransitionDimension.percentage(this.value): type = PLYDimensionType.percentage;` and `Map<String, Object?> toMap() => {'type': type == PLYDimensionType.pixel ? 'pixel' : 'percentage', 'value': value};`.
- [ ] On `Transition`: remove `heightPercentage`; add `final PLYTransitionDimension? width;` and `final PLYTransitionDimension? height;`. Keep `type`, `dismissible`, `backgroundColors`. Update generic ctor to `const Transition({required this.type, this.width, this.height, this.dismissible, this.backgroundColors});`. Keep `Transition.fullScreen()`, `Transition.modal({bool? dismissible})`, `Transition.push()`.
- [ ] `toMap()`: keep `'type': _typeToWire(type)`; add `if (width != null) 'width': width!.toMap()`, `if (height != null) 'height': height!.toMap()`; keep `dismissible`/`backgroundColors`. Remove the `heightPercentage` entry.
- [ ] Write `test/transition_test.dart`: `Transition.modal()` toMap has `type=modal`; a `Transition(type: TransitionType.popin, width: PLYTransitionDimension.pixel(320), height: PLYTransitionDimension.percentage(0.5))` toMap serializes `width={'type':'pixel','value':320.0}`, `height={'type':'percentage','value':0.5}`; null dimensions omitted.

### Task 3: Bridge — type rename, typed plan parse, interceptor cleanup rename

**Files:**
- Modify: `purchasely/lib/src/bridge.dart`

Steps:
- [ ] Add `import 'ply_transformers.dart';` (for `plyPlanFromMap`).
- [ ] `replace_all` `PresentationOutcome` → `PLYPresentationOutcome`.
- [ ] In `_outcomeFromMap`, replace the `Map<String,dynamic>? plan` block with `final plan = plyPlanFromMap(raw['plan'] is Map ? raw['plan'] as Map : null);` and pass `plan: plan`.
- [ ] Rename method `removeInterceptor` → `removeActionInterceptor` (keep `invokeMethod('removeInterceptor', ...)` wire verb).
- [ ] Rename method `removeAllInterceptors` → `removeAllActionInterceptors` (keep `invokeMethod('removeAllInterceptors')` wire verb).

### Task 4: Public API surface — purchasely_flutter.dart

**Files:**
- Modify: `purchasely/lib/purchasely_flutter.dart`

Steps:
- [ ] `replace_all` `PresentationOutcome` → `PLYPresentationOutcome` (import line + doc + handler type).
- [ ] Rename `static Future<void> removeInterceptor(...)` → `removeActionInterceptor(...)` delegating to `bridge.removeActionInterceptor(kind)`.
- [ ] Rename `static Future<void> removeAllInterceptors()` → `removeAllActionInterceptors()` delegating to `bridge.removeAllActionInterceptors()`.
- [ ] Change `synchronize`: `static Future<bool> synchronize() async { final ok = await _channel.invokeMethod('synchronize'); return ok == true; }` (PlatformException already propagates on native error).

### Task 5: Remaining lib refs

**Files:**
- Modify: `purchasely/lib/src/presentation.dart`, `presentation_builder.dart`, `presentation_request.dart`, `native_view_widget.dart`

Steps:
- [ ] `replace_all` `PresentationOutcome` → `PLYPresentationOutcome` in each (includes doc comments + `native_view_widget.dart` comment).

### Task 6: Tests update

**Files:**
- Modify: `purchasely/test/bridge_test.dart`, `purchasely/test/platform_channel_test.dart`

Steps:
- [ ] bridge_test: `PresentationOutcome? captured;` → `PLYPresentationOutcome? captured;`.
- [ ] bridge_test default-dismiss test: change event `'closeReason': 'interactiveDismiss'` → `'back_system'`; assertion `CloseReason.interactiveDismiss` → `CloseReason.backSystem`; `captured!.plan?['vendorId']` → `captured!.plan?.vendorId`.
- [ ] bridge_test 5-field test (already sends `'plan': {'vendorId':'monthly'}`): keep `outcome.plan, isNotNull`; optionally assert `outcome.plan!.vendorId == 'monthly'`.
- [ ] bridge_test removeInterceptor test: call `.removeActionInterceptor(...)`; keep wire assertion `c.method == 'removeInterceptor'`.
- [ ] Add a bridge_test case: emit onDismissed with full plan map (`vendorId`, `productId`, `basePlanId`, `amount`, `currencyCode`…) and assert typed fields on `outcome.plan!` (vendorId/productId/basePlanId).
- [ ] platform_channel_test: add `expect(await Purchasely.synchronize(), isTrue);` where the mock returns true for `synchronize`.

### Task 7: Native iOS plugin

**Files:**
- Modify: `purchasely/ios/Classes/SwiftPurchaselyFlutterPlugin.swift`

Steps:
- [ ] `outcomeToMap`: replace partial `planMap` with `planMap = plan.toMap` (full `PLYPlan+ToMap.swift` extension).
- [ ] `outcomeToMap` closeReason: `switch outcome.closeReason { case .none: return nil; default: return outcome.closeReason.rawDescription }` (drop the `.interactiveDismiss → "interactiveDismiss"` special case; `.interactiveDismiss` now yields `"back_system"`).
- [ ] `parseTransition`: add `private static func parseDimension(_ raw: Any?) -> PLYDimension?` that reads `["type","value"]` → `.value(Int(v.rounded()))` for `"pixel"`, `.percentage(Float(v))` for `"percentage"` (default percentage). Replace the `heightPercentage` reads with `let height = parseDimension(map["height"])`, `let width = parseDimension(map["width"])`. `drawer`→`.drawer(height: height, dismissible:)`; `popin`→`.popin(width: width, height: height, dismissible:)`. Keep fullScreen/push/modal/inlinePaywall.

### Task 8: Native Android plugin

**Files:**
- Modify: `purchasely/android/src/main/kotlin/io/purchasely/purchasely_flutter/PurchaselyFlutterPlugin.kt`

Steps:
- [ ] `outcomeToMap` (Companion): replace partial inline `plan` map with `"plan" to outcome.plan?.let { transformPlanToMap(it) }` (full serialization, type ordinal). NOTE: `transformPlanToMap` is `private` in Companion — `outcomeToMap` is also in Companion, so direct call is fine.
- [ ] `parseTransition`: add `parseDimension(map["width"] as? Map<*, *>)` / `parseDimension(map["height"] as? Map<*, *>)` returning `PLYTransitionDimension(PLYDimensionType, Float)` (`"pixel"`→PIXEL else PERCENTAGE). Build `PLYTransition(type = type, width = width, height = height, dismissible = dismissible)`. Remove `heightPercentage` read (do NOT set the deprecated arg).

### Task 9: Docs + verification

**Files:**
- Modify: `MIGRATION-v6.md`
- Run: `cd purchasely && flutter analyze && flutter test`

Steps:
- [ ] MIGRATION-v6.md: `replace_all` `PresentationOutcome` → `PLYPresentationOutcome`; `Purchasely.removeInterceptor` → `removeActionInterceptor`; `Purchasely.removeAllInterceptors` → `removeAllActionInterceptors`; update synchronize note from `Future<void>` → `Future<bool>` (resolves `true`, throws `PlatformException`). Add/keep Transition dimension example using `PLYTransitionDimension.percentage(...)`.
- [ ] Example app: `presentation_demo_screen.dart` + `presentation_screen.dart`: `PresentationOutcome` → `PLYPresentationOutcome`. `main.dart` synchronize comment stays valid (now returns bool).
- [ ] `flutter analyze` → 0 issues. `flutter test` → 0 failures.

## Self-Review

- Spec item 1 (rename) → Tasks 1,3,4,5,6,9. ✓
- Spec item 2 (typed plan + full native serialization) → Tasks 1,3,6,7,8. ✓
- Spec item 3 (CloseReason reduce, iOS rawDescription, Android `.value`, Dart parser) → Tasks 1,7 (Android already `?.value`). ✓
- Spec item 4 (interceptor cleanup rename, Dart only) → Tasks 3,4,6,9. ✓
- Spec item 5 (synchronize Future<bool>) → Tasks 4,6 (native already wired). ✓
- Spec item 6 (Transition dimension model) → Tasks 2,7,8,9. ✓
- Spec items 7 (defaultSource) & 8 (deeplink) → no change. ✓
