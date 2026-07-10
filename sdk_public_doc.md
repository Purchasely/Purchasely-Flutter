# Purchasely Flutter SDK Documentation

This document provides comprehensive documentation for integrating and using the
Purchasely Flutter SDK with Dart.

> **Upgrading to 6.0?** This release adapts the plugin to the Purchasely 6.0
> native SDKs. The paywall surface (start, display / preload / close, action
> interceptor) moved to a fluent builder API documented here; other `Purchasely`
> APIs remain source-compatible except for removed v5 deeplink aliases. See
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
| Minimum OS Version | 13.4 | 23 |
| compileSdkVersion | - | 35 |
| targetSdkVersion | - | 35 |

---

## Installation

Add the Purchasely Flutter SDK to your `pubspec.yaml`:

```yaml
dependencies:
  purchasely_flutter: 6.0.0-rc.3
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
  purchasely_flutter: 6.0.0-rc.3
  purchasely_google: 6.0.0-rc.3
```

#### Video Player (Required for Video Paywalls)

If your presentations contain videos, add the Android video player extension:

```yaml
dependencies:
  purchasely_android_player: 6.0.0-rc.3
```

> ⚠️ **All Purchasely packages must be at the exact same version.** Mismatched
> versions will cause runtime errors or unexpected behavior.

> **Native dependency.** This release targets the Purchasely 6.0 native SDKs,
> pinned to `6.0.0-rc.3` (iOS `Purchasely`, Android `io.purchasely:core`). Both
> pre-releases are published — Android on Maven Central, iOS on the CocoaPods
> trunk — so the project builds from the public repositories.

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
> events) remain source-compatible.

Initialize the Purchasely SDK as early as possible in your application lifecycle
using `PurchaselyBuilder.apiKey(...)`. Only the API key is required; every other
option has a sensible default.

### Full Mode (Recommended)

In `PLYRunningMode.full`, Purchasely handles the entire purchase flow including
transactions and receipts.

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

try {
  final bool configured = await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
      .runningMode(PLYRunningMode.full)               // PLYRunningMode.observer (default) | full
      .logLevel(PLYLogLevel.error)                    // PLYLogLevel.debug in development
      .appUserId(null)                             // set your user id here if you know it
      .stores([PLYStore.google])                   // Android: google | huawei | amazon
      .allowCampaigns(true)                        // optional campaign display gate
      .storekitVersion(PLYStorekitVersion.storeKit2) // iOS: storeKit2 (recommended) | storeKit1
      .start();

  if (configured) {
    print('Purchasely SDK configured successfully');
  }
} catch (e) {
  print('Purchasely SDK not configured properly: $e');
}
```

### Observer (PaywallObserver) Mode

Use `PLYRunningMode.observer` if you have an existing in-app purchase infrastructure
and want to use Purchasely only for presentation display and analytics. **This is
the default in 6.0.**

```dart
try {
  final bool configured = await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
      .runningMode(PLYRunningMode.observer)
      .logLevel(PLYLogLevel.error)
      .stores([PLYStore.google])
      .start();
} catch (e) {
  print('Purchasely SDK not configured properly');
}
```

> **Default running mode changed.** With the 6.0 native SDK the default
> `PLYRunningMode` is `PLYRunningMode.observer`. Pass `.runningMode(PLYRunningMode.full)`
> to let Purchasely own the purchase flow.

---

## Displaying Presentations

Purchasely presentations are displayed using **placements**. A placement is a
specific location in your app where you want to display a presentation (e.g.
onboarding, settings, premium feature).

### Display a Placement

`PLYPresentationBuilder.placement(id).build()` returns a `PLYPresentationRequest`.
Calling `display([PLYTransition])` shows the presentation and resolves at
**dismiss** with a `PLYPresentationOutcome`.

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

try {
  final outcome = await PLYPresentationBuilder.placement('ONBOARDING')
      .contentId('my_content_id') // optional: associate content with the purchase
      .build()
      .display(const PLYTransition.fullScreen());

  // outcome: presentation, purchaseResult, plan, closeReason, error
  if (outcome.error != null) {
    print('Display error: ${outcome.error!.message}');
  } else if (outcome.purchaseResult == PLYPurchaseResult.purchased ||
      outcome.purchaseResult == PLYPurchaseResult.restored) {
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
await PLYPresentationBuilder.screen('SCREEN_ID').build().display(const PLYTransition.modal());

// A specific product (content) inside a screen
await PLYPresentationBuilder.screen('SCREEN_ID').contentId('CONTENT_ID').build().display();
```

### Transitions

`display([PLYTransition])` accepts an optional `PLYTransition`:

```dart
const PLYTransition.fullScreen();          // full-screen
const PLYTransition.modal();               // modal sheet
const PLYTransition.modal(dismissible: false);
const PLYTransition.push();                // pushed onto the navigation stack
```

