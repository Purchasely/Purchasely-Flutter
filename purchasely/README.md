![Purchasely](images/icon.png)

# Purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store and Huawei App Gallery.

> **Upgrading to 6.0?** The paywall surface (start, display/preload/close, action
> interceptor) moved to a fluent builder API; everything else on the `Purchasely`
> class is unchanged. See [`MIGRATION-v6.md`](../MIGRATION-v6.md) for the complete
> old→new mapping.

## Installation

```yaml
dependencies:
  purchasely_flutter: ^6.0.0
```

## Usage

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

// 1. Start the SDK (fluent builder, `start()` returns once configured).
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .runningMode(RunningMode.observer)
    .logLevel(LogLevel.error)
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

## Migration to 6.0

This release adapts the plugin to the Purchasely 6.0 native SDKs. Only the
paywall surface changed; everything else on the `Purchasely` class is unchanged.

| Old (`Purchasely.*`) | New |
|---|---|
| `Purchasely.start(apiKey: ..., runningMode: PLYRunningMode.full)` | `PurchaselyBuilder.apiKey(...).runningMode(RunningMode.full).start()` |
| `Purchasely.presentPresentationForPlacement(id, isFullscreen: true)` | `PresentationBuilder.placement(id).build().display(const Transition.fullScreen())` |
| `Purchasely.fetchPresentation(...)` | `PresentationBuilder.placement(id).build().preload()` |
| `result.result` (3-value enum), `result.plan` | `outcome.presentation`, `outcome.purchaseResult`, `outcome.plan`, `outcome.closeReason`, `outcome.error` |
| `Purchasely.setPaywallActionInterceptorCallback(...)` + `onProcessAction(bool)` | `PurchaselyBridge.ensureInstalled().registerInterceptor(PresentationActionKind.purchase, (info, payload) async => InterceptResult.notHandled)` |

See [`MIGRATION-v6.md`](../MIGRATION-v6.md) for the full old→new mapping and
before/after examples.

## 🏁 Documentation
A complete documentation is available on our website [https://docs.purchasely.com](https://docs.purchasely.com)