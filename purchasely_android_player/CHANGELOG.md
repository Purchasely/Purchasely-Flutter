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