`PLYTransitionType` also exposes `drawer`, `popin` and `inlinePaywall` for
advanced layouts. Drawer and popin sizes use `PLYTransitionDimension`:

```dart
const PLYTransition.drawer(
  height: PLYTransitionDimension.percentage(0.6),
);
```

### Display Results

`display([PLYTransition])` resolves with a `PLYPresentationOutcome`:

| Field | Type | Description |
|-------|------|-------------|
| `presentation` | `Presentation?` | The displayed presentation (or `null` if it never reached display) |
| `purchaseResult` | `PLYPurchaseResult?` | `purchased` \| `restored` \| `cancelled` \| `null` |
| `plan` | `Map<String, dynamic>?` | The purchased plan (when `purchaseResult` is `purchased` / `restored`) |
| `closeReason` | `CloseReason?` | `button` \| `backSystem` \| `programmatic` (when no purchase) |
| `error` | `PresentationError?` | Display error; mutually exclusive with `closeReason` |

---

## Processing Transactions

### Full Mode

In `PLYRunningMode.full`, the Purchasely SDK automatically launches the native
in-app purchase flow when a user taps a purchase button and handles the
transaction. You only need to update entitlements once you have confirmation the
purchase was processed.

```dart
try {
  final outcome = await PLYPresentationBuilder.placement('onboarding')
      .build()
      .display();

  if (outcome.purchaseResult == PLYPurchaseResult.purchased ||
      outcome.purchaseResult == PLYPurchaseResult.restored) {
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

In `PLYRunningMode.observer`, you handle purchases with your own infrastructure
while using Purchasely for presentation display. Register an interceptor for the
`purchase` action; the handler returns an `PLYInterceptResult` (there is no more
`onProcessAction`).

```dart
import 'package:flutter/foundation.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

await Purchasely.interceptAction(
  PLYPresentationActionKind.purchase,
  (info, payload) async {
    if (payload is! PurchasePayload) {
      return PLYInterceptResult.notHandled;
    }
    try {
      // The store product id (sku) the user tapped on in the presentation
      final storeProductId = payload.plan.productId;

      if (defaultTargetPlatform == TargetPlatform.android) {
        // Only for Android you can retrieve the subscription offer details
        final basePlanId = payload.subscriptionOffer?.basePlanId;
        final offerId = payload.subscriptionOffer?.offerId;
        final offerToken = payload.subscriptionOffer?.offerToken;
      }

      final success = await MyPurchaseSystem.purchase(storeProductId);
      if (success) {
        Purchasely.synchronize(); // Synchronize all purchases with Purchasely
        return PLYInterceptResult.success;
      }
      return PLYInterceptResult.failed;
    } catch (e) {
      print(e);
      return PLYInterceptResult.failed;
    }
  },
);

await Purchasely.interceptAction(
  PLYPresentationActionKind.restore,
  (info, payload) async {
    try {
      await MyPurchaseSystem.restorePurchases();
      Purchasely.synchronize();
      return PLYInterceptResult.success;
    } catch (e) {
      return PLYInterceptResult.failed;
    }
  },
);
```

---

## Action Interceptor

The action interceptor lets you intercept and handle user actions on the
presentation. Register **one handler per action kind** with
`Purchasely.interceptAction(kind, handler)`. The
handler returns an `PLYInterceptResult` that tells the SDK how the action was
handled:

- `PLYInterceptResult.success` — you handled the action successfully
- `PLYInterceptResult.failed` — you tried to handle it but it failed
- `PLYInterceptResult.notHandled` — let the SDK perform its default behaviour

### Available Action Kinds

| Kind (`PLYPresentationActionKind`) | Payload | Description |
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
  PLYPresentationActionKind.navigate,
  (info, payload) async {
    if (payload is NavigatePayload) {
      print('User wants to navigate to ${payload.url}');
      // open payload.url with your router / url_launcher
      return PLYInterceptResult.success;
    }
    return PLYInterceptResult.notHandled;
  },
);

await Purchasely.interceptAction(
  PLYPresentationActionKind.login,
  (info, payload) async {
    print('User wants to login');
    // Present your own screen for the user to log in
    Purchasely.userLogin('MY_USER_ID');
    return PLYInterceptResult.success;
  },
);
```

### Removing interceptors

```dart
await Purchasely.removeInterceptor(PLYPresentationActionKind.navigate);
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
  PLYPresentationActionKind.login,
  (info, payload) async {
    // Present your own screen for the user to log in
    Purchasely.userLogin('MY_USER_ID');
    return PLYInterceptResult.success;
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

Build a `PLYPresentationRequest`, `preload()` it to fetch the screen from the
network, then `display()` the **same** request when you are ready.

```dart
import 'package:purchasely_flutter/purchasely_flutter.dart';

