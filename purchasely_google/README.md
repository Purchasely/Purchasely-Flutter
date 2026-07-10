![Purchasely](images/icon.png)

# Purchasely Google Play extension

Android Google Play Billing extension for the Purchasely Flutter SDK.

## Installation

Use the exact same version for every Purchasely Flutter package:

```yaml
dependencies:
  purchasely_flutter: 6.0.0-rc.3
  purchasely_google: 6.0.0-rc.3
```

This package pulls `io.purchasely:google-play:6.0.0-rc.3` on Android, published on
Maven Central, so it resolves directly from the public repository.

## Usage

Initialize the SDK with the v6 builder and include the Google store:

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

final configured = await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .runningMode(PLYRunningMode.full)
    .stores([PLYStore.google])
    .start();
```

Display presentations with `PLYPresentationBuilder`:

```dart
final outcome = await PLYPresentationBuilder.placement('<YOUR_PLACEMENT_ID>')
    .build()
    .display(const PLYTransition.fullScreen());

if (outcome.purchaseResult == PLYPurchaseResult.purchased) {
  print('User purchased ${outcome.plan}');
}
```

See the repository `MIGRATION-v6.md` and `sdk_public_doc.md` for the complete v6
API mapping.
