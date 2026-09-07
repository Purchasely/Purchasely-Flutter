# Dart ↔ Android E2E test index — porting guide for React Native & Cordova

This file catalogs the **end-to-end integration tests** added to the Flutter SDK
(`purchasely/example/integration_test/`) that drive the public API across the
MethodChannel/EventChannel to the **real native Android SDK** against the **real
Purchasely backend**, and documents everything needed to reimplement the same
suite in the **React Native** and **Cordova** wrappers.

All tests were run on `emulator-5554` (Android) and pass. Every value in the
"Expected output" columns is an actually observed result, not a guess.

---

## 1. Shared test configuration

Mirror of the native Android `com.purchasely.integration.BaseIntegrationTest`.

| Key | Value |
|-----|-------|
| **API key** | `0ad0594b-3b3d-4fea-8ee1-4b5df91efe87` |
| **Running mode** | `Full` |
| **Stores** | Google (`GoogleStore`) |
| **Log level** | `debug` |
| **Default placement** | `integration_test_audiences` — onboarding screen; exposes a **purchase button** with content-desc `action:purchase,plan:monthly; action:close_all` |
| **Flow placement** | `integration_test_flow` (flow id `integration_test_v_1`, "calm" selection screen) |
| **Interactions placement** | `integration_tests_interactions` (login / restore buttons) |
| **Open-screen placement** | `integration_test_open_screen` (open_presentation stacking) |
| **Scrim placement** | `scrim_test` |
| **Plan exposed by the purchase button** | vendorId `monthly`, productId `com.purchasely.plus.monthly` |
| **Deeplink to open a placement** | `ply://ply/placements/<PLACEMENT_ID>` |

### SDK init (per wrapper)

- **Flutter:** `PurchaselyBuilder.apiKey(K).runningMode(PLYRunningMode.full).logLevel(PLYLogLevel.debug).stores([PLYStore.google]).start()` → `Future<bool>`
- **React Native:** `Purchasely.builder(K).runningMode('full').logLevel(LogLevels.debug).stores(['google']).start()` → `Promise<boolean>`
- **Cordova:** `Purchasely.start(K, ['Google'], false /*storekit1*/, null /*userId*/, Purchasely.LogLevel.DEBUG, Purchasely.RunningMode.full, success, error)`

### Prerequisites / environment notes

- A booted Android emulator/device with the example app installed.
- **No Google Play billing on a bare emulator.** `synchronize()` (and any real
  purchase) hits `BillingUnavailable`. This is expected and is exercised as the
  error path (see T6). Catalog/preload/identity calls do **not** need billing.
- Flutter runs these via `flutter test integration_test/... -d emulator-5554`.
  RN: Detox or `@react-native/jest` + a native instrumented driver. Cordova:
  an instrumented test or a manual harness page — the JS layer is identical, only
  the runner differs.

---

## 2. Public API mapping (Flutter ↔ RN ↔ Cordova)

| Concept | Flutter | React Native | Cordova |
|---------|---------|--------------|---------|
| Start | `PurchaselyBuilder.apiKey(...).…start()` | `Purchasely.builder(...).…start()` | `Purchasely.start(apiKey, stores, sk1, userId, logLevel, runningMode, ok, err)` |
| Anonymous id | `Purchasely.anonymousUserId` | `Purchasely.getAnonymousUserId()` | `Purchasely.getAnonymousUserId(ok, err)` |
| Is anonymous | `Purchasely.isAnonymous()` | `Purchasely.isAnonymous()` | ❌ not exposed |
| Login / logout | `userLogin(id)` / `userLogout()` | `userLogin(id)` / `userLogout()` | `userLogin(id, ok)` / `userLogout()` |
| Preload | `PLYPresentationBuilder.placement(id).build().preload()` | `Purchasely.presentation.placement(id).build().preload()` | `fetchPresentationForPlacement(placementId, contentId, ok, err)` |
| Display | `request.display([PLYTransition])` | `request.display([transition])` | `presentPresentationForPlacement(placementId, contentId, isFullscreen, ok, err)` |
| Local dismiss | `presentation.close()` | `presentation.close()` | `Purchasely.closePresentation()` |
| All products | `allProducts()` | `allProducts()` | `allProducts(ok, err)` |
| Dynamic offerings | `getDynamicOfferings()` | `getDynamicOfferings()` | ❌ not exposed |
| Synchronize | `synchronize()` → `Future<bool>` | `synchronize()` → `Promise<boolean>` | `synchronize(ok, err)` (resolves on completion) |
| Register interceptor | `interceptAction(kind, handler)` | `interceptAction(kind, handler)` | `setPaywallActionInterceptor(cb)` + `onProcessAction(bool)` (**old model**) |
| Remove interceptor | `removeActionInterceptor(kind)` | `removeActionInterceptor(kind)` | ❌ (no per-kind removal in old model) |
| Remove all interceptors | `removeAllActionInterceptors()` | `removeAllActionInterceptors()` | ❌ |
| Default dismiss handler | `setDefaultPresentationDismissHandler(cb)` | `setDefaultPresentationDismissHandler(cb)` | `setDefaultPresentationDismissHandler(ok, err)` |
| Handle deeplink | `handleDeeplink(url)` → `Future<bool>` | `handleDeeplink(url)` → `Promise<boolean>` | `handleDeeplink(url, ok, err)` |

