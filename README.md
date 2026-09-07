![Purchasely](images/icon.png)

# Purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store and Huawei App Gallery.

> **Upgrading to 6.0?** The paywall surface (start, display/preload/close, action
> interceptor) moved to a fluent builder API; other `Purchasely` APIs remain
> source-compatible (deeplinks use v6 names). See
> [`MIGRATION-v6.md`](./MIGRATION-v6.md) for the complete old→new mapping.

## Installation

```yaml
dependencies:
  purchasely_flutter: 6.1.0
```

## Usage

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

// 1. Start the SDK.
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .runningMode(PLYRunningMode.full)
    .logLevel(PLYLogLevel.error)
    .stores([PLYStore.google])
    .start();

// Runtime deeplink toggle (v6 name):
await Purchasely.allowDeeplink(true);

// 2. Build a presentation request and display it.
//    `.display(...)` resolves at *dismiss* time with the 5-field
//    `PLYPresentationOutcome` (presentation, purchaseResult, plan, closeReason, error).
final outcome = await PLYPresentationBuilder.placement('<YOUR_PLACEMENT_ID>')
    .build()
    .display(const PLYTransition.fullScreen());

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
    print('Dismissed without a purchase action');
    break;
}
```

## 🏁 Documentation
A complete documentation is available on our website [https://docs.purchasely.com](https://docs.purchasely.com)
