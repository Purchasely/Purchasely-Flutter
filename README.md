![Purchasely](images/icon.png)

# Purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store and Huawei App Gallery.

> **Upgrading to 6.0?** The paywall surface (start, display/preload/close, action
> interceptor) moved to a fluent builder API; everything else on the `Purchasely`
> class is unchanged. See [`MIGRATION-v6.md`](./MIGRATION-v6.md) for the complete
> old→new mapping.

## Installation

```yaml
dependencies:
  purchasely_flutter: ^6.0.0
```

## Usage

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

// 1. Start the SDK.
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .runningMode(RunningMode.full)
    .logLevel(LogLevel.error)
    .stores([PLYStore.google])
    .start();

// 2. Build a presentation request and display it.
//    `.display(...)` resolves at *dismiss* time with the 5-field
//    `PresentationOutcome` (presentation, purchaseResult, plan, closeReason, error).
final outcome = await PresentationBuilder.placement('<YOUR_PLACEMENT_ID>')
    .build()
    .display(const Transition.fullScreen());

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
    print('Dismissed without a purchase action');
    break;
}
```

## 🏁 Documentation
A complete documentation is available on our website [https://docs.purchasely.com](https://docs.purchasely.com)