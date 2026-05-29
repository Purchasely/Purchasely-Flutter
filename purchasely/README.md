![Purchasely](images/icon.png)

# Purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store and Huawei App Gallery.

## Installation

```yaml
dependencies:
  purchasely_flutter: ^6.0.0-beta.0
```

> **Migrating from 5.x?** Initialization, Presentation display and the action
> interceptor are now v6-only. See the full
> [migration guide](MIGRATION.md) for the before/after of every API.

## Usage

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

// 1. Start the SDK (fluent builder, `start()` resolves once configured).
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .runningMode(V6RunningMode.observer)
    .logLevel(V6LogLevel.error)
    .stores([PLYStore.google])
    .start();

// 2. Build a Presentation request and display it.
//    `.display(...)` resolves at *dismiss* time with the enriched 5-field
//    `PresentationOutcome` (presentation, purchaseResult, plan, closeReason,
//    error).
final outcome = await PresentationBuilder
    .placement('<YOUR_PLACEMENT_ID>')
    .contentId('article-42')
    .onLoaded((presentation, error) => print('loaded ${presentation.screenId}'))
    .onPresented((presentation, error) => print('shown'))
    .onDismissed((o) => print('dismissed: ${o.purchaseResult}'))
    .build()
    .display(const Transition.modal());

switch (outcome.purchaseResult) {
  case PurchaseResult.cancelled:
    print('User cancelled');
    break;
  case PurchaseResult.purchased:
    print('User purchased ${outcome.plan}');
    break;
  case PurchaseResult.restored:
    print('User restored ${outcome.plan}');
    break;
  case null:
    print('Dismissed without purchase action');
    break;
}
```

### Preloading a Presentation

Fetch a Presentation ahead of time without displaying it, then show it later:

```dart
final request = PresentationBuilder.placement('<YOUR_PLACEMENT_ID>').build();
await request.preload();
// …later…
final outcome = await request.display(const Transition.fullScreen());
```

### Action interceptor

Register a per-action interceptor to react to (or take over) actions triggered
from a Presentation. The handler returns an `InterceptResult` to tell the SDK
how the action was handled.

```dart
await PurchaselyV6Bridge.ensureInstalled().registerInterceptor(
  PresentationActionKind.navigate,
  (InterceptorInfo info, ActionPayload? payload) {
    if (payload is NavigatePayload) {
      print('navigate to ${payload.url}');
    }
    // Let the SDK keep handling the action.
    return InterceptResult.notHandled;
  },
);
```

## Migration from 5.x

The v6 release introduces a cross-platform fluent API matching the iOS and
Android v6 SDKs. **Initialization, Presentation display and the action
interceptor are v6-only** — the v5 `Purchasely.start(...)`, the v5 `present*` /
`fetchPresentation` / `getPresentationView` display APIs (and the
`PLYPresentationView` widget), and the v5 `setPaywallActionInterceptor` were
**removed in 6.0**. All other v5 methods (purchases, restore, login/logout,
attributes, products/plans, subscription data, events, dynamic offerings,
consent, config) are kept — they now require a `PurchaselyBuilder` start first.

A summary of the most common changes:

| Removed in 6.0 | v6 replacement |
|---|---|
| `Purchasely.start(apiKey: ..., runningMode: PLYRunningMode.full)` | `PurchaselyBuilder.apiKey(...).runningMode(V6RunningMode.full).start()` |
| `Purchasely.presentPresentationForPlacement(id, isFullscreen: true)` | `PresentationBuilder.placement(id).build().display(Transition.fullScreen())` |
| `Purchasely.fetchPresentation(...)` | `PresentationBuilder.placement(id).build().preload()` |
| `result.result` (3-value enum), `result.plan` | `outcome.presentation`, `outcome.purchaseResult`, `outcome.plan`, `outcome.closeReason`, `outcome.error` |
| `Purchasely.setPaywallActionInterceptor(...)` | `PurchaselyV6Bridge.ensureInstalled().registerInterceptor(PresentationActionKind.purchase, (info, payload) async => InterceptResult.notHandled)` |

See the full [migration guide](MIGRATION.md) for every removed/kept API and
step-by-step examples.

## 🏁 Documentation
A complete documentation is available on our website [https://docs.purchasely.com](https://docs.purchasely.com)