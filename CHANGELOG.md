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