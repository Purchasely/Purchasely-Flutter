![Purchasely](images/icon.png)

# Purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store and Huawei App Gallery.

## Installation

```
dependencies:
  purchasely_flutter: ^5.0.0-rc01
```

## Usage

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

// ...

bool configured = await Purchasely.start(
    apiKey: '<YOUR_API_KEY>',
    androidStores: ['Google, Huawei, Amazon'],
    storeKit1: false,
    logLevel: PLYLogLevel.error,
    runningMode: PLYRunningMode.full,
    userId: null,
);

var result = await Purchasely.presentPresentationForPlacement("<YOUR_PLACEMENT_ID>", isFullscreen: true);

switch (result.result) {
  case PLYPurchaseResult.cancelled:
  {
    print("User cancelled purchased");
  }
  break;
  case PLYPurchaseResult.purchased:
  {
    print("User purchased ${result.plan?.name}");
  }
  break;
  case PLYPurchaseResult.restored:
  {
    print("User restored ${result.plan?.name}");
  }
  break;
}
```

## 🏁 Documentation
A complete documentation is available on our website [https://docs.purchasely.com](https://docs.purchasely.com)