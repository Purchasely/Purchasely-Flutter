![Purchasely](images/icon.png)

# Purchasely Android Player extension

Android video player extension for the Purchasely Flutter SDK. Add it when your
presentations contain videos on Android.

## Installation

Use the exact same version for every Purchasely Flutter package:

```yaml
dependencies:
  purchasely_flutter: 6.0.0
  purchasely_android_player: 6.0.0
```

This package pulls `io.purchasely:player:6.0.1` on Android, published on
Maven Central, so it resolves directly from the public repository.

## Usage

Initialize and display presentations through the main package v6 API:

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .runningMode(PLYRunningMode.full)
    .stores([PLYStore.google])
    .start();

final outcome = await PLYPresentationBuilder.placement('<YOUR_PLACEMENT_ID>')
    .build()
    .display(const PLYTransition.fullScreen());
```

See the repository `MIGRATION-v6.md` and `sdk_public_doc.md` for the complete v6
API mapping.