> **RN ≈ Flutter (builder API).** Porting to RN is almost 1:1.
> **Cordova is still on the pre-builder imperative API** — there is no
> `PLYPresentationBuilder`, no typed `interceptAction`/`PLYInterceptResult`, and no
> `isAnonymous`/`getDynamicOfferings`. Port the *intent* of each test using the
> imperative entry points; some tests (T2 isAnonymous, T4 dynamic offerings, T7
> interceptor cleanup) have no Cordova equivalent and should be skipped or
> adapted.

### Outcome shape

The dismiss/outcome object delivered to `display()`/`onDismissed`/the default
handler carries 5 fields on every wrapper:
`presentation`, `purchaseResult` (`purchased`/`cancelled`/`restored`/null),
`plan` (typed plan or null), `closeReason`, `error`.

`closeReason` **wire values**: `button`, `back_system`, `programmatic`, or null.
- Flutter/Android map to enum `CloseReason.{button, backSystem, programmatic}`.
- **iOS parity:** Flutter & RN normalize iOS `interactiveDismiss` → `back_system`.
  **Cordova iOS still emits the raw `interactiveDismiss` string** (see its
  `Purchasely.js` comment) — assert accordingly per platform when porting.

---

## 3. Test catalog

Files:
- `dart_android_bridge_test.dart` — T1–T8 (pure-Dart round-trips + local dismiss)
- `redemption_identity_test.dart` — R1–R4 (6.1.0: anonymousUserId, cleared proxy, redemption listener)
- `proxy_invalid_test.dart` — P1–P2 (6.1.0: an unconvertible proxy string is skipped)
- `interceptor_trigger_test.dart` — T9 (interceptor fired by a real native tap)
- `default_dismiss_handler_test.dart` — T10 (global dismiss handler via deeplink + back)

### T1 — anonymousUserId returns a non-empty id
- **API:** `anonymousUserId`
- **Action:** read the id after start.
- **Expected:** non-empty string.
- **Port:** RN/Cordova identical (`getAnonymousUserId`).

### T2 — isAnonymous lifecycle: true → login → false → logout → true
- **API:** `isAnonymous()`, `userLogin(id)`, `userLogout()`
- **Action:** assert anonymous; `userLogin('flutter_it_user')`; assert not anonymous; `userLogout()`; assert anonymous.
- **Expected:** `true → false → true`. `userLogin` resolves a `bool`.
- **Port:** RN identical. **Cordova:** no `isAnonymous` — test only `userLogin`/`userLogout` resolve without error.

### T3 — preload(placement) returns a typed Presentation
- **API:** `PLYPresentationBuilder.placement(id).build().preload()`
- **Action:** preload `integration_test_audiences`.
- **Expected:** `screenId` non-null (observed `pres_Yzzy4U8bkPAzByL0QS8KJDj6mBWKd6a`), `type == normal`, `plans` is a typed list (observed length 1). Real backend round-trip.
- **Port:** RN identical. **Cordova:** `fetchPresentationForPlacement(...)` → success cb gets a presentation object; assert its `id`/`screenId` and `plans`.

### T4 — getDynamicOfferings returns a typed list
- **API:** `getDynamicOfferings()`
- **Expected:** typed list (may be empty).
- **Port:** RN identical. **Cordova:** skip (not exposed).

