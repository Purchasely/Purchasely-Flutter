![Purchasely](images/icon.png)

# Purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store and Huawei App Gallery.

> **Upgrading to 6.0?** The paywall surface (start, display/preload/close, action
> interceptor) moved to a fluent builder API; other `Purchasely` APIs remain
> source-compatible (deeplinks use v6 names). See
> [`MIGRATION-v6.md`](../MIGRATION-v6.md) for the complete old→new mapping.

## Installation

```yaml
dependencies:
  purchasely_flutter: 6.0.0
```

## Usage

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

// 1. Start the SDK (fluent builder, `start()` returns once configured).
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .runningMode(PLYRunningMode.observer)
    .logLevel(PLYLogLevel.error)
    .stores([PLYStore.google])
    .start();

// 2. Build a presentation request and display it.
//    `.display(...)` resolves at *dismiss* time with the enriched 5-field
//    `PLYPresentationOutcome` (presentation, purchaseResult, plan, closeReason,
//    error).
final outcome = await PLYPresentationBuilder
    .placement('<YOUR_PLACEMENT_ID>')
    .contentId('article-42')
    .onLoaded((presentation, error) => print('loaded ${presentation.screenId}'))
    .onPresented((presentation, error) => print('shown'))
    .onDismissed((o) => print('dismissed: ${o.purchaseResult}'))
    .build()
    .display(const PLYTransition.modal());

switch (outcome.purchaseResult) {
  case PLYPurchaseResult.cancelled:
    print('User cancelled');
    break;
  case PLYPurchaseResult.purchased:
    print('User purchased ${outcome.plan}');
    break;
  case PLYPurchaseResult.restored:
    print('User restored ${outcome.plan}');
    break;
  case null:
    print('Dismissed without purchase action');
    break;
}
```

## Custom Screens

Register a dedicated Flutter entrypoint immediately after `start()` to provide
the UI for CLIENT steps inside Purchasely-managed native flows:

```dart
await Purchasely.setCustomScreenProvider();

@pragma('vm:entry-point')
void purchaselyCustomScreen(List<String> args) {
  PurchaselyCustomScreens.run(args, (context, presentation) {
    return MaterialApp(
      home: MyCustomStep(
        connections: presentation.connections,
        onNext: () => presentation.execute(),
        onBack: presentation.back,
        onClose: presentation.close,
      ),
    );
  });
}
```

The builder runs in a dedicated isolate and does not inherit app state,
Navigator, inherited themes, service locators, or auto-registered app plugins
from the main isolate. Prefer self-contained steps, presentation `metadata`,
and persistent storage. Custom Screen hosting is flow-step-only; inline
`PLYPresentationView` and standalone native CLIENT presentation hosting are
unsupported.

## Migration to 6.0

This release adapts the plugin to the Purchasely 6.0 native SDKs. Only the
paywall surface has breaking changes; other `Purchasely` APIs remain
source-compatible.

| Old (`Purchasely.*`) | New |
|---|---|
| `Purchasely.start(apiKey: ..., runningMode: PLYRunningMode.full)` | `PurchaselyBuilder.apiKey(...).runningMode(PLYRunningMode.full).start()` |
| `Purchasely.presentPresentationForPlacement(id, isFullscreen: true)` | `PLYPresentationBuilder.placement(id).build().display(const PLYTransition.fullScreen())` |
| `Purchasely.fetchPresentation(...)` | `PLYPresentationBuilder.placement(id).build().preload()` |
| `result.result` (3-value enum), `result.plan` | `outcome.presentation`, `outcome.purchaseResult`, `outcome.plan`, `outcome.closeReason`, `outcome.error` |
| `Purchasely.setPaywallActionInterceptorCallback(...)` + `onProcessAction(bool)` | `Purchasely.interceptAction(PLYPresentationActionKind.purchase, (info, payload) async => PLYInterceptResult.notHandled)` |

See [`MIGRATION-v6.md`](../MIGRATION-v6.md) for the full old→new mapping and
before/after examples.

### Platform limitations in this beta

- **Removed (BREAKING): `presentSubscriptions()`.** The 6.0 native SDKs removed
  the built-in subscriptions list on both Android and iOS, so
  `Purchasely.presentSubscriptions()` no longer exists. Build your own UI with
  `userSubscriptions()` / `userSubscriptionsHistory()`.
- The cancellation survey UI was also removed, so
  `Purchasely.displaySubscriptionCancellationInstruction()` no longer exists.
- iOS v6 currently does not expose `closeReason` or a loaded presentation
  `contentId` on `PLYPresentation`; Flutter reports those fields as `null` on
  iOS instead of inventing values.

## 🏁 Documentation
A complete documentation is available on our website [https://docs.purchasely.com](https://docs.purchasely.com)
