# Migrating to Purchasely Flutter 6.0

Purchasely Flutter `6.0` aligns the plugin with the **cross-platform v6 SDK contract**.
The way you **display screens** and **intercept actions** has changed, and the
plugin now depends on the native **Purchasely 6.0** SDKs (Android `io.purchasely:core:6.0.0`,
iOS `Purchasely` 6.0.0).

> **Terminology:** the term *paywall* no longer exists. A monetization screen is now a
> **Presentation** (a *Screen* in the Console). The API uses `Presentation` everywhere.

> **Need help?** The **Purchasely AI plugin** can drive most of this migration for you.

---

## TL;DR — what changed

| Area | Before (5.x) | Now (6.0) |
|------|--------------|-----------|
| **Init** | `Purchasely.start(...)` | `PurchaselyBuilder.apiKey(...)…start()` |
| **Show a screen** | `Purchasely.presentPresentationForPlacement(...)`, `presentPresentationWithIdentifier(...)`, `fetchPresentation(...)`, `presentProductWithIdentifier(...)`, `presentPlanWithIdentifier(...)` | `PresentationBuilder.placement(id) / .screen(id)`, then `.build().display(...)` |
| **Inline screen widget** | `PLYPresentationView` (`native_view_widget.dart`) | **Removed** — use `display(Transition(type: TransitionType.inlinePaywall))` |
| **Action interceptor** | `Purchasely.setPaywallActionInterceptorCallback(...)` + `onProcessAction(...)` | `PurchaselyV6Bridge.ensureInstalled().registerInterceptor(PresentationActionKind, handler)` (typed, `InterceptResult`) |
| **Close / navigate** | `closePresentation()`, `hidePresentation()`, `showPresentation()` | `Presentation.close()` / `Presentation.back()` on the handle returned by `display()` |
| **Default result handler** | `setDefaultPresentationResultHandler(...)` | The `PresentationOutcome` returned/awaited by `display()` |

**Everything else from the 5.x API is kept** — purchases, restore, user login/logout,
user attributes, product/plan lookups, subscription data, analytics event streams,
dynamic offerings, consent, language/theme/log configuration. Those methods still live on
the `Purchasely` class; they simply require the SDK to be started via `PurchaselyBuilder`
first (same native singleton).

---

## 1. Initialization

**Before**
```dart
await Purchasely.start(
  apiKey: 'API_KEY',
  androidStores: ['Google'],
  userId: 'USER_ID',
  logLevel: LogLevel.debug,
  runningMode: PLYRunningMode.full,
);
```

**Now**
```dart
final ok = await PurchaselyBuilder.apiKey('API_KEY')
    .appUserId('USER_ID')
    .stores([PLYStore.google])
    .runningMode(V6RunningMode.full)
    .logLevel(V6LogLevel.debug)
    .start();
```

`Purchasely.start(...)` has been **removed**. `PurchaselyBuilder` is the single entry point.
After it resolves, the kept 5.x methods (`userLogin`, `setUserAttributeWithString`,
`restoreAllProducts`, `allProducts`, …) work exactly as before.

## 2. Displaying a Presentation (Screen)

**Before**
```dart
Purchasely.presentPresentationForPlacement(
  placementId: 'onboarding',
  onLoaded: (loaded) {},
).then((result) { /* PresentPresentationResult */ });
```

**Now**
```dart
final request = PresentationBuilder
    .placement('onboarding')
    .onLoaded(() {})
    .onDismissed((outcome) {})
    .build();

final outcome = await request.display(const Transition.modal());
// outcome: presentation, purchaseResult, plan, closeReason, error
```

- `fetchPresentation`, `presentPresentation`, `presentPresentationWithIdentifier`,
  `presentPresentationForPlacement`, `presentProductWithIdentifier`,
  `presentPlanWithIdentifier`, `getPresentationView`, `clientPresentationDisplayed`,
  `clientPresentationClosed`, `closePresentation`, `hidePresentation`, `showPresentation`,
  `close`, `setDefaultPresentationResultHandler`/`setDefaultPresentationResultCallback`
  are **removed**.
- `display()` resolves **at dismiss time** with a 5-field `PresentationOutcome`.
- To close/navigate programmatically, use the `Presentation` handle:
  `presentation.close()` / `presentation.back()`.

### Inline (embedded) screen

The `PLYPresentationView` Flutter widget (`native_view_widget.dart`) has been **removed** —
there is no embedded platform-view widget in v6. To render a screen inline, request the
inline transition:

```dart
await PresentationBuilder.placement('home').build()
    .display(const Transition(type: TransitionType.inlinePaywall));
```