### T5 — allProducts returns a typed list
- **API:** `allProducts()`
- **Expected:** list of products (observed 5).
- **Port:** RN/Cordova identical.

### T6 — synchronize() resolves true on success OR throws on store error
- **API:** `synchronize()`
- **Action:** call and handle both outcomes.
- **Expected:** resolves `true` **or** throws/rejects with a platform error. On a
  bare emulator it **threw `PlatformException(-1)` BillingUnavailable** — proving
  the v6 contract that `synchronize()` now propagates the native error instead of
  fire-and-forget.
- **Port (critical for v6):**
  - RN: `await synchronize()` resolves `true` or **rejects** — wrap in try/catch.
  - Cordova: `synchronize(success, error)` — the **error callback** must fire on
    BillingUnavailable; assert one of the two callbacks runs.

### T7 — interceptor cleanup round-trip (renamed v6 APIs)
- **API:** `interceptAction(kind, handler)`, `removeActionInterceptor(kind)`, `removeAllActionInterceptors()`
- **Action:** register purchase + navigate handlers; `removeActionInterceptor(purchase)`; `removeAllActionInterceptors()`.
- **Expected:** all four MethodChannel round-trips succeed (no throw).
- **Port:** RN identical. **Cordova:** skip (old `setPaywallActionInterceptor`/`onProcessAction` model has no per-kind register/remove).

### T8 — display + local dismiss (PLYTransition dimension + closeReason)
- **API:** `preload()`, `display(PLYTransition)`, `onPresented`, `presentation.close()`
- **Action:** preload `integration_test_audiences`; `display(PLYTransition.drawer(height: PLYTransitionDimension.percentage(0.6)))`; wait for `onPresented`; `presentation.close()`; await the display future.
- **Expected (observed):** `onPresented` fires (the **v6 PLYTransition dimension** reached native and the drawer rendered); after `close()` the display future resolves with `purchaseResult=cancelled`, **`closeReason=programmatic`**, `plan=null`.
- **Notes:** this is the path that surfaced and verifies the **onDismissed fix**
  (see §5). The drawer height uses the v6 dimension model
  (`{type:'percentage', value:0.6}` on the wire), not the removed `heightPercentage`.
- **Port:**
  - RN: same builder + transition dimension shape; `presentation.close()`; assert outcome `closeReason`.
  - Cordova: `presentPresentationForPlacement(placement, null, true, ok, err)`
    (the `ok` callback is the dismiss outcome) then `closePresentation()`; assert
    the outcome's `closeReason`. Cordova has no drawer-dimension transition arg
    (full-screen only) — assert the dismiss outcome rather than the dimension.

### T9 — purchase interceptor fires with a typed payload on a real tap
- **API:** `interceptAction(purchase, …)`, `interceptAction(closeAll, …)`, `display()`
- **Action:** register `purchase` (capture + return `success`) and `closeAll`
  (return `success`, keeps the paywall open — mirrors native Android ACT-01);
  display `integration_test_audiences`; **driver taps the native `action:purchase`
  button**; poll for the handler to fire.
- **Expected (observed):** the purchase interceptor fires with a typed
  `PurchasePayload` → `plan.vendorId=monthly`, `plan.productId=com.purchasely.plus.monthly`; `kind == purchase`.
- **Driver:** `tools/tap_purchase.sh` (uiautomator dump → tap node whose
  content-desc contains `action:purchase`).
- **Port:**
  - RN: identical JS; reuse the same uiautomator tap driver (the native view is
    identical — same `action:purchase` content-desc).
  - Cordova: use the **old model** — `setPaywallActionInterceptor(cb)`; in `cb`,
    inspect the action; call `onProcessAction(false)` to block; then tap the same
    button with the same driver and assert the callback received a purchase action.

### T10 — global default dismiss handler (SDK-opened presentation)
- **API:** `setDefaultPresentationDismissHandler(cb)`, `handleDeeplink(url)`
- **Action:** register the default handler; `handleDeeplink('ply://ply/placements/integration_test_audiences')` (SDK opens the screen itself); **driver presses system BACK**; poll for the handler.
- **Expected (observed):** the default handler receives the outcome with
  **`closeReason=backSystem`** and `presentation.screenId=pres_Yzzy4U8bk…`. Proves
  the global handler path + the `back_system` → `backSystem` mapping.
