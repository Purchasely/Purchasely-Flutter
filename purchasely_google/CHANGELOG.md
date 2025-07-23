## 5.3.0
### 🚀 Introducing Flows
We’re introducing Flows, a powerful new feature that lets you orchestrate personalized, multi-screen journeys directly from the Purchasely Console.
Whether you're onboarding users, promoting offers, or guiding upgrades, Flows are tailored to user behavior and lifecycle stages.
>  ⚠️ **Important**
>  Flows is currently available in beta and accessible only to selected customers.
> If you're interested in early access, please reach out to the Purchasely team.

### 🖥️ Enhanced Presentation Display API
A new display method has been added to PLYPresentation objects, enabling immediate rendering of pre-fetched presentations.
>  ⚠️ **Important**
> This API is required when using the Flows feature.
> It ensures presentations are displayed according to their designated mode (e.g. push, modal, fullscreen, etc.) and handles the Flow's lifecycle and navigation state seamlessly

### 💳 Web Checkout Action
The Screen Composer’s new Web Checkout Action makes it effortless to turn any button into a purchase flow that suits your business. With a few clicks you can choose between:
a Stripe integration complete with native Purchasely support and built-in A/B-test and conversion tracking
any other web-billing provider you already use without conversion tracking
For customers in the U.S., this update is fully compliant with Apple’s latest policy: they can now subscribe outside the App Store via a web checkout flow.
Simply drag the Web Checkout Action onto your screen, map it to the button of your choice, and configure the SDK to open your chosen URL.
Whether you select “Stripe” for consolidated analytics in your Purchasely dashboard or “Other” to keep using an existing billing solution, setup is literally as simple as pasting in a link.

Behind the scenes, Purchasely’s Stripe Web Checkout integration ensures your web-based transactions feed directly into our A/B-testing dashboard alongside in-app data. Ensuring that you see end-to-end funnel performance without any extra wiring.
If you prefer a different provider, the SDK will hand off users to whatever URL you specify, leaving conversion logging to your own systems.

### 🎨 Asset Prefetching for Seamless UX
To deliver smoother transitions, the SDK now automatically preloads image assets prior to presenting a screen with Purchasely.fetchPresentation(), minimizing perceived latency and visual flickering.

### 🔧 Stability & Performance Improvements
This release includes various stability improvements, internal refinements, and minor bug fixes to enhance overall reliability and developer experience.

## 5.2.0
### 🎯 Introductory, Promotional, and Regular Offers — All on One Paywall

Present the right pricing to the right user, all through a single paywall.
The SDK now automatically selects and displays Introductory, Promotional, or Regular offers based on user eligibility — simplifying configuration and maximizing relevance.

### 🔁 Dynamic Offerings

With [Dynamic Offering](dynamic-offering), you can now define in real-time which Offering a user should see.
This drastically reduces the number of paywalls you need and enables a cleaner, more scalable monetization setup.

### 📱 Support for Google Billing v7

Upgraded to Google Play Billing Library v7, ensuring compatibility with the latest billing features and improvements.

### 🛠 Fixes & Improvements

- Add the ability to compare the offer of plan A to the price of plan B with tags `OFFER_DISCOUNT_PERCENTAGE` and `OFFER_PRICE_COMPARISON`, like `{{OFFER_DISCOUNT_PERCENTAGE(plan_a, plan_b, offer_from_a)}}`

#### iOS

- Enhanced eligibility system for more accurate offer selection
- Improved image loading performance
- Fixed an issue where the subscription view could throw an error in certain cases
- Corrected misleading error logs related to image loading
- Resolved a price rounding inconsistency
- We've also added a fix for a rare issue caused by a bug in iOS 18.4.1, where StoreKit could fail to respond when fetching products. This could prevent the SDK from starting correctly. The SDK now includes a safeguard to handle this situation gracefully.

#### Android

- Smarter and more consistent background color management ensures a polished look across all devices.
- Enhanced handling of deep links to prevent them from being triggered multiple times in certain edge cases, improving navigation reliability and user experience.
- Fix a potential display issue when using a carousel inside a tab layout
## 5.1.2
### Android
- Fix surveys events properties
## iOS
- Fix surveys events properties
- Added check to prevent multi start call
- Added result callback to userLogout method
## 5.1.1
### Android
- Fix image display issue between default and selected state
## iOS
- Improved Event System
- Enhanced Stability & Reliability
## 5.1.0
## 🚀 Campaigns Support
Introducing our powerful new Campaigns feature, enabling you to launch targeted in-app campaigns for specific audiences or all users right at app launch.
- Works just like deep links:
  - Simply set `Purchasely.readyToOpenDeeplink = true` to enable campaigns.
- Gain more control over campaign displays:
  - Use `Purchasely.uiHandler` for custom UI management.
## 📊 Enhanced Built-in Attributes
Get deeper insights into user interactions with new built-in attributes for analytics and event tracking:
- **Display & Dismissal Tracking:**
  - Number of displays and dismissals per screen
  - Number of displays and dismissals per placement
