## 1.7.2
### Enhancements on Android
- Update Exoplayer dependency to 2.19.0 in player module
- Update player module to compile with SDK 33
- Use countdown tag for any labels in your paywalls
### Enhancements on iOS
- Improve eligibility check for introductory and promo offers
- Fixes a bug affecting the price display depending on time period
## 1.7.1
### Fixes on Android
- Improve paywall engine for default selected plan on display
- A/B test data for a flow of paywalls
- - Now, you can override paywall closing **after a purchase** with `PaywallActionInterceptor`
- Performance improvements on  Purchasely.start() method to retrieve application configuration and google products (pricing and offers)

## 1.7.0
### Features

- Support of GIF format for enhanced media capabilities.
- 🇳🇱 Dutch (NL) Language Support - The SDK now includes language support for Dutch localization.
- `TRIAL_PRICE` Tag Enhancement - The `TRIAL_PRICE` tag has been updated to consider the introductory price if both a free trial and an introductory price are configured for a subscription on the Google Play Console.
- `QUARTERLY_AMOUNT` Tag - The new `QUARTERLY_AMOUNT` tag has been added to provide the equivalent subscription price in quarter like it is already possible in daily, weekly, monthly and yearly. PLYPlan now contains the method `quarterlyEquivalentPrice()` to retrieve the value
- `AIRSHIP_USER_ID` Attribute - An `AIRSHIP_USER_ID` attribute has been introduced to facilitate integration with Airship.

### Fixes

- Carousel paywall restoration - Paywalls with a carousel are now correctly restored when navigating back within the app.
- Event emission fix - Restoration or Purchase events were not emitted correctly if performed consecutively
- We also fix several issues, the main one is our SDK is now available starting with iOS 11 (the past couple of releases are only available for iOS13+).
## 1.6.2
- Fix paywall display on Android with fetchPresentation
## 1.6.1
- Fix iOS compilation issue
## 1.6.0
- Auto import of your subscriptions at the first launch of the SDK
- Ukrainian language added
## 1.5.2
### Fixes
- `fetchPresentation()` method for Android to open a paywall asynchronously
- `closePaywall()`, which hides the paywall by default on Android, can now take optional boolean argument to close the paywall definitively and prevent it from being open again with `onProcessAction()`
- Remove paywalls from background tasks on Android when closed
- Remove `subscription_status` attribute from Subscription (temporary until available on all platforms)
## 1.5.1
Add optional argument to closePaywall() method to close definitively the paywall
## 1.5.0
### New features
- Fetch presentation before displaying it
- Disable specific placement or audience to not show a paywall
- Display your own paywall with Purchasely placements
## 1.4.2
🇮🇱 Hebrew language supported
🐞 Under the hood, we provide some stability improvements and several bug fixes
## 1.4.0
🔌 We have added the integration of mparticle, Branch and Customer.IO and you can now send user id or device id attributes for Amplitude
👤️ You can now send custom user attributes to our SDK with Purchasely.userAttributes() they will soon be used for a new feature.
## 1.3.2
⚠️ Important Patch fix on android to receive a callback on paywall display for a purchase, restore or cancel result
## 1.3.1
📈 Some new properties have been added to our SDK events, focusing on session and screen durations to help you understand when and how a user converts.
⭐️ A new public method has been added to help us understand your users premium content usage. This method userDidConsumeSubscriptionContent() should be call whenever your user is using a feature or content that is protected behind a paywall.
🐞 Minor fixes, mainly regarding our `contentId` that previously could not be sent in particular contexs.
## 1.3.0
### Previews

If your app already integrates deeplinks from Purchasely, you can now scan our new QR Code available in your Purchasely console to preview your drafted paywalls directly in your app.

### Eligibility for introductory offers

Beforehand, it was not possible to check if your current user is eligible for introductory offers. You can know check directly with a property added to `PLYPlan` called `isEligibleForIntroOffer`. Furthermore, Your paywalls will only display introductory offers automatically to clients eligible to.

### 3rd parties integrated
New 3rd parties have been integrated: `Sendinblue`, `Iterable`, and `AT Internet`

#### `PRESENTATION_CLOSED` SDK Event added

A new event has been added to let you know when your current user has tapped on the close button.

### Stability improvements and bug fixes

Under the hood, we provide some stability improvements and several bug fixes, focusing on Sandbox receipt errors.
## 1.2.5
Fix: Paywall action interceptor for promo code on Android
## 1.2.4
Fix: non Mac M1 support.

## 1.2.3
Fix: add static_framework to the iOS podspec.

## 1.2.2
Fix: add product linked to a subscription for iOS devices

## 1.2.1
### New integrations
This version also adds support for new third party integrations:
- [Mixpanel](https://docs.purchasely.com/integrations/mixpanel)
- CleverTap

## 1.2.0
### A/B Tests
This version brings native A/B tests to Purchasely. No need to use another tool, you can do it all and pilot it from Purchasely.
With our A/B tests you can
1. Easily start new tests without having to republish your app
2. Monitor the performance of it in terms of conversion to trial / trial to paid / renewal
3. Finish a test and chose which variant to apply

This is great to:
- Increase revenues by finding the right price point for your products
- Increase install to trial by finding the right composition / texts / visuals that present best your offers

No need for developer, everything is done from our console.
A/B tests are applied on _Placements_ that we brought to you with SDK 1.1.0. If you app already use them, you have nothing else to do but to upgrade SDK to 2.2.0 that essentially brings internal tracking.

> ⚠️ This feature will be activated in your console very soon.
> If you want it now, please request the support using the chat in the console.

### New integrations
This version also adds support for new third party integrations:
- [Adjust](https://docs.purchasely.com/integrations/adjust), improved support with native integration
- [Appsflyer](https://docs.purchasely.com/integrations/appsflyer)
- [OneSignal](https://docs.purchasely.com/integrations/onesignal)

## 1.1.0
We are introducing a new feature: **Placements**
Placements allows you to override the default paywall at specific locations in your apps (aka placements) instead of calling a paywall by its id (or not and get one default paywall by app).

First you define different placements where your paywalls are called from within your app like Home, Settings, Article, On boarding…
The method is almost exactly the same then the one you already use for a presentationController with an Id:

```dart
await Purchasely.presentPresentationForPlacement('your_placement_id');
```
Then you declare them in the [console](https://console.purchasely.io/) and define which paywall you want for which placement.
## 1.0.1
Display paywalls in fullscreen
## 1.0.0
First version of Purchasely Flutter SDK with integration of Purchasely SDK Android and iOS 3.0.0
Full documentation is available here: https://docs.purchasely.com/