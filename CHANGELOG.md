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