![Purchasely](images/icon.png)

# Purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store and Huawei App Gallery.

## Installation

```
dependencies:
  purchasely_flutter: ^1.7.0
```

## Usage

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

// ...

bool configured = await Purchasely.startWithApiKey(
    'YOUR_API_KEY',
    ['Google'],
    null, // your user id
    PLYLogLevel.debug,
    PLYRunningMode.full
  );

var result = await Purchasely.presentProductWithIdentifier('YOU_PRODUCT_ID');
print('Result : $result');
if (result.result == PLYPurchaseResult.cancelled) {
  print("User cancelled purchased");
} else {
  print('User purchased: ${result.plan.name}');
}
```

## 🏁 Documentation
A complete documentation is available on our website [https://docs.purchasely.com](https://docs.purchasely.com)
