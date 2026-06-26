# Migrating to the Purchasely 6.0 native SDK (Flutter)

This release **adapts the Purchasely Flutter plugin to the Purchasely 6.0 native
SDKs** (iOS `Purchasely 6.0.0-rc.1`, Android `io.purchasely:core 6.0.0-rc.1`).

Three areas are breaking changes: **starting the SDK**, **displaying / preloading /
closing a presentation**, and the **action interceptor**. Everything else on the
`Purchasely` class — purchases, restore, identity, catalog, subscriptions, user
attributes, events, dynamic offerings, consent and config — remains
source-compatible except for removed v5 aliases. Deeplinks use the v6 names
(`allowDeeplink`, `handleDeeplink`).

A paywall is now called a **Presentation** (or *Screen*).

> **Tip — let the AI help you migrate.** The Purchasely AI plugin and the
> `purchasely-integrate`, `purchasely-review` and `purchasely-debug` skills can
> read your integration and rewrite the old paywall calls to the new builder
> API for you. Point them at the files that call `Purchasely.start(...)`,
> `Purchasely.presentPresentationForPlacement(...)`,
> `Purchasely.fetchPresentation(...)`,
> `Purchasely.setPaywallActionInterceptorCallback(...)`, etc.

---

## Changelog

### Breaking type renames (v5 → v6)

These v5 types have been renamed or restructured. Update all usages.

