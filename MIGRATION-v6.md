# Migrating to the Purchasely 6.0 native SDK (Flutter)

This release **adapts the Purchasely Flutter plugin to the Purchasely 6.0 native
SDKs** (iOS `Purchasely 6.0.0`, Android `io.purchasely:core 6.0.0`). Unlike the
React Native migration, there is **no "v6" naming in the Dart API** — the public
symbols keep their plain names (`PurchaselyBuilder`, `PresentationBuilder`,
`PresentationOutcome`, `Transition`, …).

Only three areas changed: **starting the SDK**, **displaying / preloading /
closing a presentation**, and the **action interceptor**. Everything else on the
`Purchasely` class — purchases, restore, identity, catalog, subscriptions, user
attributes, events, dynamic offerings, consent and config — is **unchanged**.

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
  `PurchaselyBridge.ensureInstalled().registerInterceptor(kind, handler)`, where
  `handler` returns an `InterceptResult` (`success` / `failed` / `notHandled`).
- Inline rendering uses the `PLYPresentationView` widget.
- **All other `Purchasely.*` methods are UNCHANGED** — see
  [What's unchanged](#whats-unchanged).

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
| `Purchasely.setDefaultPresentationResultHandler(cb)` / `setDefaultPresentationResultCallback(cb)` | `PresentationBuilder.defaultSource().onDismissed((outcome) => …).build().display()` |
| `Purchasely.setPaywallActionInterceptorCallback(cb)` + `Purchasely.onProcessAction(bool)` | `PurchaselyBridge.ensureInstalled().registerInterceptor(kind, handler)` — handler returns `InterceptResult.success` / `.failed` / `.notHandled` (no more `onProcessAction`) |

> **Reminder.** Everything *not* in this table — purchases, restore, login,
> attributes, subscriptions, products, events, offerings, consent and config —
> keeps the exact same `Purchasely.*` signatures. Only the paywall surface
> moved.

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

Purchasely.readyToOpenDeeplink(true);
```

### After

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

final bool configured = await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .appUserId('user_id')                       // optional, defaults to anonymous
    .runningMode(RunningMode.full)              // RunningMode.observer (default) | full
    .logLevel(LogLevel.error)                   // debug | info | warn | error
    .allowDeeplink(true)                         // allow the SDK to open deeplinks
    .allowCampaigns(true)                        // automatic campaigns (default true)
    .stores([PLYStore.google])                   // Android only: google | huawei | amazon
    .storekitVersion(StorekitVersion.storeKit2)  // iOS only: storeKit2 (default) | storeKit1
    .start();
```

> **Default running mode changed.** With the 6.0 native SDK the default
> `RunningMode` is `RunningMode.observer` — the host app keeps control of the
> purchase flow unless it opts into `RunningMode.full`. Pass
> `.runningMode(RunningMode.full)` to keep the previous behaviour where
> Purchasely owns the purchase flow.

> **`allowDeeplink` replaces the start-time call.** Allowing deeplinks is now
> part of the builder. `Purchasely.readyToOpenDeeplink(bool)` still exists if you
> need to toggle it later at runtime.

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
`PurchaselyBridge.ensureInstalled().registerInterceptor(kind, handler)`. Register
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

final bridge = PurchaselyBridge.ensureInstalled();

await bridge.registerInterceptor(
  PresentationActionKind.purchase,
  (info, payload) async {
    if (payload is PurchasePayload) {
      final ok = await MyPurchaseSystem.purchase(payload.plan['productId']);
      return ok ? InterceptResult.success : InterceptResult.failed;
    }
    return InterceptResult.notHandled;
  },
);

await bridge.registerInterceptor(
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
await bridge.removeInterceptor(PresentationActionKind.purchase);
await bridge.removeAllInterceptors();
```

Action kinds (`PresentationActionKind`): `close`, `closeAll`, `login`,
`navigate`, `purchase`, `restore`, `openPresentation`, `openPlacement`,
`promoCode`, `webCheckout`. Each kind has a typed payload
(`NavigatePayload`, `PurchasePayload`, `ClosePayload`, `CloseAllPayload`,
`OpenPresentationPayload`, `OpenPlacementPayload`, `WebCheckoutPayload`);
payload-less kinds (`login`, `restore`, `promoCode`) carry no extra fields.

---

## Deeplinks & default result handler

```dart
// Allow deeplinks at start:
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>').allowDeeplink(true).start();

// Default result handler (replaces setDefaultPresentationResultHandler) — attach
// onDismissed to a default-source request:
PresentationBuilder.defaultSource()
    .onDismissed((outcome) {
      print('Deeplink presentation dismissed: ${outcome.purchaseResult} / ${outcome.closeReason}');
    })
    .build()
    .display();

// isDeeplinkHandled is UNCHANGED:
final handled = await Purchasely.isDeeplinkHandled('app://ply/presentations/');
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
action interceptor) changed. Every other `Purchasely.*` method keeps the same
name, signature and behaviour:

- **Purchases**: `purchaseWithPlanVendorId`, `signPromotionalOffer`.
- **Restore**: `restoreAllProducts`, `silentRestoreAllProducts`,
  `userDidConsumeSubscriptionContent`.
- **Identity**: `userLogin`, `userLogout`, `isAnonymous`, `anonymousUserId`.
- **Catalog**: `allProducts`, `productWithIdentifier`, `planWithIdentifier`,
  `isEligibleForIntroOffer`.
- **Subscriptions data**: `userSubscriptions`, `userSubscriptionsHistory`,
  `presentSubscriptions` (see callout below),
  `displaySubscriptionCancellationInstruction`.
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
  `synchronize`, `readyToOpenDeeplink`, `isDeeplinkHandled`, `setDebugMode`.

> **`presentSubscriptions` is a no-op on Android in 6.0.** The native
> subscriptions screen was removed from the Android SDK, so
> `Purchasely.presentSubscriptions()` does nothing on Android. It still works on
> iOS. Build your own subscriptions screen with `userSubscriptions()` if you
> need cross-platform parity.

> **Native dependency.** This release targets the Purchasely 6.0 native SDKs
> (iOS `Purchasely 6.0.0`, Android `io.purchasely:core 6.0.0`). These versions
> may not be published on CocoaPods / Maven Central yet; local builds resolve
> them via `mavenLocal()` (Android) and a development pod (iOS).

---

## Need a hand?

Use the Purchasely AI plugin / skills (`purchasely-integrate`,
`purchasely-review`, `purchasely-debug`) to scan your project and apply this
migration automatically.
