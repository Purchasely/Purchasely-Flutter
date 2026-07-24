# Custom Screens (BYOS) — Flutter SDK Plan

**Created:** 2026-07-17
**Status:** Draft — awaiting review
**Tickets:** [MOB-203](https://linear.app/purchasely/issue/MOB-203) (Flutter), parent [MOB-200](https://linear.app/purchasely/issue/MOB-200) "Pause/Resume flow → BYOS Bridges"
**Base branch:** `feat/sdk-v6-migration` (6.0.0-rc.3)
**Native references:** Purchasely-Android-Sources (v6, shipped), Purchasely-iOS-Sources (shipped since 5.6.2)

> Naming note: "BYOS" was the internal codename on iOS and was scrubbed from all public
> symbols before release. The public feature name is **Custom Screen** on both native SDKs.
> This plan uses "Custom Screen" for all public API and reserves "BYOS" for internal docs.

---

## 1. Context & Goal

A **Custom Screen** is a screen inside a Purchasely presentation/flow whose UI is authored by
the host app instead of the Screen Composer. The console marks such a screen `is_client: true`
and gives it a `connections` array (named exit paths, each with a `vendor_id`, a `default`
flag, and actions). When the SDK reaches a client screen it asks the app for UI, embeds the
returned UI **inside its own flow container** (inheriting the step's transition —
fullscreen/push/modal/drawer/popin), and the app drives navigation by executing connections.

This is shipped on both native SDKs:

| | Android | iOS |
|---|---|---|
| Registration | `Purchasely.setCustomScreenProvider(PLYCustomScreenProvider?)` | `Purchasely.setCustomScreenViewControllerDelegate(_:)` (UIKit) + `setCustomScreenViewDelegate(_:)` (SwiftUI), UIKit tried first |
| Provider callback | `onCustomScreenRequested(presentation: PLYPresentation): PLYCustomScreen?` — synchronous, main thread | `viewController(for: PLYPresentation) -> UIViewController?` — synchronous, main thread |
| Return type | `PLYCustomScreen.View(android.view.View)` / `.Fragment(Fragment)` | `UIViewController?` (SwiftUI variant wrapped in `UIHostingController` by the SDK) |
| Hosting | View `addView`'d / Fragment committed into the current flow fragment's container (`PLYFlowParentFragment.onCustomScreenLoaded`) | Child-VC containment inside the same `PLYProductViewController` used for normal paywalls |
| No provider / null | Warn log; container left empty; display still recorded | Warn log; presentation **self-closes** with `.cancelled` |
| Navigation | `presentation.execute(connection?)` (null → default), `presentation.back()`, `presentation.close()` | `presentation.executeConnection(connection?)` (nil → default), `presentation.close()` |
| Data handed over | Full `PLYPresentation` incl. `connections: List<PLYConnection>` (`id`, `default`, actions internal-ish) | Full `PLYPresentation` incl. `connections: Set<PLYConnection>` (only `id` public) |
| Auto events | `clientPresentationDisplayed` fired automatically on mount (`PRESENTATION_VIEWED`) | Standard presentation lifecycle events (client branch shares the normal configure path) |
| Applies to | Flow steps **and** standalone presentations (`PLYPresentationView` standalone path also routes through the provider) | Any `isClient` presentation, flow or standalone |

The Flutter SDK has **none** of this: no provider API, no `PLYConnection` model, no
`execute()`. What it does have (and this plan builds on):

- `PLYPresentationType.client` in the Dart enum (`purchasely/lib/src/presentation.dart`).
- `Purchasely.clientPresentationDisplayed/Closed` (notification pair for app-managed
  standalone client presentations).
- `PLYPresentation.back()` / `.close()` routed to native.
- The **action-interceptor round trip** (`interceptorTriggered` event → id-keyed pending
  completion map → `interceptorResolve` method) — the plumbing template for any
  "native waits on Dart" handshake.
- A `requestId`-keyed static registry of native loaded presentations on both platforms
  (`loadedPresentations` / `preparedRequests`).

**Goal:** mirror the native Custom Screen feature in Flutter — same logic, same lifecycle,
API names aligned with Android's neutral naming (`setCustomScreenProvider`) — so a Flutter
app can supply Flutter-authored screens for `CLIENT` steps inside native flows and drive
navigation via connections.

---

## 2. The Core Problem & Chosen Architecture

The native provider callback is **synchronous on the main thread** and must return native UI
(`View`/`Fragment`/`UIViewController`). Dart cannot answer synchronously, and a Flutter widget
is not a native view. Three architectures were considered:

### Option A — Secondary FlutterEngine (FlutterEngineGroup) ✅ **chosen**

The plugin's native provider synchronously returns a host `FlutterFragment` (Android) /
`FlutterViewController` (iOS) backed by an engine spawned from a `FlutterEngineGroup` running
a **dedicated Dart entrypoint** in which the app registered a widget builder. Spawned engines
are cheap (shared GPU context/snapshots), plugins auto-register on them, and the existing
plugin already keeps its registries in static/companion state, so both engines see the same
native presentation registry.

- ✔ Matches the native design exactly: the custom screen lives *inside* the flow container,
  inherits transitions, back-stack, process-death restoration (`PLYFlowManager.update` runs
  as for any step). No native-SDK changes required.
- ✔ Works for flows *and* standalone client presentations, `display()` *and* inline
  `PLYPresentationView`.
- ✖ **The builder runs in a separate isolate**: no access to the main app's Provider/Bloc/
  Riverpod state or Navigator. This is the documented trade-off (see §8 DX guidance).
  The Notion feasibility note ("Flutter — à priori possible") pointed at this route.

### Option B — Pause/hide the flow, app renders a normal Flutter route (MOB-200 model) ❌ deferred

The 2025 spec's hybrid model: SDK hides the flow window, app pushes its own route, then calls
`proceed(connection)`. Requires new native pause/resume APIs (MOB-201/MOB-205, both Backlog),
and hiding the flow was flagged as destroying flow context. On Android the flow lives in
`PLYFlowActivity` *above* the `FlutterActivity`, so "app renders behind it" needs the
activity→fragment rework the 15 Oct 2025 workshop deferred. Revisit only if Option A's
isolate DX proves blocking for customers.

### Option C — Overlay above the inline platform view ❌ rejected

Only works when the flow is embedded via the `PLYPresentationView` widget (Flutter can draw
routes above a platform view), not for `display()`/`PLYFlowActivity`. Two rendering models
for one feature is not acceptable.

---

## 3. Public Dart API (spec)

### 3.1 Registration (main isolate)

```dart
/// Registers the app's custom screen entrypoint with the SDK.
/// [entrypoint] is the name of a top-level @pragma('vm:entry-point') function.
/// [libraryUri] is required if the entrypoint is not in the app's main library.
/// Call after Purchasely.start(), before any presentation is displayed
/// (typically right after start, mirroring native guidance).
static Future<void> setCustomScreenProvider({
  String entrypoint = 'purchaselyCustomScreen',
  String? libraryUri,
}) async { ... }

static Future<void> removeCustomScreenProvider() async { ... }
```

### 3.2 The entrypoint + builder (custom-screen isolate)

```dart
typedef PLYCustomScreenBuilder = Widget Function(
  BuildContext context,
  PLYCustomScreenPresentation presentation,
);

@pragma('vm:entry-point')
void purchaselyCustomScreen() {
  PurchaselyCustomScreens.run((context, presentation) {
    switch (presentation.id) {
      case 'onboarding_custom_step':
        return MyOnboardingStep(presentation: presentation);
      default:
        return MyGenericCustomScreen(presentation: presentation);
    }
  });
}
```

`PurchaselyCustomScreens.run(builder)`:
1. `WidgetsFlutterBinding.ensureInitialized()`.
2. Reads the `customScreenId` from the engine's `dartEntrypointArgs`.
3. Fetches the presentation map over the dedicated channel (`getCustomScreenPresentation`).
4. `runApp` of a minimal host (`Directionality` + `MediaQuery` from the view, no MaterialApp
   imposed — the builder brings its own theming) that invokes the builder.

### 3.3 Models & navigation

```dart
class PLYConnection {
  final String? id;        // console vendor_id
  final bool isDefault;
}

/// The presentation as seen from a custom screen. Same fields as PLYPresentation
/// (id/screenId, placementId, contentId, flowId, language, type, plans, metadata,
/// backgroundColor, height, displayMode) plus:
class PLYCustomScreenPresentation extends PLYPresentation {
  final List<PLYConnection> connections;

  /// Executes [connection]'s actions; null → the connection flagged default.
  Future<void> execute([PLYConnection? connection]);

  /// Navigate to the previous flow step (or dismiss when first step).
  Future<void> back();

  /// Close all Purchasely screens.
  Future<void> close();
}
```

`execute`/`back`/`close` are bound to the **exact native presentation instance** the provider
received (via `customScreenId`), never to a previously fetched one — this mirrors the
documented native pitfall (Android `FlowTests.kt:576`: connections differ per flow instance).

`connections` is also added to the base `PLYPresentation` model + `toMap`/`fromMap`, so
app-managed standalone CLIENT presentations (fetched via `preload()`) can execute connections
too (M1 below).

---

## 4. Wire Protocol (bridge contract)

New dedicated channel (registered by the plugin on **every** engine it attaches to, so the
spawned engine gets it automatically): `purchasely-custom-screen` (MethodChannel).

Main-isolate `purchasely` channel additions:

| Method | Args | Direction | Notes |
|---|---|---|---|
| `setCustomScreenProvider` | `{entrypoint, libraryUri?}` | Dart→native | Stores entrypoint config; registers the native provider/delegate |
| `removeCustomScreenProvider` | `{}` | Dart→native | Unregisters (Android: `setCustomScreenProvider(null)`; iOS: `removeCustomScreenViewControllerDelegate()`) |
| `executeConnection` | `{requestId or customScreenId, connectionId?}` | Dart→native | For standalone client presentations held by the app |

Custom-screen channel (spawned isolate ↔ native):

| Method | Args | Direction | Notes |
|---|---|---|---|
| `getCustomScreenPresentation` | `{customScreenId}` | Dart→native | Returns presentation map (incl. `connections`, `customScreenId`) |
| `executeConnection` | `{customScreenId, connectionId?}` | Dart→native | `connectionId == null` → default connection |
| `customScreenBack` | `{customScreenId}` | Dart→native | Android `presentation.back()`; iOS same call the existing `back()` bridge uses |
| `customScreenClose` | `{customScreenId}` | Dart→native | `presentation.close()` |

Payload additions to the existing `presentationToMap` (both platforms):

```
connections: [ { id: String?, isDefault: Bool } ],
customScreenId: String?        // only set when delivered through the provider
```

`customScreenId` format `ply_cs_<counter>` generated natively, keyed into a static
`ConcurrentHashMap<String, PLYPresentation>` (Android) / static dictionary + lock (iOS),
removed when the host view is destroyed. Same single-shot registry discipline as
`pendingInterceptors`.

---

## 5. Native Implementation

### 5.1 Android (`purchasely/android/.../PurchaselyFlutterPlugin.kt` + new files)

1. **Provider registration** (`setCustomScreenProvider` method handler):
   ```kotlin
   Purchasely.setCustomScreenProvider(object : PLYCustomScreenProvider {
       override fun onCustomScreenRequested(presentation: PLYPresentation): PLYCustomScreen? {
           val id = registerCustomScreenPresentation(presentation)   // ply_cs_<n>
           return PLYCustomScreen.Fragment(
               PurchaselyCustomScreenFragment.newInstance(id, entrypoint, libraryUri)
           )
       }
   })
   ```
   Return a **Fragment** (not View) so we get lifecycle callbacks for engine teardown; the
   flow machinery commits it via `childFragmentManager.replace` (`PLYFlowParentFragment.onCustomScreenLoaded`).
2. **New `PurchaselyCustomScreenFragment`** (subclasses `FlutterFragment` or hosts a
   `FlutterView` directly):
   - `onCreateView`: spawn engine from a process-wide `FlutterEngineGroup`
     (`createAndRunEngine(context, DartEntrypoint(appBundlePath, entrypoint), listOf(customScreenId))`),
     cache under `ply_cs_engine_<id>`, build via `FlutterFragment.withCachedEngine(...)
     .destroyEngineWithFragment(true).renderMode(texture)`.
   - `onDestroyView`: destroy engine, remove registry entry, remove engine-cache entry.
   - Render mode **texture** so the surface composites correctly inside modal/drawer/popin
     containers with rounded corners/scrims (validate in M5; fall back to surface if
     performance requires and clipping allows).
3. **Custom-screen channel handler** in the plugin (all engines): `getCustomScreenPresentation`
   (map from registry via existing `presentationToMap` + `connections` + `customScreenId`),
   `executeConnection` (`presentation.execute(presentation.connections.firstOrNull { it.id == connectionId })`,
   null-id → `execute(null)` = default; run on main thread), `customScreenBack`, `customScreenClose`.
4. **`connections` in `presentationToMap`**: `PLYConnection.id` and `.default` are public on
   Android — direct mapping.
5. **Graceful degradation** (SDK no-crash rule): every handler try/catches and no-ops with a
   warn log if the registry entry is gone (e.g. execute after step already popped).

### 5.2 iOS (`purchasely/ios/Classes/SwiftPurchaselyFlutterPlugin.swift` + new files)

1. **Delegate registration**: plugin holds a `PurchaselyCustomScreenDelegate: NSObject,
   PLYCustomScreenViewControllerDelegate`, registered via
   `Purchasely.setCustomScreenViewControllerDelegate(...)` only when Dart calls
   `setCustomScreenProvider` (so iOS's "no delegate → self-close with warning" default is
   preserved when the Flutter app doesn't use the feature).
2. **`viewController(for:)`**:
   ```swift
   func viewController(for presentation: PLYPresentation) -> UIViewController? {
       let id = registerCustomScreenPresentation(presentation)
       let engine = engineGroup.makeEngine(with: options(entrypoint:, libraryURI:, entrypointArgs: [id]))
       return PurchaselyCustomScreenViewController(engine: engine, customScreenId: id)
   }
   ```
   `PurchaselyCustomScreenViewController: FlutterViewController` — cleans up registry +
   shuts the engine down in `deinit`/`viewDidDisappear` (when removed from parent).
3. **Custom-screen channel** handlers mirror Android. `executeConnection` maps `connectionId`
   → `presentation.connections.first { $0.id == connectionId }` then
   `presentation.executeConnection(conn)`; nil → `executeConnection(nil)` (SDK falls back to
   default connection). Dispatch to main queue.
4. **`connections` in `presentationToMap`**: iOS `PLYConnection` publicly exposes only `id`;
   the `default` flag is internal. → **Native iOS SDK prerequisite (tiny):** add
   `@objc public var isDefault: Bool { _connection.default }` to `PLYConnection`
   (Purchasely-iOS-Sources PR). Until merged, bridge `isDefault: false` on iOS and rely on
   `execute(null)` for default-connection behavior (functional, slightly degraded metadata).
5. SwiftUI delegate (`PLYCustomScreenViewDelegate`) is **not** bridged — irrelevant from Dart.

### 5.3 Event parity

Android fires `clientPresentationDisplayed` automatically on mount; `clientPresentationClosed`
is not auto-fired by the flow fragments. iOS shares the normal presentation lifecycle events.
→ In M5, verify `PRESENTATION_VIEWED`/`PRESENTATION_CLOSED` parity end-to-end on both
platforms; if the closed event is missing on Android when a custom step is popped, call
`Purchasely.clientPresentationClosed(presentation)` from `PurchaselyCustomScreenFragment.onDestroyView`
(guarded so flow-forward navigation vs. close is respected — align with whatever native does
for normal steps).

---

## 6. Milestones

Work on a branch off `feat/sdk-v6-migration`. TDD where the layer is testable
(Dart models/channel handlers); commit atomically per milestone.

| # | Milestone | Contents | Est. |
|---|---|---|---|
| M1 | **Models + standalone support** | `PLYConnection` Dart model; `connections` on `PLYPresentation` (+ `toMap`/`fromMap`); native `presentationToMap` additions (both platforms); `executeConnection` for requestId-held presentations; Dart unit tests | 1–1.5 d |
| M2 | **Android provider + engine host** | Provider registration, `PurchaselyCustomScreenFragment`, engine group, registry, custom-screen channel handlers | 2–3 d |
| M3 | **iOS delegate + engine host** | Delegate, `PurchaselyCustomScreenViewController`, engine group, channel handlers; iOS-Sources PR for `PLYConnection.isDefault` | 2–3 d |
| M4 | **Dart runtime API** | `Purchasely.setCustomScreenProvider/remove`, `PurchaselyCustomScreens.run`, `PLYCustomScreenPresentation` with `execute/back/close`; channel tests with `TestDefaultBinaryMessenger` | 1.5–2 d |
| M5 | **Example + E2E validation** | Example-app demo (entrypoint + per-connection buttons, mirroring native samples); manual E2E against a console flow with a CLIENT step on the example API key; verify: all 5 transition types, back navigation, pushed-inside-container steps, event parity, engine teardown (no leak via LeakCanary/Instruments), process-death restoration | 2–3 d |
| M6 | **Docs + release** | README + `sdk_public_doc.md` section, isolate DX guidance (§8), CHANGELOG/RELEASE_NOTES entry; fold into next 6.0.0-rc / 6.1.0 | 0.5–1 d |

Total ≈ 9–13 dev-days. M2 and M3 can be parallelized after M1 locks the wire contract.

---

## 7. Testing Strategy

- **Dart unit tests** (`purchasely/test/`): connection parsing (`isDefault`, missing ids),
  presentation map round-trip with `connections`/`customScreenId`, provider registration
  invoking the channel, `execute/back/close` sending correct payloads, graceful behavior on
  channel `PlatformException`.
- **Native**: keep plugin logic thin; registry add/remove and connection-lookup helpers unit
  tested where extractable (Android: plain JVM test for the id-matching helper).
- **E2E (manual first, scripted later)**: a dedicated flow on the example app's API key with
  a CLIENT step per transition type. The Android SDK integration tests use screen id
  `integration_test_my_own_screen` — check with the console team whether the same flow can be
  cloned to the Flutter example app (open question OQ-1).
- **Regression**: full existing test suites (`flutter test`, example builds on both
  platforms) — the presentation map change touches every presentation event.

---

## 8. DX Guidance (must ship with docs)

The custom-screen builder runs in a **dedicated isolate**:

- No shared memory with the main app: no Provider/Riverpod/Bloc/GetIt state, no main
  Navigator, no inherited themes.
- Recommended patterns: keep custom flow steps self-contained; feed configuration via the
  presentation's console-configured `metadata` (verify metadata is bridged in M1 — it exists
  natively; confirm the Dart model carries it); persist decisions via your backend or
  platform storage; advanced apps can bridge isolates with `IsolateNameServer`/`SendPort`.
- Registration must happen every launch **before** a client screen can appear (i.e. right
  after `Purchasely.start()`), including cold starts into a deeplinked flow — same guidance
  as native ("set during application initialization"). Android process-death restoration of
  a flow re-requests the custom screen, so late registration = blank step.

---

## 9. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Isolate isolation surprises customers (login step can't reach app state) | DX complaints, feature unused | Prominent docs (§8); metadata-driven pattern; keep Option B (pause/resume, MOB-200) on the roadmap as a complement |
| First-frame latency of spawned engine (blank container during transition) | Visible jank | Engine-group spawn is fast; optionally pre-warm one engine at `setCustomScreenProvider` and hand it to the first request; measure in M5 |
| Rendering inside bottom-sheet/popin containers (clipping, rounded corners, gestures) | Visual/interaction bugs | Texture render mode; explicit M5 test matrix over all 5 transitions incl. pushed-inside-container |
| Engine leak per step | Memory growth over long flows | `destroyEngineWithFragment(true)` / `deinit` teardown; leak check in M5 |
| Android `null` (blank) vs iOS `nil` (self-close) asymmetry | Behavior divergence | Bridge always returns a host when the provider is registered; when not registered, the native defaults apply unchanged (documented) |
| iOS `PLYConnection.isDefault` not public | `isDefault` wrong on iOS | Tiny iOS-Sources PR (M3); interim fallback documented in §5.2 |
| Custom screen widget embedding another `PLYPresentationView` platform view | Recursive/undefined behavior | Document as unsupported in v1 |

---

## 10. Open Questions

- **OQ-1**: Which console placement/flow (API key of the Flutter example app) will carry a
  CLIENT step for demos/E2E? Android integration tests use `integration_test_my_own_screen`;
  iOS used `cm_flow_byos`. Needs console setup or key reuse.
- **OQ-2**: Confirm iOS flow-step `back()` parity — the existing Dart `PLYPresentation.back()`
  path must behave identically when called from a custom flow step (Android pops one step via
  `onCloseRequested(false)`); verify the iOS equivalent during M3.
- **OQ-3**: Expose connection `actions` metadata (e.g. action types) to Dart? Deliberately
  **out of scope v1** — iOS keeps them opaque; parity = `id` + `isDefault` only.
- **OQ-4**: Should `PurchaselyCustomScreens.run` impose an app shell (MaterialApp) or stay
  bare? Plan says bare host + docs example using MaterialApp inside the builder — revisit
  with DX feedback.

---

## 11. Key Source References

**Native contract** (source of truth for parity):
- Android: `core/src/main/java/io/purchasely/ext/PLYCustomScreen.kt`,
  `ext/interfaces.kt:147` (`PLYCustomScreenProvider`), `ext/Purchasely.kt:1115`
  (`setCustomScreenProvider`), `ext/PLYConnection.kt`,
  `ext/presentation/PLYPresentationBase.kt:351-385` (`execute`/`back`/`close`),
  `views/flows/PLYFlowManager.kt:333` (`requestCustomScreen`),
  `views/flows/fragments/PLYFlowParentFragment.kt:468` (`onCustomScreenLoaded`),
  sample: `samplev2/.../SampleV2Application.kt:235`, tests:
  `integration-tests/.../CustomScreenProviderTests.kt`, `FlowTests.kt:124,588`.
- iOS: `Purchasely/Classes/common/Purchasely+CustomScreen.swift`,
  `Purchasely+PublicInterface.swift:813-857`,
  `Model/UI/PLYPresentation+CustomScreen.swift` (`executeConnection`),
  `Model/UI/PLYConnection.swift`,
  `specific/uikit/Controller/PLYProductViewController+Configure.swift:142-297`,
  sample: `Example/PurchaselySampleV2/.../Helpers/CustomScreens.swift`.

**Flutter bridge precedents** (this repo):
- Interceptor round trip: `purchasely/lib/src/bridge.dart`
  (`_handleInterceptorTriggered`/`_resolveInterceptor`),
  `android/.../PurchaselyFlutterPlugin.kt` (`pendingInterceptors`, `interceptorResolve`),
  `ios/Classes/SwiftPurchaselyFlutterPlugin.swift` (same).
- Presentation registry & marshalling: `presentationToMap` (both native mains),
  `loadedPresentations`, `clientPresentationDisplayed/Closed` handlers.
- Platform view (reverse-direction precedent only): `purchasely/lib/native_view_widget.dart`,
  `NativeView(.kt/.swift)`, `NativeViewFactory(.kt/.swift)`.
