![Purchasely](images/icon.png)

# Purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store and Huawei App Gallery.

## Installation

```yaml
dependencies:
  purchasely_flutter: ^6.0.0-beta.0
```

## Usage (v6 — recommended)

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

// 1. Start the SDK (fluent builder, `start()` returns once configured).
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .runningMode(V6RunningMode.observer)
    .logLevel(V6LogLevel.error)
    .stores([PLYStore.google])
    .start();

// 2. Build a presentation request and display it.
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

## Migration to v6.x

The v6 release introduces a cross-platform fluent API matching the iOS and
Android v6 SDKs:

| v5 (still available, deprecated) | v6 (recommended) |
|---|---|
| `Purchasely.start(apiKey: ..., runningMode: PLYRunningMode.full)` | `PurchaselyBuilder.apiKey(...).runningMode(V6RunningMode.full).start()` |
| `Purchasely.presentPresentationForPlacement(id, isFullscreen: true)` | `PresentationBuilder.placement(id).build().display(Transition.fullScreen())` |
| `Purchasely.fetchPresentation(...)` | `PresentationBuilder.placement(id).build().preload()` |
| `result.result` (3-value enum), `result.plan` | `outcome.presentation`, `outcome.purchaseResult`, `outcome.plan`, `outcome.closeReason`, `outcome.error` |
| `Purchasely.setPaywallActionInterceptor((info, action, parameters, processAction) { ... })` | `Purchasely.interceptAction(PresentationActionKind.purchase, (info, payload) async => InterceptResult.notHandled)` |

The legacy `Purchasely.*` static surface continues to work during the v6
beta line for incremental migration. Both surfaces co-exist; you can adopt
the new API screen by screen.

## Usage (legacy v5)

```dart
bool configured = await Purchasely.start(
    apiKey: '<YOUR_API_KEY>',
    androidStores: ['Google, Huawei, Amazon'],
    storeKit1: false,
    logLevel: PLYLogLevel.error,
    runningMode: PLYRunningMode.full,
    userId: null,
);

var result = await Purchasely.presentPresentationForPlacement(
    '<YOUR_PLACEMENT_ID>', isFullscreen: true);
```

## 🏁 Documentation
A complete documentation is available on our website [https://docs.purchasely.com](https://docs.purchasely.com)