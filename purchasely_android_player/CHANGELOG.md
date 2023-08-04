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