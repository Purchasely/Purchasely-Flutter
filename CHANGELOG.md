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