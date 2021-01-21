# Purchasely

Purchasely is a solution to ease the integration and boost your In-App Purchase & Subscriptions on the App Store, Google Play Store and Huawei App Gallery.

## Installation

```
dependencies:
  purchasely: ^0.0.1
```

## Usage

```dart
import 'package:purchasely/purchasely.dart';

// ...

Purchasely.startWithAPIKey(
  'afa96c76-1d8e-4e3c-a48f-204a3cd93a15',
  ['Google'],
  null,
  LogLevels.WARNING
);

var data = await Purchasely.presentProductWithIdentifier(
            'PURCHASELY_PLUS', null
          );
print('Result : $data');
```

## 🏁 Documentation
A complete documentation is available on our website [https://docs.purchasely.com](https://docs.purchasely.com)