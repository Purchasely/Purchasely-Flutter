# Migrating to the Purchasely 6.0 native SDK (Flutter)

This release **adapts the Purchasely Flutter plugin to the Purchasely 6.0 native
SDKs** (iOS `Purchasely 6.0.0-rc.1`, Android `io.purchasely:core 6.0.0-rc.1`). Unlike the
React Native migration, there is **no "v6" naming in the Dart API** — the public
symbols keep their plain names (`PurchaselyBuilder`, `PresentationBuilder`,
`PresentationOutcome`, `Transition`, …).

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

## TL;DR

- Start the SDK with the fluent builder:
  `PurchaselyBuilder.apiKey('…').runningMode(RunningMode.full).start()`.
- Build a presentation with `PresentationBuilder`
  (`.placement(id)`, `.screen(id)`, `.defaultSource()`), then `.build()` to get
  a **`PresentationRequest`** with a lifecycle (`preload()`,
  `display([transition])`).
- `display([Transition])` resolves at **dismiss** with a 5-field
  **`PresentationOutcome`** (`presentation`, `purchaseResult`, `plan`,
  `closeReason`, `error`).
- A loaded `Presentation` exposes `display()`, `close()` and `back()` for
  programmatic control.
- The interceptor is now
  `Purchasely.interceptAction(kind, handler)`, where
  `handler` returns an `InterceptResult` (`success` / `failed` / `notHandled`).
- Inline rendering uses the `PLYPresentationView` widget.
- Other `Purchasely.*` methods remain source-compatible; deeplinks use the v6
  names — see [What's unchanged](#whats-unchanged).

---

## Removed / changed API → new equivalent

These were the paywall-related entry points on the `Purchasely` class. They have
been removed in favour of the builder API.

| Old (`Purchasely.*`, removed) | New |
|-------------------------------|-----|
| `Purchasely.start(apiKey: …, androidStores: …, storeKit1: …, logLevel: …, runningMode: …, userId: …)` | `PurchaselyBuilder.apiKey('…').appUserId(userId).runningMode(RunningMode.full).logLevel(LogLevel.error).stores([PLYStore.google]).storekitVersion(StorekitVersion.storeKit2).start()` |
| `Purchasely.fetchPresentation(placementId: id)` | `PresentationBuilder.placement(id).build().preload()` |
| `Purchasely.presentPresentationForPlacement(id, isFullscreen: …)` | `PresentationBuilder.placement(id).build().display(const Transition.fullScreen())` |
| `Purchasely.presentPresentationWithIdentifier(presentationId, …)` | `PresentationBuilder.screen(id).build().display(const Transition.modal())` |
| `Purchasely.presentPresentation(presentation)` | preload then display the same request: `final req = PresentationBuilder.placement(id).build(); await req.preload(); await req.display();` |
| `Purchasely.presentProductWithIdentifier(productId, …)` | `PresentationBuilder.screen(id).contentId(contentId).build().display()` |
| `Purchasely.presentPlanWithIdentifier(planId, …)` | `PresentationBuilder.screen(id).build().display()` |
| `Purchasely.getPresentationView(...)` | the `PLYPresentationView(request: …)` widget |
| `Purchasely.closePresentation()` / `hidePresentation()` / `close()` | `presentation.close()` (on the loaded `Presentation`) |
| `Purchasely.showPresentation()` | `presentation.display()` (on the loaded `Presentation`) |
| `Purchasely.clientPresentationDisplayed(...)` / `clientPresentationClosed(...)` | handled via the `PresentationRequest` lifecycle (`preload` → inspect `PresentationType.client` → render your own UI) |
| `Purchasely.setDefaultPresentationResultHandler(cb)` / `setDefaultPresentationResultCallback(cb)` | `Purchasely.setDefaultPresentationDismissHandler((outcome) => …)` — receives `PresentationOutcome` (`presentation`, `purchaseResult`, `plan`, `closeReason`, `error`) |
| `Purchasely.setPaywallActionInterceptorCallback(cb)` + `Purchasely.onProcessAction(bool)` | `Purchasely.interceptAction(kind, handler)` — handler returns `InterceptResult.success` / `.failed` / `.notHandled` (no more `onProcessAction`) |

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

final bool configured = await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .appUserId('user_id')                       // optional, defaults to anonymous
    .runningMode(RunningMode.full)              // RunningMode.observer (default) | full
    .logLevel(LogLevel.error)                   // debug | info | warn | error
    .allowDeeplink(true)                         // allow the SDK to open deeplinks
    .allowCampaigns(true)                        // optional campaign display gate
    .stores([PLYStore.google])                   // Android only: google | huawei | amazon
    .storekitVersion(StorekitVersion.storeKit2)  // iOS only: storeKit2 (default) | storeKit1
    .start();
```

> **Default running mode changed.** With the 6.0 native SDK the default
> `RunningMode` is `RunningMode.observer` — the host app keeps control of the
> purchase flow unless it opts into `RunningMode.full`. Pass
> `.runningMode(RunningMode.full)` to keep the previous behaviour where
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

`PresentationBuilder.placement(id).build()` returns a `PresentationRequest`.
Calling `display([Transition])` shows the screen and resolves at **dismiss**
with a `PresentationOutcome`.

```dart
final outcome = await PresentationBuilder.placement('<YOUR_PLACEMENT_ID>')
    .contentId('my_content_id')
    .build()
    .display(const Transition.fullScreen());

// outcome: presentation, purchaseResult, plan, closeReason, error
if (outcome.error != null) {
  print('Display error: ${outcome.error!.message}');
} else if (outcome.purchaseResult == PurchaseResult.purchased ||
    outcome.purchaseResult == PurchaseResult.restored) {
  print('Purchased ${outcome.plan}');
} else {
  print('Dismissed: ${outcome.closeReason}'); // button | backSystem | programmatic
}
```

`purchaseResult` is the `PurchaseResult` enum
(`purchased` / `cancelled` / `restored`) and is `null` when the user dismissed
the screen without a purchase action.

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
await PresentationBuilder.screen('SCREEN_ID').build().display(const Transition.modal());

// A specific product / content inside a screen (was presentProductWithIdentifier)
await PresentationBuilder.screen('SCREEN_ID').contentId('CONTENT_ID').build().display();
```

---

## Preloading (pre-fetch)

### Before

```dart
final presentation = await Purchasely.fetchPresentation(placementId: '<YOUR_PLACEMENT_ID>');
final result = await Purchasely.presentPresentation(presentation);
```

### After

Build a `PresentationRequest`, `preload()` it to fetch the screen from the
network, then `display()` the **same** request when you are ready.

```dart
final request = PresentationBuilder.placement('<YOUR_PLACEMENT_ID>').build();

final presentation = await request.preload(); // resolves when the screen is loaded

if (presentation.type == PresentationType.deactivated) {
  // No paywall to display for this placement
  return;
}
if (presentation.type == PresentationType.client) {
  // Display your own paywall (BYOS) — plan summaries are in presentation.plans
  return;
}

// Later, when ready to show it; resolves at dismiss
final outcome = await request.display(const Transition.fullScreen());
```

---

## Presentation lifecycle (display / close / back)

The imperative `showPresentation` / `hidePresentation` / `closePresentation`
methods are replaced by methods on the loaded `Presentation` handle (the one you
get from `preload()`, or from `outcome.presentation`):

```dart
final presentation = await PresentationBuilder.placement('ONBOARDING').build().preload();

presentation.display();  // show (returns a future that resolves at dismiss)
presentation.close();    // dismiss programmatically
presentation.back();     // navigate back inside a multi-step (Flow) presentation
```

---

## Action interceptor

`setPaywallActionInterceptorCallback` + `onProcessAction` are replaced by
`Purchasely.interceptAction(kind, handler)`. Register
**one handler per action kind**; the handler returns an `InterceptResult`
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
  PresentationActionKind.purchase,
  (info, payload) async {
    if (payload is PurchasePayload) {
      final ok = await MyPurchaseSystem.purchase(payload.plan.productId);
      return ok ? InterceptResult.success : InterceptResult.failed;
    }
    return InterceptResult.notHandled;
  },
);

