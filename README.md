![Purchasely](images/icon.png)

# Purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store and Huawei App Gallery.

## Installation

```
dependencies:
  purchasely_flutter: ^6.0.0-beta.0
```

> **Migrating from 5.x?** Initialization, Presentation display and the action
> interceptor are now v6-only. See the
> [migration guide](purchasely/MIGRATION.md).

## Usage

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

// 1. Start the SDK (fluent builder, `start()` resolves once configured).
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .runningMode(V6RunningMode.observer)
    .logLevel(V6LogLevel.error)
    .stores([PLYStore.google])
    .start();

// 2. Build a Presentation request and display it. `.display(...)` resolves at
//    dismiss time with the 5-field `PresentationOutcome`.
final outcome = await PresentationBuilder
    .placement('<YOUR_PLACEMENT_ID>')
    .build()
    .display(const Transition.fullScreen());

switch (outcome.purchaseResult) {
  case PurchaseResult.cancelled:
    print("User cancelled");
    break;
  case PurchaseResult.purchased:
    print("User purchased ${outcome.plan}");
    break;
  case PurchaseResult.restored:
    print("User restored ${outcome.plan}");
    break;
  case null:
    print("Dismissed without purchase action");
    break;
}
```

## 🏁 Documentation
A complete documentation is available on our website [https://docs.purchasely.com](https://docs.purchasely.com)