- **Last Display Date Tracking:**
  - Last display timestamp per screen
  - Last display timestamp per placement
- **A/B Testing Insights:**
  - A/B tests viewed with their variant ID
  - Latest A/B test and variant viewed
## 🆕 New Public API Method: `clearBuiltInAttributes`
Now you can reset built-in attributes easily when needed. Purchasely automatically calls this method when `Purchasely.userLogout()` is triggered.
## 5.0.6
### Android
- Removed module's package name from their manifest to avoid conflicts with namespace declarations.
## 5.0.5
### Android
- Restore Google Store by default if no android store are specified in `Purchasely.start()`
### iOS
- Add InAppRenewed event
## 5.0.4
### Android
- Specified explicit namespace declarations for all SDK modules in Gradle.
- App Started Event: Delayed the triggering of AppStartedEvent until the SDK is fully configured.
- Open Placement Action: Resolved an issue where the open placement action was triggered with an incorrect ID.
- Various enhancements and optimizations to boost stability and performance.
### iOS
- Improved GIF handling – Fixed an issue where GIFs sometimes played at incorrect speeds and ensured proper display even when missing the expected file extension.
- Optimized receipt processing
- Default option selection – Fixed an issue where the default option selection for multiple option component wasn't properly set.
## 5.0.3
- User Attributes Listener: Introduced a callback to notify when a user attribute is added or removed.
- General performance enhancements and bug fixes.
## 5.0.2
Improvements and bug fixes.
## 5.0.1
### Fixes
- Placement ID issue that could return the wrong screen in some cases.
- Event count issue for "presentation viewed."
### Improvements
- Optimization for non-subscription and in-app purchase apps.
- General performance enhancements
## 5.0.0
Explore the full details of this release in our [changelog](https://docs.purchasely.com/changelog/500).
## 5.0.0-rc01
Explore the full details of this release in our [changelog](https://docs.purchasely.com/changelog/500-rc01).
## 4.5.1
- Various improvements and bug fixes to enhance performance and stability.
## 4.5.0
- Markdown: Enhanced text formatting capabilities by supporting markdown syntax for bold, italic, strikethrough, and links. Reach out to the Customer Success Team to activate it for your account.
- Amount Tag Pricing: Improved price display on AMOUNT tag by hiding decimals when the price is a whole number.
- Various enhancements and optimizations to boost stability and performance.
## 4.4.1
- Fix method `userSubscriptions` on iOS platform.
## 4.4.0
- **Audience Targeting**: Added capability to segment audiences based on user's country and purchase history.
- **UI Enhancements**:
     - Introduced a customizable header button as an alternative to the default close button.
- **Subscription Management**: New method `userSubscriptionsHistory` allows retrieval of expired subscriptions.
### Android
- **Google Play Billing**: Upgraded to version 6.
- **Paywall Engine**: Improved paywall engine for better performance.
## 4.3.4
### Fixes for Android
- Fixed presentations cache.
### Fixes for iOS
- Resolved a bug that caused the discount percentage to display incorrectly for users using the pay as you go payment method.
- Corrected a text color display issue occurring when switching between dark mode and light mode in the operating system while viewing the paywall.
## 4.3.3
### Fixes
- Invalidate subscriptions cache and built-in attributes when calling Purchasely.userLogin() or Purchasely.userLogout().
- Fix background an progress color when opening a presentation from another one with the action open_presentation or open_placement.
## 4.3.2
Improvements and bug fixes.
## 4.3.1
Improvements and bug fixes.
## 4.3.0
### 🕒 User Centric Countdowns
Countdowns tailored to individual users have been implemented, enabling personalized timers based on user attributes.
Example: users may have 24 hours to subscribe to an offer following their initial subscription.
### Improvements and Optimizations
Numerous enhancements and optimizations are being implemented to elevate the user experience.
## 4.2.5
### Fixes for Android
- Fix possible crash with paywall action interceptor if user tap multiple times on same button
## 4.2.4
### Fixes for iOS
- minor bug fixes
## 4.2.3
### Fixes for Android
- Incorrect offer selected when purchasing a developer determined offer (eligible to all users) but also eligible to introductory offer (eligible to new users only). This impact the Winback/Retention offer feature of Purchasely where the offer chosen may be replaced by an introductory offer when the user never subscribed before
### Fixes for iOS
- minor bug fixes
## 4.2.2
Improvements and bug fixes.
## 4.2.1
Improvements and bug fixes.
## 4.2.0
### 🌙 Native Dark Mode Support for Presentations

Dark mode support has been implemented for screens & paywalls, automatically adapting to the user’s system settings for an improved viewing comfort. In the Console, you can now define 2 color sets (light & dark) for the same paywall.

Developers can override the default setting with `Purchasely.setThemeMode(PLYThemeMode.dark);` or `Purchasely.setThemeMode(PLYThemeMode.light);`, enabling more control over the app’s appearance and accommodating user preferences

### 🔍 Augmented Session User Attributes

Additional attributes have been added to track user session activity.

These attributes provide detailed insights into user engagement with the app, like session frequency, interaction with paywalls, and purchase activities.

This level of detail aids in fine-tuning user engagement strategies and understanding user behavior patterns more accurately

### 🏷 Tags System Extended to All Labels

The tags system has been expanded to include all label types, allowing for dynamic display of pricing, introductory offers or promotional offers for any plan any where in the paywalls (an not only in the buttons). This update gives more flexibility in UI customization and dynamic content presentation.

## Improvements and Optimizations

**🔄 New `batchCustomUserId` Attribute for External Integrations**: Enhances data syncing with external systems.

🔧 **Setting a StoreKit version is now mandatory**
You must know explicitly set a StoreKit setting on SDK initialization
```dart
await Purchasely.start(
          apiKey: 'YOUR_API_KEY', storeKit1: true); // true for StoreKit 1, false for StoreKit 2
```
## 4.1.3
🚨 Important: This SDK version uses StoreKit 2 by default. Read the [documentation](https://docs.purchasely.com/quick-start-1/sdk-configuration/storekit-2) for more information.
If you did not configure StoreKit 2 in Purchasely console, the SDK will fallback to StoreKit 1.

### Fixes for Android:
- Solved attributes for integration like Adjust, CleverTap, etc.
## 4.1.2
🚨 Important: This SDK version uses StoreKit 2 by default. Read the [documentation](https://docs.purchasely.com/quick-start-1/sdk-configuration/storekit-2) for more information.
If you did not configure StoreKit 2 in Purchasely console, the SDK will fallback to StoreKit 1.

### Fixes for iOS:
- Close button always visible even when deactived on Purchasely console
- Infinite loader when cancelling purchase

### Fix for Android:
- Possible crash when saving user attributes if application was compiled with Java 8 due to Kotlinx Serialization [issue](https://github.com/Kotlin/kotlinx.serialization/issues/2326)
## 4.1.1
🚨 Important: This SDK version uses StoreKit 2 by default. Read the [documentation](https://docs.purchasely.com/quick-start-1/sdk-configuration/storekit-2) for more information.
If you did not configure StoreKit 2 in Purchasely console, the SDK will fallback to StoreKit 1.

## Improvements:
- Purchase with promo offer
- `isEligibleForIntroOffer` method
- Metadata handling for 'Use your own paywall'

### iOS only:
- `signPromotionalOffer` method

### Android only:
- Added `subscriptionOffer` to Paywall Action Interceptor parameters
## 4.0.1
🚨 Important: This SDK version uses StoreKit 2 by default. Read the [documentation](https://docs.purchasely.com/quick-start-1/sdk-configuration/storekit-2) for more information.
If you did not configure StoreKit 2 in Purchasely console, the SDK will fallback to StoreKit 1.
### Major fix
In this release, we have addressed a bug affecting the purchase action while using the SDK in Observer mode. Please update to this version if you are in paywall observer mode.
## 4.0.0
🚨 Important: This SDK version uses StoreKit 2 by default unless you have not setup credential for SK2 in Purchasely console.
🚧 Important: Documentation for this release is in progress and will be available in early September. Some methods and properties have undergone changes. Detailed information will follow soon.
### Google Play Billing v5 Integration
Version: Purchasely SDK 4.0.0 now integrates with Google Play Billing v5 (5.2.1). This ensures you have access to the comprehensive features introduced in the latest version of Google's in-app subscriptions.
Action Required: Review your plans on the Purchasely console to confirm the presence of a basePlan identifier.
### StoreKit 2 by default
On iOS devices running with iOS 15+, Purchasely SDK uses StoreKit 2 by default.
Please, follow our documentation to upload your private key and do all necessary steps for StoreKit 2 on Purchasely console.
### Promo Offers (Exclusive for Google and Apple)
New Feature: Excitingly, we're introducing support for promotional offers on AppStore Connect and developer determined offers on Google Play Console.
Action Required: When setting up your developer determined offers in the Google Play Console, make sure to tag them as "ignore-offer". This ensures that the Purchasely SDK doesn't automatically apply them to all your paywalls. Instead, they'll be used exclusively where you've specified.
### iOS Eligibility Management
Streamlined and restructured for products, providing a more coherent and optimized experience.
### Presentation lifecycle handling
- `Purchasely.hidePresentation()` to hide a paywall.
- `Purchasely.showPresenttation()` to display hidden paywall.
- `Purchasely.closePresentation()` to close definitely paywall displayed (needs to call fetchPresentation to display it again).
### Is Anonymous
Add method `Purchasely.isAnonymous()`: Promise<boolean> to know if your user is currently anonymous or not for Purchasely.
### Android Build Configuration Update
Kotlin: Upgraded to 1.7.2.

## 1.7.1
### Fixes on Android
- Improve paywall engine for default selected plan on display
- A/B test data for a flow of paywalls
- - Now, you can override paywall closing **after a purchase** with `PaywallActionInterceptor`
- Performance improvements on  Purchasely.start() method to retrieve application configuration and google products (pricing and offers)

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