- **Driver:** `tools/press_back.sh` (waits for a paywall, then `adb … input keyevent 4`).
- **Port:**
  - RN: identical JS + same back-press driver.
  - Cordova: `setDefaultPresentationDismissHandler(ok, err)` + `handleDeeplink(url, ok, err)`; same back-press driver. **iOS caveat:** Cordova iOS reports `closeReason='interactiveDismiss'` (not `back_system`).

### T11 — default dismiss handler catches a fire-and-forget display() (host-opened)
- **API:** `setDefaultPresentationDismissHandler(cb)`, `preload()`, `display()` (not awaited, no `onDismissed`)
- **Action:** register the default handler; `preload('integration_test_audiences')`; `unawaited(presentation.display())` with **no per-presentation `onDismissed`**; **driver dismisses** (Android system BACK / iOS tap `ply_action_close`); poll for the handler.
- **Expected:** the default handler receives the outcome (Android `closeReason=backSystem`, iOS `button`). Unlike T10 the screen is **host-opened via `display()`**, so the dismissal travels the per-request `onDismissed` event — but since the host set no local handler, the Dart bridge **falls back** to the default handler (`_handleOnDismissed`). This is the regression guard for the dismiss-routing fallback.
- **Files:** `default_dismiss_via_display_test.dart` (Android), `default_dismiss_via_display_ios_test.dart` (iOS).
- **Driver:** `tools/press_back.sh` (Android) / `tools/close_paywall_ios.sh` (iOS).
- **Port:**
  - RN: identical builder JS; `display()` without awaiting and without an `onDismissed`; reuse the same drivers. **Requires the RN bridge to implement the same local→default dismiss fallback** (see §5.5).
  - Cordova: old imperative model has no per-presentation `onDismissed` to omit; not directly portable — skip or assert via the default handler only.

### T12 — local onDismissed (+ awaited display()) wins over the default handler
- **API:** `setDefaultPresentationDismissHandler(cb)`, `preload()`, `onDismissed`, `await display()`
- **Action:** register the default handler; build `integration_test_audiences` **with** a local `onDismissed`; `preload()`; **`await display()`** (with a 50 s safety timeout); **driver dismisses** (Android system BACK / iOS tap `ply_action_close`).
- **Expected:** the awaited `display()` future resolves with the outcome, the local `onDismissed` also receives it, and the **default handler stays silent** (`defaultOutcome == null`). This is the complement of T11: it pins that a local handler claims the dismissal so the fallback to the default does NOT happen. (Routing keys on the presence of `onDismissed`; awaiting alone always resolves the future but does not by itself suppress the default — hence the local handler here.)
- **Files:** `local_dismiss_handler_test.dart` (Android), `local_dismiss_handler_ios_test.dart` (iOS).
- **Driver:** `tools/press_back.sh` (Android) / `tools/close_paywall_ios.sh` (iOS).
- **Port:**
  - RN: identical builder JS with `onDismissed` set + `await display()`; reuse the same drivers; assert the default handler did not fire.
  - Cordova: the imperative `presentPresentationForPlacement(...)` success callback is the per-presentation dismiss outcome — assert it fires and the default handler does not.

### R1–R4 — 6.1.0: anonymousUserId, proxy(null), Web2App redemption listener
- **File:** `redemption_identity_test.dart` (both platforms; no UI driver).
- **Start chain:** `.anonymousUserId('3f2504e0-4f89-11d3-9a0c-0305e82c3301', override: true).proxy(null).webRedemptionListener(collect)`.
- **R1 — `anonymousUserId`:** the SDK reports back the pinned UUID **uppercased**, and the same value appears on `PLYEventProperties.anonymous_user_id`. `override: true` is required — the device already holds an SDK-generated id from an earlier run.
- **R2 — `proxy(null)`:** an explicit **clear** is a supported operation on both native SDKs. Asserted indirectly, by the SDK still resolving `integration_test_audiences` and `allProducts()` from production — the resolved API host itself is SDK-internal state no harness can read.
- **R3 — chain ordering:** `Purchasely.webRedemptions != null` is snapshotted **between building the chain and calling `start()`**, so the test proves the subscription happens at chain time. That is the point of the modifier: a redemption can settle *during* `start()`.
- **R4 — live failure path:** `handleDeeplink('ply://ply/redeem/<bogus>')` with `allowDeeplink(false)` still settles (a redemption deeplink bypasses that gate) and the listener receives `isSuccess: false`, `context: null`, `replay: false`, and an `errorCode` of `INVALID_REDEMPTION_TOKEN` / `EXPIRED_REDEMPTION_TOKEN` (or `null` on a transport failure), **exactly once**. Then `removeWebRedemptionListener()` and assert nothing is delivered.
- **Port:**
  - RN: identical — `builder(key).anonymousUserId(...).proxy(null).webRedemptionListener(cb).start()`, then `Purchasely.handleDeeplink(...)`.
  - Cordova: only if the bridge exposes the three options and a redemption event.