try {
  final request = PLYPresentationBuilder.placement('ONBOARDING').build();

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
  final outcome = await request.display(const PLYTransition.fullScreen());

  if (outcome.purchaseResult == PLYPurchaseResult.purchased ||
      outcome.purchaseResult == PLYPurchaseResult.restored) {
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
`PLYPresentationRequest`. The widget preloads the request and hands the resulting
presentation to the native inline view.

```dart
import 'package:purchasely_flutter/native_view_widget.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

final request = PLYPresentationBuilder.placement('onboarding')
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

`Purchasely.allowDeeplink(bool)` can also toggle this at runtime. The v5
deeplink aliases were removed.

### Cold-Start Deeplink

When your app is launched **from** a deeplink, pass the captured URL to the start
builder. The SDK replays it automatically once configured — no separate
`Purchasely.handleDeeplink(...)` call is needed:

```dart
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .allowDeeplink(true)
    .handleDeeplink(launchDeeplink) // null when not launched from a deeplink
    .start();
```

`handleDeeplink(null)` (or omitting the modifier) is a no-op. Non-Purchasely URLs
are ignored by the native SDK. This mirrors the native
`PurchaselyBuilder.handleDeeplink(_:)` (iOS) and
`Purchasely.Builder.handleDeeplink(uri)` (Android).

### Setting the Default Presentation Handler

Retrieve the result of user actions on presentations opened via deeplinks by
attaching `onDismissed` to a default-source request:

```dart
PLYPresentationBuilder.defaultSource()
    .onDismissed((outcome) {
      print('Presentation dismissed: ${outcome.purchaseResult}');
      if (outcome.plan != null) {
        print('Plan: ${outcome.plan}');
      }
    })
    .build()
    .display();
```

Alternatively, register a single app-wide handler with
`Purchasely.setDefaultPresentationDismissHandler((outcome) { … })`.

> **Where the outcome is delivered.** A dismissed presentation produces one
> `PLYPresentationOutcome`, delivered to the **per-presentation `onDismissed` if
> one is set, otherwise to the global default handler**. The deciding factor is
> the presence of `onDismissed` — awaiting `display()` returns the outcome too
> but does not by itself silence the global handler. Pick one channel per
> presentation: await it, set `onDismissed`, or leave both off and let the global
> handler catch it. The global handler is also what receives presentations the
> SDK opens itself (deeplinks, campaigns, promoted in-app purchases).

### Checking a Deeplink

```dart
final handled = await Purchasely.handleDeeplink('app://ply/presentations/');
print('Deeplink handled by Purchasely? $handled');
```

---

## Platform-Specific Features

### StoreKit Selection (iOS)

Choose between StoreKit 1 and StoreKit 2 for iOS:

```dart
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .storekitVersion(PLYStorekitVersion.storeKit2) // or PLYStorekitVersion.storeKit1
    .start();
```

> **Recommendation**: Use StoreKit 2 (`PLYStorekitVersion.storeKit2`) for new
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
  PLYPresentationActionKind.purchase,
  (info, payload) async {
    if (payload is PurchasePayload &&
        defaultTargetPlatform == TargetPlatform.android) {
      final basePlanId = payload.subscriptionOffer?.basePlanId;
      final offerId = payload.subscriptionOffer?.offerId;
      final offerToken = payload.subscriptionOffer?.offerToken;
    }
    return PLYInterceptResult.notHandled;
  },
);
```

### Native Subscriptions Screen

> **Removed (BREAKING): `presentSubscriptions()`.** The native subscriptions
> screen was removed from the 6.0 SDKs on both platforms, so
> `Purchasely.presentSubscriptions()` has been **removed** from the SDK — the
> method no longer exists. Build your own UI with `userSubscriptions()` /
> `userSubscriptionsHistory()`. The cancellation survey UI was also removed, so
> `Purchasely.displaySubscriptionCancellationInstruction()` has been removed on
> both platforms.

### iOS Presentation Fields

The native iOS 6.0 SDK does not currently expose `closeReason` on
`PLYPresentationOutcome`, nor a loaded presentation `contentId` on
`PLYPresentation`. Flutter therefore reports `outcome.closeReason` and
`presentation.contentId` as `null` on iOS rather than synthesising values. Android
6.0 does expose both fields.

### Plan Offer Fields

Android 6.0 renamed introductory-price helpers to offer-price helpers. Flutter
exposes the v6 names on `PLYPlan` (`hasOfferPrice`, `offerPrice`, `offerAmount`,
`offerDuration`, `offerPeriod`) and keeps the old `intro*` fields populated as
deprecated compatibility aliases.

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

4. **StoreKit issues on iOS**: Ensure your iOS deployment target is at least 13.4.

### Debug Mode

Enable debug logging during development:

```dart
await PurchaselyBuilder.apiKey('<YOUR_API_KEY>')
    .logLevel(PLYLogLevel.debug) // Use PLYLogLevel.error in production
    .start();
```

---

## Additional Resources

- [Purchasely Console](https://console.purchasely.io)
- [pub.dev Package](https://pub.dev/packages/purchasely_flutter)
- [Purchasely Documentation](https://docs.purchasely.com)