| Old (v5) | New (v6) |
|---|---|
| `PresentPresentationResult` | `PLYPresentationOutcome` |
| `PLYPaywallAction` | `PLYPresentationActionKind` |
| `PLYPaywallInfo` | `PLYInterceptorInfo` |
| `PLYPaywallActionParameters` | `PLYActionPayload` (+ typed `PLY*Payload` subclasses) |
| `PaywallActionInterceptorResult` | callback split into `(PLYInterceptorInfo, PLYActionPayload?, PLYActionInterceptorHandler)` — see [Action interceptor](#action-interceptor) |

**`PLYRunningMode` values changed.** The old (v5-era) `PLYRunningMode` had four
values: `transactionOnly`, `observer`, `paywallObserver`, `full`. The new enum
only has `observer` (index 0) and `full` (index 1). Any reference to
`PLYRunningMode.transactionOnly` or `PLYRunningMode.paywallObserver` must be
removed.

**New `PLYTransition` factory constructors.** `PLYTransition.drawer()` and
`PLYTransition.popin()` are now available, mirroring `PLYTransition.modal()` and
`PLYTransition.fullScreen()`. See [Sized transitions](#sized-transitions-drawer--popin--breaking)
below.

**`.preload().display()` chain.** An extension on `Future<PLYPresentation>` lets
you chain `preload()` directly into `display()` without a separate `await`:

```dart
final outcome = await PLYPresentationBuilder.placement('onboarding')
    .build()
    .preload()
    .display(const PLYTransition.drawer(height: PLYTransitionDimension.percentage(0.5)));
```

---

## TL;DR

- Start the SDK with the fluent builder:
  `Purchasely.apiKey('…').runningMode(PLYRunningMode.full).start()`.
- Build a presentation with `PLYPresentationBuilder`
  (`.placement(id)`, `.screen(id)`, `.defaultSource()`), then `.build()` to get
  a **`PLYPresentationRequest`** with a lifecycle (`preload()`,
  `display([transition])`).
- `display([PLYTransition])` resolves at **dismiss** with a 5-field
  **`PLYPresentationOutcome`** (`presentation`, `purchaseResult`, `plan`,
  `closeReason`, `error`).
- A loaded `PLYPresentation` exposes `display()`, `close()` and `back()` for
  programmatic control.
- The interceptor is now
  `Purchasely.interceptAction(kind, handler)`, where
  `handler` returns a `PLYInterceptResult` (`success` / `failed` / `notHandled`).
- Inline rendering uses the `PLYPresentationView` widget.
- Other `Purchasely.*` methods remain source-compatible; deeplinks use the v6
  names — see [What's unchanged](#whats-unchanged).

---

## Removed / changed API → new equivalent

These were the paywall-related entry points on the `Purchasely` class. They have
been removed in favour of the builder API.

| Old (`Purchasely.*`, removed) | New |
|-------------------------------|-----|
| `Purchasely.start(apiKey: …, androidStores: …, storeKit1: …, logLevel: …, runningMode: …, userId: …)` | `Purchasely.apiKey('…').appUserId(userId).runningMode(PLYRunningMode.full).logLevel(PLYLogLevel.error).stores([PLYStore.google]).storekitVersion(PLYStorekitVersion.storeKit2).start()` |
| `Purchasely.fetchPresentation(placementId: id)` | `PLYPresentationBuilder.placement(id).build().preload()` |
| `Purchasely.presentPresentationForPlacement(id, isFullscreen: …)` | `PLYPresentationBuilder.placement(id).build().display(const PLYTransition.fullScreen())` |
| `Purchasely.presentPresentationWithIdentifier(presentationId, …)` | `PLYPresentationBuilder.screen(id).build().display(const PLYTransition.modal())` |
| `Purchasely.presentPresentation(presentation)` | preload then display the same request: `final req = PLYPresentationBuilder.placement(id).build(); await req.preload(); await req.display();` |
| `Purchasely.presentProductWithIdentifier(productId, …)` | `PLYPresentationBuilder.screen(id).contentId(contentId).build().display()` |
| `Purchasely.presentPlanWithIdentifier(planId, …)` | `PLYPresentationBuilder.screen(id).build().display()` |
| `Purchasely.getPresentationView(...)` | the `PLYPresentationView(request: …)` widget |
| `Purchasely.closePresentation()` / `hidePresentation()` / `close()` | `presentation.close()` (on the loaded `PLYPresentation`) |
| `Purchasely.showPresentation()` | `presentation.display()` (on the loaded `PLYPresentation`) |
| `Purchasely.clientPresentationDisplayed(...)` / `clientPresentationClosed(...)` | handled via the `PLYPresentationRequest` lifecycle (`preload` → inspect `PLYPresentationType.client` → render your own UI) |
| `Purchasely.setDefaultPresentationResultHandler(cb)` / `setDefaultPresentationResultCallback(cb)` | `Purchasely.setDefaultPresentationDismissHandler((outcome) => …)` — receives `PLYPresentationOutcome` (`presentation`, `purchaseResult`, `plan`, `closeReason`, `error`) |
| `Purchasely.setPaywallActionInterceptorCallback(cb)` + `Purchasely.onProcessAction(bool)` | `Purchasely.interceptAction(kind, handler)` — handler returns `PLYInterceptResult.success` / `.failed` / `.notHandled` (no more `onProcessAction`) |

> **Reminder.** Everything *not* in this table — purchases, restore, login,
> attributes, subscriptions, products, events, offerings, consent and config —
> keeps source-compatible `Purchasely.*` signatures. Deeplinks use the v6 names
> documented below.

---

## Initialization

### Before

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

bool configured = await Purchasely.start(
  apiKey: '<YOUR_API_KEY>',
  androidStores: ['Google'],
  storeKit1: false,
  logLevel: PLYLogLevel.error,
  runningMode: PLYRunningMode.full,
  userId: 'user_id',
);

Purchasely.readyToOpenDeeplink(true); // removed in v6; use allowDeeplink
```

### After

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

final bool configured = await Purchasely.apiKey('<YOUR_API_KEY>')
    .appUserId('user_id')                          // optional, defaults to anonymous
    .runningMode(PLYRunningMode.full)              // PLYRunningMode.observer (default) | full
    .logLevel(PLYLogLevel.error)                   // debug | info | warn | error
    .allowDeeplink(true)                           // allow the SDK to open deeplinks
    .allowCampaigns(true)                          // optional campaign display gate
    .stores([PLYStore.google])                     // Android only: google | huawei | amazon
    .storekitVersion(PLYStorekitVersion.storeKit2) // iOS only: storeKit2 (default) | storeKit1
    .start();
```

> **Default running mode changed.** With the 6.0 native SDK the default
> `PLYRunningMode` is `PLYRunningMode.observer` — the host app keeps control of
> the purchase flow unless it opts into `PLYRunningMode.full`. Pass
> `.runningMode(PLYRunningMode.full)` to keep the previous behaviour where
> Purchasely owns the purchase flow.

> **`allowDeeplink` replaces the old v5 name.** Allowing deeplinks can be set on
> the builder or toggled later with `Purchasely.allowDeeplink(bool)`.
> `readyToOpenDeeplink` was removed from the Flutter v6 API.

---

## Displaying a presentation

### Before

```dart
final result = await Purchasely.presentPresentationForPlacement(
  '<YOUR_PLACEMENT_ID>',
  contentId: 'my_content_id',
  isFullscreen: true,
);

switch (result.result) {
  case PLYPurchaseResult.purchased:
  case PLYPurchaseResult.restored:
    print('Purchased ${result.plan?.name}');
    break;
  case PLYPurchaseResult.cancelled:
    break;
}
```

### After

`PLYPresentationBuilder.placement(id).build()` returns a `PLYPresentationRequest`.
Calling `display([PLYTransition])` shows the screen and resolves at **dismiss**
with a `PLYPresentationOutcome`.

```dart
final outcome = await PLYPresentationBuilder.placement('<YOUR_PLACEMENT_ID>')
    .contentId('my_content_id')
    .build()
    .display(const PLYTransition.fullScreen());

// outcome: presentation, purchaseResult, plan, closeReason, error
if (outcome.error != null) {
  print('Display error: ${outcome.error!.message}');
} else if (outcome.purchaseResult == PLYPurchaseResult.purchased ||
    outcome.purchaseResult == PLYPurchaseResult.restored) {
  print('Purchased ${outcome.plan?.name}');
} else {
  print('Dismissed: ${outcome.closeReason}'); // button | backSystem | programmatic
}
```

`purchaseResult` is the `PLYPurchaseResult` enum
(`purchased` / `cancelled` / `restored`) and is `null` when the user dismissed
the screen without a purchase action.

`plan` is a fully-typed **`PLYPlan?`** — the same model returned by
`planWithIdentifier` and carried by a purchase interceptor's `PLYPurchasePayload`.
Read its fields directly (`outcome.plan?.vendorId`, `outcome.plan?.name`,
`outcome.plan?.amount`, …). It is `null` when no purchase action produced a plan.

> **iOS / Android `closeReason` parity.** Both native 6.0 SDKs now expose
> `closeReason` on the outcome, and Flutter surfaces it on both platforms
> (`button` / `backSystem` / `programmatic`). iOS maps its
> `interactiveDismiss` (swipe-down / nav-pop) to `backSystem` to stay aligned
> with Android's `BACK_SYSTEM`. The only field still iOS-`null` is the loaded
> presentation `contentId` (`PLYPresentation` does not expose it on iOS);
> Android 6.0 reports it.

> **Plan offer fields.** Android 6.0 renamed introductory-price helpers to
> offer-price helpers. Flutter now exposes the v6 names (`hasOfferPrice`,
> `offerPrice`, `offerAmount`, `offerDuration`, `offerPeriod`) and keeps the old
> `intro*` fields populated as deprecated compatibility aliases.

### Targeting a specific screen / product

```dart
// A specific presentation by screen id (was presentPresentationWithIdentifier)
await PLYPresentationBuilder.screen('SCREEN_ID').build().display(const PLYTransition.modal());

// A specific product / content inside a screen (was presentProductWithIdentifier)
await PLYPresentationBuilder.screen('SCREEN_ID').contentId('CONTENT_ID').build().display();
```

### Sized transitions (`drawer` / `popin`) — BREAKING

`Transition.heightPercentage` was **removed**. Drawer and popin transitions are
now sized with the native dimension model, mirroring Android's
`PLYTransitionDimension`. Use the `width` (popin only) and `height` (drawer +
popin) fields with a `PLYTransitionDimension`, expressed as a `percentage`
(`0.0`–`1.0`) or fixed `pixel` value. Leave a dimension `null` to size to
content ("hug").

Named factory constructors are provided for `drawer` and `popin` (like
`PLYTransition.modal()` and `PLYTransition.fullScreen()`):

```dart
// Before (v5 / removed):
// Transition(type: TransitionType.drawer, heightPercentage: 0.5);

// After — factory constructors (preferred):
const PLYTransition.drawer(height: PLYTransitionDimension.percentage(0.5));
const PLYTransition.drawer(height: PLYTransitionDimension.pixel(300));

const PLYTransition.popin(
  width: PLYTransitionDimension.pixel(320),
  height: PLYTransitionDimension.percentage(0.6),
  dismissible: false,
);

// After — explicit constructor (equivalent):
const PLYTransition(
  type: PLYTransitionType.drawer,
  height: PLYTransitionDimension.percentage(0.5),
);
```

Available factory constructors on `PLYTransition`:

| Constructor | Description |
|---|---|
| `PLYTransition.fullScreen()` | Full-screen (default) |
| `PLYTransition.modal({bool? dismissible})` | Modal sheet |
| `PLYTransition.push()` | Push / navigation |
| `PLYTransition.drawer({PLYTransitionDimension? height, bool? dismissible, PLYTransitionColors? backgroundColors})` | Bottom drawer with optional height |
| `PLYTransition.popin({PLYTransitionDimension? width, PLYTransitionDimension? height, bool? dismissible, PLYTransitionColors? backgroundColors})` | Floating pop-in with optional dimensions |

---

## Preloading (pre-fetch)

### Before

```dart
final presentation = await Purchasely.fetchPresentation(placementId: '<YOUR_PLACEMENT_ID>');
final result = await Purchasely.presentPresentation(presentation);
```

### After

Build a `PLYPresentationRequest`, `preload()` it to fetch the screen from the
network, then `display()` the loaded `PLYPresentation` when you are ready.

**Pattern A — separate preload and display** (preload early, display later):

```dart
final request = PLYPresentationBuilder.placement('<YOUR_PLACEMENT_ID>').build();

final presentation = await request.preload(); // resolves when the screen is loaded

if (presentation.type == PLYPresentationType.deactivated) {
  return; // No paywall to display for this placement
}
if (presentation.type == PLYPresentationType.client) {
  return; // Display your own paywall (BYOS) — plan summaries are in presentation.plans
}

// Later, when ready to show it; resolves at dismiss
final outcome = await presentation.display(const PLYTransition.fullScreen());
```

**Pattern B — chained preload and display** (preload + display in one expression):

```dart
final outcome = await PLYPresentationBuilder.placement('<YOUR_PLACEMENT_ID>')
    .build()
    .preload()
    .display(const PLYTransition.drawer(height: PLYTransitionDimension.percentage(0.5)));
```

> `preload()` on `PLYPresentationRequest` returns `Future<PLYPresentation>`. The
> `display([PLYTransition?])` method is available both on `PLYPresentation`
> directly (Pattern A) and via a `Future<PLYPresentation>` extension (Pattern B).

---

## Presentation lifecycle (display / close / back)

The imperative `showPresentation` / `hidePresentation` / `closePresentation`
methods are replaced by methods on the loaded `PLYPresentation` handle (the one
you get from `preload()`, or from `outcome.presentation`):

```dart
final presentation = await PLYPresentationBuilder.placement('ONBOARDING').build().preload();

presentation.display();  // show (returns a future that resolves at dismiss)
presentation.close();    // dismiss programmatically
presentation.back();     // navigate back inside a multi-step (Flow) presentation
```

---

## Action interceptor

`setPaywallActionInterceptorCallback` + `onProcessAction` are replaced by
`Purchasely.interceptAction(kind, handler)`. Register
**one handler per action kind**; the handler returns a `PLYInterceptResult`
(`success` / `failed` / `notHandled`) instead of calling
`onProcessAction(true/false)`.

### Before

```dart
Purchasely.setPaywallActionInterceptorCallback((info, action, parameters, processAction) {
  if (action == PLYPaywallAction.purchase) {
    MyPurchaseSystem.purchase(parameters.plan.productId);
    Purchasely.onProcessAction(false);
  } else {
    Purchasely.onProcessAction(true);
  }
});
```

### After

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

await Purchasely.interceptAction(
  PLYPresentationActionKind.purchase,
  (info, payload) async {
    if (payload is PLYPurchasePayload) {
      final ok = await MyPurchaseSystem.purchase(payload.plan.productId);
      return ok ? PLYInterceptResult.success : PLYInterceptResult.failed;
    }
    return PLYInterceptResult.notHandled;
  },
);

await Purchasely.interceptAction(
  PLYPresentationActionKind.navigate,
  (info, payload) async {
    if (payload is PLYNavigatePayload) {
      // open payload.url with your router / url_launcher
      return PLYInterceptResult.success;
    }
    return PLYInterceptResult.notHandled;
  },
);

// Cleanup
await Purchasely.removeActionInterceptor(PLYPresentationActionKind.purchase);
await Purchasely.removeAllActionInterceptors();
```

Action kinds (`PLYPresentationActionKind`): `close`, `closeAll`, `login`,
`navigate`, `purchase`, `restore`, `openPresentation`, `openPlacement`,
`promoCode`, `webCheckout`. Each kind has a typed payload
(`PLYNavigatePayload`, `PLYPurchasePayload`, `PLYClosePayload`,
`PLYCloseAllPayload`, `PLYOpenPresentationPayload`, `PLYOpenPlacementPayload`,
`PLYWebCheckoutPayload`); payload-less kinds (`login`, `restore`, `promoCode`)
carry no extra fields.

---

## Deeplinks, campaigns & default dismiss handler

```dart
// Allow deeplinks and campaigns at start:
await Purchasely.apiKey('<YOUR_API_KEY>')
    .allowDeeplink(true)
    .allowCampaigns(true)
    .start();

// These runtime gates are independent.
await Purchasely.allowDeeplink(true);
await Purchasely.allowCampaigns(false);

// Default dismiss handler (renamed from setDefaultPresentationResultHandler).
// Used for presentations opened by the SDK itself: campaigns, deeplinks,
// promoted in-app purchases.
await Purchasely.setDefaultPresentationDismissHandler((outcome) {
  print('SDK presentation dismissed: ${outcome.presentation?.screenId} / '
      '${outcome.purchaseResult} / ${outcome.closeReason}');
});

// v6 deeplink handler:
final handled = await Purchasely.handleDeeplink('app://ply/presentations/');
```

### Where the dismiss outcome is delivered (routing)

A dismissed presentation produces one `PLYPresentationOutcome`. There are three
ways to receive it:

| Channel | What it is |
|---------|------------|
| `await display()` | the **return value** — you await the call and get the outcome inline |
| `onDismissed` | a **per-presentation** callback attached to *this* request/presentation |
| `setDefaultPresentationDismissHandler` | a single **global** handler for the whole app |

**Routing rule:** at dismiss, the outcome goes to the **`onDismissed` handler if
one is set, otherwise to the global default handler.** The deciding factor is the
*presence of `onDismissed`* — not whether you awaited the future. Awaiting
`display()` always gives you the outcome as a return value, but it does **not** by
itself suppress the global handler.

```dart
await Purchasely.setDefaultPresentationDismissHandler((outcome) {
  print('caught globally: ${outcome.purchaseResult}');
});

// (A) fire-and-forget, no onDismissed → the GLOBAL handler receives it.
PLYPresentationBuilder.placement('PLACEMENT').build().display();

// (B) local onDismissed set → the LOCAL handler receives it, global stays silent.
PLYPresentationBuilder.placement('PLACEMENT')
    .onDismissed((outcome) => print('caught locally'))
    .build()
    .display();

// (C) await without onDismissed → the return value AND the global handler both
//     receive it (set an onDismissed if you want the global to stay silent).
final outcome =
    await PLYPresentationBuilder.placement('PLACEMENT').build().display();

// (D) await + onDismissed → return value + local handler receive it, global silent.
```

> **Rule of thumb:** pick *one* channel per presentation — await it, **or** set
> `onDismissed`, **or** leave both off and let the global handler catch it.
> The global handler is also the path for presentations the SDK opens itself
> (campaigns, deeplinks, promoted in-app purchases), which have no host-side
> `display()` call to await.

---

## Inline (embedded) presentations

To render a presentation inline inside your widget tree, use the
`PLYPresentationView` widget with a `PLYPresentationRequest`. The widget preloads
the request and hands the result to the native inline view.

```dart
import 'package:purchasely_flutter/native_view_widget.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

final request = PLYPresentationBuilder.placement('onboarding')
    .onDismissed((outcome) => print('inline dismissed: ${outcome.purchaseResult}'))
    .build();

// In your build():
PLYPresentationView(request: request);
```

---

## What's unchanged

Only the **paywall surface** (start, display / preload / close / back, and the
action interceptor) has breaking API changes. Every other `Purchasely.*` method
remains source-compatible except for removed v5 aliases; deeplinks use v6 names:

- **Purchases**: `purchaseWithPlanVendorId`, `signPromotionalOffer`.
- **Restore**: `restoreAllProducts`, `silentRestoreAllProducts`,
  `userDidConsumeSubscriptionContent`.
- **Identity**: `userLogin`, `userLogout`, `isAnonymous`, `anonymousUserId`.
- **Catalog**: `allProducts`, `productWithIdentifier`, `planWithIdentifier`,
  `isEligibleForIntroOffer`.
- **Subscriptions data**: `userSubscriptions`, `userSubscriptionsHistory`,
  `displaySubscriptionCancellationInstruction` (no-op on both platforms — see
  callout below). Note: `presentSubscriptions()` was **removed** (see callout).
- **User attributes**: `setUserAttributeWithString` / `WithInt` / `WithDouble` /
  `WithBoolean` / `WithDate` / `WithStringArray` / `WithIntArray` /
  `WithDoubleArray` / `WithBooleanArray`, `incrementUserAttribute`,
  `decrementUserAttribute`, `userAttribute`, `userAttributes`,
  `clearUserAttribute`, `clearUserAttributes`, `clearBuiltInAttributes`,
  `setAttribute`, `setUserAttributeListener` / `clearUserAttributeListener`.
- **Events**: `listenToEvents` / `stopListeningToEvents`, `listenToPurchases` /
  `stopListeningToPurchases`.
- **Dynamic offerings**: `setDynamicOffering`, `getDynamicOfferings`,
  `removeDynamicOffering`, `clearDynamicOfferings`.
- **Consent**: `revokeDataProcessingConsent`.
- **Config / misc**: `setLanguage`, `setThemeMode`, `setLogLevel`,
  `synchronize`, `allowDeeplink`, `allowCampaigns`, `handleDeeplink`,
  `setDebugMode`. (`readyToOpenDeeplink` / `isDeeplinkHandled` were removed.)

> **`synchronize()` now reports completion (BREAKING signature).** The 6.0
> native SDKs expose success/error callbacks on `synchronize()` (Android
> `synchronize(onSuccess, onError)`, iOS `synchronize(success:failure:)`).
> `Purchasely.synchronize()` now returns **`Future<bool>`** (was `Future<void>`):
> it **resolves with `true` when the synchronization actually completes** and
> **throws a `PlatformException` on failure**, instead of the previous
> fire-and-forget behaviour. `await` it (and optionally `try/catch`) before
> chaining a follow-up presentation that targets subscribers.

> **Removed `presentSubscriptions()` (BREAKING).** The native subscriptions
> screen was removed from the 6.0 SDKs on both platforms (the iOS
> `subscriptionsController()` entry point no longer exists in native 6.0, and
> Android dropped its built-in screen). `Purchasely.presentSubscriptions()` has
> therefore been **removed entirely** from the Flutter API on every layer (Dart,
> iOS, Android) — it is no longer a no-op, the method no longer exists. There is
> no drop-in replacement: build your own subscriptions screen with
> `userSubscriptions()` / `userSubscriptionsHistory()`.
>
> The cancellation survey UI was likewise removed, so
> `Purchasely.displaySubscriptionCancellationInstruction()` is kept for source
> compatibility but is a **no-op on both Android and iOS**.

> **Native dependency.** This release targets the Purchasely 6.0 native SDKs,
> pinned to the **`6.0.0-rc.1`** pre-release on both platforms
> (Android `io.purchasely:core` / `google-play` / `player` `6.0.0-rc.1`;
> iOS `Purchasely` `6.0.0-rc.1`). Both are published — Android on **Maven
> Central**, iOS on the **CocoaPods trunk** — so the project builds from the
> public repositories with no `mavenLocal()` and no development pod.

---

## Need a hand?

Use the Purchasely AI plugin / skills (`purchasely-integrate`,
`purchasely-review`, `purchasely-debug`) to scan your project and apply this
migration automatically.
