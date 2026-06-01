# Purchasely Flutter SDK Documentation

This document provides comprehensive documentation for integrating and using the
Purchasely Flutter SDK with Dart.

> **Upgrading to 6.0?** This release adapts the plugin to the Purchasely 6.0
> native SDKs. The paywall surface (start, display / preload / close, action
> interceptor) moved to a fluent builder API documented here; everything else on
> the `Purchasely` class is unchanged. See
> [`MIGRATION-v6.md`](./MIGRATION-v6.md) for the complete old→new mapping. The
> Purchasely AI plugin and skills (`purchasely-integrate`, `purchasely-review`,
> `purchasely-debug`) can apply the migration for you.

A paywall is referred to as a **Presentation** (or *Screen*) throughout this
guide.

---

## Table of Contents

1. [Requirements](#requirements)
2. [Installation](#installation)
3. [SDK Initialization](#sdk-initialization)
4. [Displaying Presentations](#displaying-presentations)
5. [Processing Transactions](#processing-transactions)
6. [Action Interceptor](#action-interceptor)
7. [User Identification](#user-identification)
8. [Subscription Status & Entitlements](#subscription-status--entitlements)
9. [Custom User Attributes](#custom-user-attributes)
10. [Event Listeners](#event-listeners)
11. [Pre-fetching Screens](#pre-fetching-screens)
12. [Inline Presentations](#inline-presentations)
13. [Deeplinks Management](#deeplinks-management)
14. [Platform-Specific Features](#platform-specific-features)

---

## Requirements

| Requirement | iOS | Android |
|-------------|-----|---------|
| Minimum OS Version | 11.0 | 21 |
| compileSdkVersion | - | 33 |
| targetSdkVersion | - | 33 |

---

## Installation

Add the Purchasely Flutter SDK to your `pubspec.yaml`:

```yaml
dependencies:
  purchasely_flutter: ^6.0.0
```

Then run:

```shell
flutter pub get
```

### Android Dependencies

With Android, you can choose to use Google Play Store and/or Huawei AppGallery
and/or Amazon Appstore. **You must install the corresponding dependency for each
store you want to support.**

#### Google Play Billing (Required for Google Play Store)

If your app is distributed on the **Google Play Store**, you **must** add the
Google Play Billing extension:

```yaml
dependencies:
  purchasely_flutter: ^6.0.0
  purchasely_google: ^6.0.0
```

#### Video Player (Required for Video Paywalls)

If your presentations contain videos, add the Android video player extension:

```yaml
dependencies:
  purchasely_android_player: ^6.0.0
```

> ⚠️ **All Purchasely packages must be at the exact same version.** Mismatched
> versions will cause runtime errors or unexpected behavior.

> **Native dependency.** This release targets the Purchasely 6.0 native SDKs
> (iOS `Purchasely 6.0.0`, Android `io.purchasely:core 6.0.0`). These versions
> may not be published on CocoaPods / Maven Central yet; local builds resolve
> them via `mavenLocal()` (Android) and a development pod (iOS).

### API Key

You can find your API Key in the Purchasely Console under **App settings >
Backend & SDK configuration**.

---

## SDK Initialization

> **6.0 — paywall API moved to the builder.** Initialization, presentation
> display and action interception use the fluent builder API below. The previous
> paywall methods (`Purchasely.start(...)`,
> `presentPresentationForPlacement`, `fetchPresentation`,
> `setPaywallActionInterceptorCallback`, `onProcessAction`,
> `setDefaultPresentationResultHandler`, …) have been replaced. See
> [`MIGRATION-v6.md`](./MIGRATION-v6.md) for the complete old→new mapping. All
> other `Purchasely.*` methods (user, products, subscriptions, attributes,
> events) are unchanged.

Initialize the Purchasely SDK as early as possible in your application lifecycle
using `PurchaselyBuilder.apiKey(...)`. Only the API key is required; every other
option has a sensible default.

### Full Mode (Recommended)

In `RunningMode.full`, Purchasely handles the entire purchase flow including
transactions and receipts.

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

try {
  final bool configured = await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
      .runningMode(RunningMode.full)               // RunningMode.observer (default) | full
      .logLevel(LogLevel.error)                    // LogLevel.debug in development
      .appUserId(null)                             // set your user id here if you know it
      .stores([PLYStore.google])                   // Android: google | huawei | amazon
      .storekitVersion(StorekitVersion.storeKit2)  // iOS: storeKit2 (recommended) | storeKit1
      .start();

  if (configured) {
    print('Purchasely SDK configured successfully');
  }
} catch (e) {
  print('Purchasely SDK not configured properly: $e');
}
```

### Observer (PaywallObserver) Mode

Use `RunningMode.observer` if you have an existing in-app purchase infrastructure
and want to use Purchasely only for presentation display and analytics. **This is
the default in 6.0.**

```dart
try {
  final bool configured = await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
      .runningMode(RunningMode.observer)
      .logLevel(LogLevel.error)
      .stores([PLYStore.google])
      .start();
} catch (e) {
  print('Purchasely SDK not configured properly');
}
```

> **Default running mode changed.** With the 6.0 native SDK the default
> `RunningMode` is `RunningMode.observer`. Pass `.runningMode(RunningMode.full)`
> to let Purchasely own the purchase flow.

---

## Displaying Presentations

Purchasely presentations are displayed using **placements**. A placement is a
specific location in your app where you want to display a presentation (e.g.
onboarding, settings, premium feature).

### Display a Placement

`PresentationBuilder.placement(id).build()` returns a `PresentationRequest`.
Calling `display([Transition])` shows the presentation and resolves at
**dismiss** with a `PresentationOutcome`.

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

try {
  final outcome = await PresentationBuilder.placement('ONBOARDING')
      .contentId('my_content_id') // optional: associate content with the purchase
      .build()
      .display(const Transition.fullScreen());

  // outcome: presentation, purchaseResult, plan, closeReason, error
  if (outcome.error != null) {
    print('Display error: ${outcome.error!.message}');
  } else if (outcome.purchaseResult == PurchaseResult.purchased ||
      outcome.purchaseResult == PurchaseResult.restored) {
    print('User purchased ${outcome.plan}');
    // Update entitlements to unlock content
  } else {
    print('User dismissed: ${outcome.closeReason}');
  }
} catch (e) {
  print(e);
}
```

You can also target a specific screen or product:

```dart
// A specific presentation by screen id
await PresentationBuilder.screen('SCREEN_ID').build().display(const Transition.modal());

// A specific product (content) inside a screen
await PresentationBuilder.screen('SCREEN_ID').contentId('CONTENT_ID').build().display();
```

### Transitions

`display([Transition])` accepts an optional `Transition`:

```dart
const Transition.fullScreen();          // full-screen
const Transition.modal();               // modal sheet
const Transition.modal(dismissible: false);
const Transition.push();                // pushed onto the navigation stack
```

`TransitionType` also exposes `drawer`, `popin` and `inlinePaywall` for advanced
layouts (with `heightPercentage` and `backgroundColors`).

### Display Results

`display([Transition])` resolves with a `PresentationOutcome`:

| Field | Type | Description |
|-------|------|-------------|
| `presentation` | `Presentation?` | The displayed presentation (or `null` if it never reached display) |
| `purchaseResult` | `PurchaseResult?` | `purchased` \| `restored` \| `cancelled` \| `null` |
| `plan` | `Map<String, dynamic>?` | The purchased plan (when `purchaseResult` is `purchased` / `restored`) |
| `closeReason` | `CloseReason?` | `button` \| `backSystem` \| `programmatic` (when no purchase) |
| `error` | `PresentationError?` | Display error; mutually exclusive with `closeReason` |

---

## Processing Transactions

### Full Mode

In `RunningMode.full`, the Purchasely SDK automatically launches the native
in-app purchase flow when a user taps a purchase button and handles the
transaction. You only need to update entitlements once you have confirmation the
purchase was processed.

```dart
try {
  final outcome = await PresentationBuilder.placement('onboarding')
      .build()
      .display();

  if (outcome.purchaseResult == PurchaseResult.purchased ||
      outcome.purchaseResult == PurchaseResult.restored) {
    print('User purchased ${outcome.plan}');
    // Update entitlements to unlock the access to the contents
  }
} catch (e) {
  print(e);
}
```

You can also trigger a purchase programmatically (unchanged):

```dart
final plan = await Purchasely.purchaseWithPlanVendorId(
  vendorId: 'PURCHASELY_PLUS_MONTHLY',
);
```

### Observer Mode with Action Interceptor

In `RunningMode.observer`, you handle purchases with your own infrastructure
while using Purchasely for presentation display. Register an interceptor for the
`purchase` action; the handler returns an `InterceptResult` (there is no more
`onProcessAction`).

```dart
import 'package:flutter/foundation.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

await Purchasely.interceptAction(
  PresentationActionKind.purchase,
  (info, payload) async {
    if (payload is! PurchasePayload) {
      return InterceptResult.notHandled;
    }
    try {
      // The store product id (sku) the user tapped on in the presentation
      final storeProductId = payload.plan['productId'];

      if (defaultTargetPlatform == TargetPlatform.android) {
        // Only for Android you can retrieve the subscription offer details
        final basePlanId = payload.subscriptionOffer?['basePlanId'];
        final offerId = payload.subscriptionOffer?['offerId'];
        final offerToken = payload.subscriptionOffer?['offerToken'];
      }

      final success = await MyPurchaseSystem.purchase(storeProductId);
      if (success) {
        Purchasely.synchronize(); // Synchronize all purchases with Purchasely
        return InterceptResult.success;
      }
      return InterceptResult.failed;
    } catch (e) {
      print(e);
      return InterceptResult.failed;
    }
  },
);

await Purchasely.interceptAction(
  PresentationActionKind.restore,
  (info, payload) async {
    try {
      await MyPurchaseSystem.restorePurchases();
      Purchasely.synchronize();
      return InterceptResult.success;
    } catch (e) {
      return InterceptResult.failed;
    }
  },
);
```

---

## Action Interceptor

The action interceptor lets you intercept and handle user actions on the
presentation. Register **one handler per action kind** with
`Purchasely.interceptAction(kind, handler)`. The
handler returns an `InterceptResult` that tells the SDK how the action was
handled:

- `InterceptResult.success` — you handled the action successfully
- `InterceptResult.failed` — you tried to handle it but it failed
- `InterceptResult.notHandled` — let the SDK perform its default behaviour

### Available Action Kinds

| Kind (`PresentationActionKind`) | Payload | Description |
|---------------------------------|---------|-------------|
| `purchase` | `PurchasePayload` | User tapped a purchase button |
| `restore` | — | User tapped the restore button |
| `login` | — | User tapped the login button |
| `close` / `closeAll` | `ClosePayload` / `CloseAllPayload` | User tapped the close button |
| `navigate` | `NavigatePayload` | User wants to navigate to an external URL |
| `openPresentation` | `OpenPresentationPayload` | User wants to open another presentation |
| `openPlacement` | `OpenPlacementPayload` | User wants to open another placement |
| `promoCode` | — | User wants to enter a promo code |
| `webCheckout` | `WebCheckoutPayload` | User wants to start a web checkout |

### Implementation

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

await Purchasely.interceptAction(
  PresentationActionKind.navigate,
  (info, payload) async {
    if (payload is NavigatePayload) {
      print('User wants to navigate to ${payload.url}');
      // open payload.url with your router / url_launcher
      return InterceptResult.success;
    }
    return InterceptResult.notHandled;
  },
);

await Purchasely.interceptAction(
  PresentationActionKind.login,
  (info, payload) async {
    print('User wants to login');
    // Present your own screen for the user to log in
    Purchasely.userLogin('MY_USER_ID');
    return InterceptResult.success;
  },
);
```

### Removing interceptors

```dart
await Purchasely.removeInterceptor(PresentationActionKind.navigate);
await Purchasely.removeAllInterceptors();
```

---

## User Identification

### Anonymous Users

The Purchasely SDK automatically generates and assigns an `anonymous_user_id` to
each user, maintaining consistency as long as the app remains installed on the
device.

```dart
final anonymousId = await Purchasely.anonymousUserId;
print('Anonymous User ID: $anonymousId');
```

### User Login

To authenticate users and associate purchases with their account:

```dart
final refresh = await Purchasely.userLogin('123456789');
if (refresh) {
  // You should call your backend to refresh user entitlements
  print('User logged in, refresh entitlements');
}
```

### User Logout

```dart
Purchasely.userLogout();
```

### Login from Presentation

To handle the login button on the presentation, intercept the `login` action:

```dart
await Purchasely.interceptAction(
  PresentationActionKind.login,
  (info, payload) async {
    // Present your own screen for the user to log in
    Purchasely.userLogin('MY_USER_ID');
    return InterceptResult.success;
  },
);
```

---

## Subscription Status & Entitlements

### Retrieve User Subscriptions

Purchasely offers a way to retrieve active subscriptions directly from your
mobile app:

```dart
try {
  final subscriptions = await Purchasely.userSubscriptions();
  if (subscriptions.isNotEmpty) {
    print(subscriptions.first.plan);
    print(subscriptions.first.subscriptionSource);
    print(subscriptions.first.nextRenewalDate);
    print(subscriptions.first.cancelledDate);
  }
} catch (e) {
  print(e);
}
```

Expired subscriptions are available via `Purchasely.userSubscriptionsHistory()`.

> **Note**: There is a **few seconds delay** for `Purchasely.userSubscriptions()`
> to be updated after a purchase or restoration. If you rely on this method right
> after a purchase, **wait for 3 seconds** before calling it.

---

## Custom User Attributes

Custom User Attributes allow you to segment users and personalize their journey.

### Supported Types

`String`, `int`, `double`, `bool`, `DateTime`, and arrays of those types.

### Setting Attributes

```dart
Purchasely.setUserAttributeWithString('gender', 'man');
Purchasely.setUserAttributeWithInt('age', 21);
Purchasely.setUserAttributeWithDouble('weight', 78.2);
Purchasely.setUserAttributeWithBoolean('premium', true);
Purchasely.setUserAttributeWithDate('subscription_date', DateTime.now());
Purchasely.setUserAttributeWithStringArray('tags', ['sport', 'news']);
```

### Retrieving Attributes

```dart
final attributes = await Purchasely.userAttributes();
print(attributes); // Map of key -> value

final dateAttribute = await Purchasely.userAttribute('subscription_date');
// DateTime values are parsed automatically when possible
```

### Incrementing / Decrementing Counters

```dart
Purchasely.incrementUserAttribute('viewed_articles');
Purchasely.incrementUserAttribute('viewed_articles', value: 3);
Purchasely.decrementUserAttribute('viewed_articles');
Purchasely.decrementUserAttribute('viewed_articles', value: 7);
```

### Clearing Attributes

```dart
Purchasely.clearUserAttribute('size');
Purchasely.clearUserAttributes();
```

> **Note**: `Purchasely.userLogout()` clears all custom user attributes.

---

## Event Listeners

### UI / SDK Events Listener

When users interact with Purchasely Screens, the SDK triggers events. Implement
an event listener to forward these events to analytics platforms.

```dart
Purchasely.listenToEvents((event) {
  print('Event received: ${event.name}');
  print('Event properties: ${event.properties.event_name}');
  // Forward to your analytics platform
});

// Stop listening when no longer needed:
Purchasely.stopListeningToEvents();
```

### Custom User Attributes Listener

When a user submits answers to a survey, custom user attributes can be set
automatically by the SDK:

```dart
class MyUserAttributeListener implements UserAttributeListener {
  @override
  void onUserAttributeSet(String key, PLYUserAttributeType type, dynamic value,
      PLYUserAttributeSource source) {
    if (source == PLYUserAttributeSource.purchasely) {
      // Process attribute set by Purchasely (e.g., from surveys)
    }
  }

  @override
  void onUserAttributeRemoved(String key, PLYUserAttributeSource source) {}
}

Purchasely.setUserAttributeListener(MyUserAttributeListener());
```

---

## Pre-fetching Screens

Pre-fetch presentations from the network before displaying them for a better
user experience.

### Benefits

- Display the Screen only after it has been loaded
- Handle network errors gracefully
- Show a custom loading screen
- Pre-load during app navigation

### Implementation

Build a `PresentationRequest`, `preload()` it to fetch the screen from the
network, then `display()` the **same** request when you are ready.

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

try {
  final request = PresentationBuilder.placement('ONBOARDING').build();

  // Preload resolves once the screen is loaded
  final presentation = await request.preload();

  if (presentation.type == PresentationType.deactivated) {
    // No paywall to display for this placement
    return;
  }
  if (presentation.type == PresentationType.client) {
    // Display your own paywall (BYOS) — plan summaries are in presentation.plans
    return;
  }

  // Display the preloaded presentation; resolves at dismiss
  final outcome = await request.display(const Transition.fullScreen());

  if (outcome.purchaseResult == PurchaseResult.purchased ||
      outcome.purchaseResult == PurchaseResult.restored) {
    print('User purchased ${outcome.plan}');
  } else {
    print('Dismissed: ${outcome.closeReason}');
  }
} catch (e) {
  print(e);
}
```

### Presentation Types

| Type (`PresentationType`) | Description |
|---------------------------|-------------|
| `normal` | Default Purchasely paywall |
| `fallback` | Fallback paywall (requested one not found) |
| `deactivated` | No paywall for this placement |
| `client` | Your own paywall (BYOS) |

---

## Inline Presentations

To render a presentation inline (embedded) inside your widget tree — as opposed
to full-screen / modal — use the `PLYPresentationView` widget with a
`PresentationRequest`. The widget preloads the request and hands the resulting
presentation to the native inline view.

```dart
import 'package:purchasely_flutter/native_view_widget.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

final request = PresentationBuilder.placement('onboarding')
    .onDismissed((outcome) => print('inline dismissed: ${outcome.purchaseResult}'))
    .build();

// In your build():
Expanded(
  child: PLYPresentationView(
    request: request,
    loadingBuilder: const Center(child: CircularProgressIndicator()),
    errorBuilder: (context, error) => Text('Error: ${error.message}'),
  ),
);
```

---

## Deeplinks Management

To enable Purchasely to display screens via deeplinks, you need to:

1. Allow the SDK to open deeplinks
2. Set a default presentation handler to receive the result
3. (Optional) check whether a deeplink is handled by Purchasely

### Allowing the Display

Deeplink display is allowed via the start builder:

```dart
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .allowDeeplink(true)
    .start();
```

`Purchasely.readyToOpenDeeplink(bool)` still exists if you need to toggle this at
runtime.

### Setting the Default Presentation Handler

Retrieve the result of user actions on presentations opened via deeplinks by
attaching `onDismissed` to a default-source request:

```dart
PresentationBuilder.defaultSource()
    .onDismissed((outcome) {
      print('Presentation dismissed: ${outcome.purchaseResult}');
      if (outcome.plan != null) {
        print('Plan: ${outcome.plan}');
      }
    })
    .build()
    .display();
```

### Checking a Deeplink

```dart
final handled = await Purchasely.isDeeplinkHandled('app://ply/presentations/');
print('Deeplink handled by Purchasely? $handled');
```

---

## Platform-Specific Features

### StoreKit Selection (iOS)

Choose between StoreKit 1 and StoreKit 2 for iOS:

```dart
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .storekitVersion(StorekitVersion.storeKit2) // or StorekitVersion.storeKit1
    .start();
```

> **Recommendation**: Use StoreKit 2 (`StorekitVersion.storeKit2`) for new
> integrations.

### Android Stores

Purchasely supports multiple Android stores:

```dart
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .stores([PLYStore.google]) // PLYStore.google | PLYStore.huawei | PLYStore.amazon
    .start();
```

To use multiple stores:

```dart
.stores([PLYStore.google, PLYStore.huawei])
```

> **Note**: Install the corresponding dependencies for each store you want to
> support.

### Android-Specific Purchase Parameters

When intercepting purchases on Android, you can access additional parameters from
the typed `PurchasePayload`:

```dart
await Purchasely.interceptAction(
  PresentationActionKind.purchase,
  (info, payload) async {
    if (payload is PurchasePayload &&
        defaultTargetPlatform == TargetPlatform.android) {
      final basePlanId = payload.subscriptionOffer?['basePlanId'];
      final offerId = payload.subscriptionOffer?['offerId'];
      final offerToken = payload.subscriptionOffer?['offerToken'];
    }
    return InterceptResult.notHandled;
  },
);
```

### Native Subscriptions Screen

> **`presentSubscriptions` is a no-op on Android in 6.0.** The native
> subscriptions screen was removed from the Android SDK, so
> `Purchasely.presentSubscriptions()` does nothing on Android. It still works on
> iOS. Build your own subscriptions screen with `userSubscriptions()` if you need
> cross-platform parity.

---

## Troubleshooting

1. **SDK not configured**: Ensure you call
   `PurchaselyBuilder.apiKey('…')...start()` before any other SDK method.

2. **Purchases not working**: Verify that you've added the correct store
   dependencies and they're all at the same version.

3. **Presentation not displaying**: Check that:
   - The placement exists in your Purchasely Console
   - The SDK is properly initialized
   - You have an active internet connection

4. **StoreKit issues on iOS**: Ensure your iOS deployment target is at least 11.0.

### Debug Mode

Enable debug logging during development:

```dart
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .logLevel(LogLevel.debug) // Use LogLevel.error in production
    .start();
```

---

## Additional Resources

- [Purchasely Console](https://console.purchasely.io)
- [pub.dev Package](https://pub.dev/packages/purchasely_flutter)
- [Purchasely Documentation](https://docs.purchasely.com)