### P1–P2 — 6.1.0: an unconvertible proxy string is skipped, not fatal
- **File:** `proxy_invalid_test.dart` — **its own app process**, because the SDK starts once and this suite needs a different proxy state than R1–R4.
- **Start chain:** `.proxy('https://svc purchasely.io')` — a space in the authority, which `URL(string:)` rejects on iOS.
- **P1:** `start()` still resolves `true`. The bridge logs an error and skips the modifier; a bad proxy is a warning, never a boot failure.
- **P2:** the placement and the catalogue still load from production, which is what proves the typo neither cleared the proxy (the iOS trap: nil means *clear*) nor redirected the host.
- **Port:** RN/Cordova identical, with each bridge's own log assertion if it has one.

> **Scope limit for both suites.** They assert the SDK still behaves against
> production after each proxy state, and that the redemption listener is wired
> end to end. They do **not** assert the native SDK's resolved API host, which is
> internal state. Neither suite ever sets a *live* proxy: that would move the
> example app off production.

---

## 4. Host-side UI drivers

JS/Dart cannot tap **native** paywall controls, so native interactions are driven
from the host via `adb`/uiautomator, concurrently with the test. Both drivers are
in `tools/` and are wrapper-agnostic (same native views on every wrapper).

- **`tools/tap_purchase.sh [device]`** — polls `uiautomator dump`, finds the node
  whose `content-desc` contains `action:purchase`, taps its center.
- **`tools/press_back.sh [device]`** — waits for any `action:` content-desc
  (= a paywall is up), then `input keyevent 4` (system BACK).

Run pattern:
```bash
bash integration_test/tools/tap_purchase.sh emulator-5554 &
flutter test integration_test/interceptor_trigger_test.dart -d emulator-5554
```

For RN/Cordova, keep these scripts as-is; only the test runner command changes.
(A fully-native alternative is an instrumented test using `UiDevice`/uiautomator
directly, as the native Android `integration-tests` module does.)

---

## 5. Cross-wrapper gotchas (check these when porting)

1. **`onDismissed` clobbering (native Android).** `dispatchDisplay` /
   `Prepared.display(...)` do `onDismissed = callback` for **any non-null
   callback** — passing an *empty* lambda CLOBBERS the builder-wired emitter, so
   the dismiss event is never delivered and `display()` never resolves. The
   Flutter Android plugin had this bug; fixed by passing the **real emitter** as
   the dismissal callback on both the loaded and prepared paths. **Verify the RN
   and Cordova native Android bridges do the same** — if their `display`
   implementation passes an empty/no-op `onDismissed`, dismiss outcomes silently
   never reach JS. (T8/T9/T10 will catch a regression.)
2. **`synchronize()` error path on emulator.** Always BillingUnavailable without
   Play billing — assert "resolves true OR errors", never "always resolves true".
3. **`closeReason` iOS parity.** Flutter & RN normalize iOS `interactiveDismiss`
   → `back_system`. Cordova iOS still emits `interactiveDismiss`. Assert per
   platform.
4. **Interceptor chain.** Tapping the purchase button triggers `purchase` →
   `close_all`. To keep the paywall open while asserting (T9), intercept
   `close_all` too and return `success`/block.
5. **Dismiss routing fallback (local → default).** When a host-opened
   `display()` is dismissed and **no** per-presentation/request `onDismissed` is
   set, the Flutter Dart bridge falls back to the global
   `setDefaultPresentationDismissHandler` (in `_handleOnDismissed`) instead of
   dropping the outcome — so a fire-and-forget `display()` (not awaited, no local
   handler) still reports centrally. T11 guards this. **When porting:** the RN
   bridge must apply the same precedence (local `onDismissed` first, else default
   handler); otherwise a fire-and-forget `display()` silently loses its dismissal.