## 3. Action interceptor

**Before**
```dart
Purchasely.setPaywallActionInterceptorCallback((action) {
  switch (action.info?.action) {
    case PLYPaywallAction.navigate: ...
  }
  Purchasely.onProcessAction(true);
});
```

**Now**
```dart
final bridge = PurchaselyV6Bridge.ensureInstalled();
bridge.registerInterceptor(PresentationActionKind.navigate, (info, payload) {
  // inspect payload (e.g. NavigatePayload), then:
  return InterceptResult.notHandled; // or .success / .failed
});
```

`setPaywallActionInterceptor`, `setPaywallActionInterceptorCallback`, `onProcessAction`,
and the `PLYPaywallAction` / `PLYPaywallInfo` / `PLYPaywallActionParameters` /
`PaywallActionInterceptorResult` types are **removed**, replaced by the typed v6 interceptor
(`PresentationActionKind`, `InterceptorInfo`, `ActionPayload`, `InterceptResult`).

## 4. Methods kept from 5.x (no change)

These remain on the `Purchasely` class and behave as before (after `PurchaselyBuilder.start`):

- **Purchases / restore:** `purchaseWithPlanVendorId`, `signPromotionalOffer`,
  `restoreAllProducts`, `silentRestoreAllProducts`, `isEligibleForIntroOffer`
- **Identity:** `userLogin`, `userLogout`, `isAnonymous`, `getAnonymousUserId`
- **Catalog:** `allProducts`, `productWithIdentifier`, `planWithIdentifier`
- **Subscriptions data:** `userSubscriptions`, `userSubscriptionsHistory`,
  `userDidConsumeSubscriptionContent`
- **User attributes:** `setUserAttributeWith*`, `incrementUserAttribute`,
  `decrementUserAttribute`, `userAttribute(s)`, `clearUserAttribute(s)`,
  `setUserAttributeListener`, `setAttribute`
- **Events:** `listenToEvents` / `listenToPurchases`
- **Dynamic offerings:** `setDynamicOffering`, `getDynamicOfferings`,
  `removeDynamicOffering`, `clearDynamicOfferings`
- **Config / misc:** `synchronize`, `setLanguage`, `setThemeMode`, `setLogLevel`,
  `readyToOpenDeeplink`, `isDeeplinkHandled`, `revokeDataProcessingConsent`, `setDebugMode`

## 5. Platform note — subscriptions screen

- **`presentSubscriptions` / `displaySubscriptionCancellationInstruction`** are still backed
  by the native SDK on **iOS** (the v6 SDK kept the subscriptions controller), but the
  **Android** native 6.0 SDK removed the built-in subscriptions screen, so these calls are
  **no-ops on Android**. For cross-platform consistency, prefer building the equivalent
  screen as a normal Presentation and reading subscription state via `userSubscriptions`.

## 6. Native SDK requirement

`6.0` requires the native Purchasely **6.0** SDKs:

- **Android:** `io.purchasely:core:6.0.0` (pulled from `mavenLocal` until published to
  Maven Central).
- **iOS:** `Purchasely` 6.0.0. The example app's iOS deployment target was raised to satisfy
  the 6.0 pod — make sure your app's `platform :ios` in the `Podfile` meets the same minimum.

---

## Full method mapping

| 5.x | 6.0 |
|-----|-----|
| `Purchasely.start(apiKey: …)` | `PurchaselyBuilder.apiKey(…)…start()` |
| `presentPresentationForPlacement(placementId:)` | `PresentationBuilder.placement(id).build().display(…)` |
| `presentPresentationWithIdentifier(presentationVendorId:)` | `PresentationBuilder.screen(id).build().display(…)` |
| `fetchPresentation(…)` + `presentPresentation(presentation:)` | `PresentationBuilder…build().preload()` then `display(…)` |
| `presentProductWithIdentifier` / `presentPlanWithIdentifier` | `PresentationBuilder.screen(id).contentId(…).build().display(…)` |
| `getPresentationView(...)` (`PLYPresentationView`) | `display(Transition(type: TransitionType.inlinePaywall))` |
| `closePresentation` / `hidePresentation` / `showPresentation` | `Presentation.close()` / `Presentation.back()` |
| `setDefaultPresentationResultHandler` | awaited `PresentationOutcome` from `display()` |
| `setPaywallActionInterceptorCallback` + `onProcessAction` | `PurchaselyV6Bridge.ensureInstalled().registerInterceptor(kind, handler)` → `InterceptResult` |
| `presentSubscriptions` | _removed (no native equivalent in 6.0)_ |