await Purchasely.interceptAction(
  PresentationActionKind.navigate,
  (info, payload) async {
    if (payload is NavigatePayload) {
      // open payload.url with your router / url_launcher
      return InterceptResult.success;
    }
    return InterceptResult.notHandled;
  },
);

// Cleanup
await Purchasely.removeInterceptor(PresentationActionKind.purchase);
await Purchasely.removeAllInterceptors();
```

Action kinds (`PresentationActionKind`): `close`, `closeAll`, `login`,
`navigate`, `purchase`, `restore`, `openPresentation`, `openPlacement`,
`promoCode`, `webCheckout`. Each kind has a typed payload
(`NavigatePayload`, `PurchasePayload`, `ClosePayload`, `CloseAllPayload`,
`OpenPresentationPayload`, `OpenPlacementPayload`, `WebCheckoutPayload`);
payload-less kinds (`login`, `restore`, `promoCode`) carry no extra fields.

---

## Deeplinks, campaigns & default dismiss handler

```dart
// Allow deeplinks and campaigns at start:
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
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

---

## Inline (embedded) presentations

To render a presentation inline inside your widget tree, use the
`PLYPresentationView` widget with a `PresentationRequest`. The widget preloads
the request and hands the result to the native inline view.

```dart
import 'package:purchasely_flutter/native_view_widget.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

final request = PresentationBuilder.placement('onboarding')
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

> **`synchronize()` now reports completion.** The 6.0 native SDKs expose
> success/error callbacks on `synchronize()` (Android
> `synchronize(onSuccess, onError)`, iOS `synchronize(success:failure:)`).
> The Dart `Purchasely.synchronize()` keeps its `Future<void>` signature but
> now **resolves when the synchronization actually completes** and **throws a
> `PlatformException` on failure**, instead of the previous fire-and-forget
> behaviour. `await` it (and optionally `try/catch`) before chaining a
> follow-up presentation that targets subscribers. No call-site change is
> required for code that already `await`ed it.

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
