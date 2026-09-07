// Purchasely SDK — Fluent builder for SDK initialisation.

import 'dart:async';

import 'package:flutter/services.dart';

import 'bridge.dart';
import 'web_redemption.dart';

/// Running mode for the SDK.
///
/// Default is [PLYRunningMode.observer].
enum PLYRunningMode { observer, full }

/// Log level for the SDK.
enum PLYLogLevel { debug, info, warn, error }

/// Storekit transaction handling on iOS.
enum PLYStorekitVersion { storeKit1, storeKit2 }

/// Android stores supported by the SDK.
enum PLYStore { google, huawei, amazon }

/// Fluent builder for `Purchasely.start()`. Begin the chain with
/// `PurchaselyBuilder.apiKey('…')`, then chain modifiers, then call
/// `.start()`.
class PurchaselyBuilder {
  final String _apiKey;
  String? _appUserId;
  PLYRunningMode _runningMode;
  PLYLogLevel _logLevel;
  bool? _allowDeeplink;
  bool _allowCampaigns;
  String? _deeplink;
  bool? _automaticDeeplinkHandling;
  String? _anonymousUserId;
  bool _anonymousUserIdOverride = false;
  bool? _appHandlesRedemptionAlert;

  // Three-state proxy. Dart cannot tell `proxy(null)` from "proxy() never
  // called" from the nullable field alone: both leave `_proxyApi` null. The
  // native SDKs treat null as *clear the proxy*, so collapsing the two would
  // turn every start into an implicit clear, or make an explicit clear do
  // nothing. Hence the separate "was it called" flag; a sentinel default would
  // work too but costs the parameter its `String?` type.
  bool _proxyWasSet = false;
  String? _proxyApi;
  // Android only
  List<PLYStore> _stores;
  // iOS only
  PLYStorekitVersion _storekitVersion;

  PurchaselyBuilder._(this._apiKey,
      {String? appUserId,
      PLYRunningMode runningMode = PLYRunningMode.observer,
      PLYLogLevel logLevel = PLYLogLevel.error,
      bool? allowDeeplink,
      bool allowCampaigns = true,
      String? deeplink,
      List<PLYStore> stores = const [PLYStore.google],
      PLYStorekitVersion storekitVersion = PLYStorekitVersion.storeKit2})
      : _appUserId = appUserId,
        _runningMode = runningMode,
        _logLevel = logLevel,
        _allowDeeplink = allowDeeplink,
        _allowCampaigns = allowCampaigns,
        _deeplink = deeplink,
        _stores = List.of(stores),
        _storekitVersion = storekitVersion;

  static PurchaselyBuilder apiKey(String key) => PurchaselyBuilder._(key);

  PurchaselyBuilder appUserId(String? id) {
    _appUserId = id;
    return this;
  }

  PurchaselyBuilder runningMode(PLYRunningMode mode) {
    _runningMode = mode;
    return this;
  }

  PurchaselyBuilder logLevel(PLYLogLevel level) {
    _logLevel = level;
    return this;
  }

  /// Whether the SDK is allowed to open deeplinks.
  PurchaselyBuilder allowDeeplink(bool allow) {
    _allowDeeplink = allow;
    return this;
  }

  /// Whether the SDK is allowed to display campaign-driven presentations.
  /// Defaults to `true` in v6.
  PurchaselyBuilder allowCampaigns(bool allow) {
    _allowCampaigns = allow;
    return this;
  }

  /// Cold-start deeplink: pass a deeplink URL captured at launch (e.g. from the
  /// intent / `UIScene` connection options) so the SDK resolves it
  /// automatically once started. No separate [Purchasely.handleDeeplink] call
  /// is needed — the deeplink is replayed after the SDK finishes configuring.
  ///
  /// Pass `null` (or omit the modifier) when the app was not launched from a
  /// deeplink. Non-Purchasely URLs are ignored by the native SDK.
  PurchaselyBuilder handleDeeplink(String? deeplink) {
    _deeplink = deeplink;
    return this;
  }

  /// Android-only: whether the SDK automatically intercepts Purchasely
  /// deeplinks (`true` by default in v6). Disable it to fully control routing
  /// yourself (e.g. `singleTask` activities that re-dispatch intents manually)
  /// and call [Purchasely.handleDeeplink] where appropriate. iOS never
  /// auto-intercepts, so this modifier is a no-op there.
  PurchaselyBuilder automaticDeeplinkHandling(bool enabled) {
    _automaticDeeplinkHandling = enabled;
    return this;
  }

  /// Set the anonymous user id the SDK reports for this device.
  ///
  /// [id] must be a canonical UUID string, e.g.
  /// `'3f2504e0-4f89-11d3-9a0c-0305e82c3301'`. Dart has no UUID type, so the
  /// id crosses the bridge as a string and each native bridge parses it. A
  /// value that is not a canonical UUID is refused with an error log and the
  /// modifier is skipped — [start] still succeeds.
  ///
  /// The SDK stores the id in **uppercase**, on iOS and on Android, and
  /// applies it at [start] before it sends a network request or an event. The
  /// SDK applies it only when the device holds no anonymous id yet, unless
  /// [override] is `true`.
  ///
  /// **`override: true` splits the user history.** The backend keeps every
  /// event and every purchase under the previous id. Use it only when the app
  /// owns the anonymous identity, e.g. after a cross-device restore.
  PurchaselyBuilder anonymousUserId(String id, {bool override = false}) {
    _anonymousUserId = id;
    _anonymousUserIdOverride = override;
    return this;
  }

  /// Route Purchasely API traffic through a proxy instead of
  /// `api.purchasely.io`, for a region where that host is unreachable, such as
  /// mainland China.
  ///
  /// Only the API host changes: the paywall host and the tracking host always
  /// stay on production. Purchasely operates a proxy at
  /// `https://svc.purchasely.io`; you can also host your own.
  ///
  /// [api] must be an `https` base URL with a host, and it must carry no query,
  /// no fragment and no credentials. The native SDK refuses any other value
  /// with an error log and keeps the production host, so this modifier does not
  /// validate it again. Each native SDK drops a trailing slash.
  ///
  /// This is a start-time option. Neither native SDK has a runtime setter for
  /// it.
  ///
  /// Three states, and they are not interchangeable:
  ///
  /// | Call | Effect |
  /// | --- | --- |
  /// | `proxy('https://svc.purchasely.io')` | routes the API host |
  /// | `proxy(null)` | clears it, back to `api.purchasely.io` |
  /// | never called | leaves the current setting untouched |
  ///
  /// The last call wins, so `proxy(url).proxy(null)` ends cleared.
  PurchaselyBuilder proxy(String? api) {
    _proxyApi = api;
    _proxyWasSet = true;
    return this;
  }

  /// Hand the Web2App redemption result screen to the app.
  ///
  /// This flag decides who shows the outcome of a redemption, and with it when
  /// the SDK calls the listener added with
  /// [Purchasely.addWebRedemptionListener]:
  ///
  /// - `false` (the default): the SDK shows its own popin and calls the
  ///   listener after the user acknowledges the popin.
  /// - `true`: the SDK shows nothing and calls the listener as soon as the
  ///   redemption settles. The app must then show its own result screen.
  ///
  /// This is a start-time option because it changes what the native SDK
  /// presents. Set it before [start].
  PurchaselyBuilder appHandlesRedemptionAlert(bool handles) {
    _appHandlesRedemptionAlert = handles;
    return this;
  }

  /// Register [listener] for the outcome of a Web2App redemption
  /// (`{scheme}://ply/redeem/{token}`), and optionally hand the result screen
  /// to the app.
  ///
  /// ```dart
  /// await Purchasely.apiKey('API_KEY')
  ///     .webRedemptionListener(onRedemption, true)
  ///     .start();
  /// ```
  ///
  /// **The subscription happens here, at chain time — not inside [start].** A
  /// redemption can settle *during* `start()`, from a cold start that the
  /// `ply/redeem` link itself triggered, or from a token a previous launch left
  /// pending. Registering on the chain makes that ordering structurally
  /// impossible to get wrong, instead of a documentation warning an integrator
  /// can miss. `Purchasely.addWebRedemptionListener` stays available for the
  /// runtime case, and carries exactly that trade-off.
  ///
  /// The callback never crosses the bridge. Each native bridge registers
  /// *itself* as the delegate/listener during `start()`, unconditionally, and
  /// forwards every outcome as an event; this modifier only stores the callback
  /// and subscribes it locally.
  ///
  /// [appHandlesRedemptionAlert] is a shorthand for
  /// [PurchaselyBuilder.appHandlesRedemptionAlert]. Omit it to leave the flag
  /// unset, so the native default (the SDK shows its own popin) applies.
  PurchaselyBuilder webRedemptionListener(PLYWebRedemptionListener listener,
      [bool? appHandlesRedemptionAlert]) {
    addWebRedemptionListener(listener);
    if (appHandlesRedemptionAlert != null) {
      _appHandlesRedemptionAlert = appHandlesRedemptionAlert;
    }
    return this;
  }

  /// Android-only: stores the SDK is allowed to use (priority order). On iOS
  /// this modifier is a no-op.
  PurchaselyBuilder stores(List<PLYStore> stores) {
    _stores = List.of(stores);
    return this;
  }

  /// iOS-only: StoreKit version to use. On Android this modifier is a no-op.
  PurchaselyBuilder storekitVersion(PLYStorekitVersion version) {
    _storekitVersion = version;
    return this;
  }

  /// Start the SDK. Resolves to `true` once configured, throws a
  /// [PlatformException] otherwise.
  Future<bool> start() async {
    // Wire the dispatcher (idempotent) so subsequent PLYPresentationBuilder /
    // PLYPresentationRequest calls have a live channel to talk to.
    PurchaselyBridge.ensureInstalled();
    const channel = MethodChannel('purchasely');
    final result = await channel.invokeMethod<bool>(
      'start',
      <String, Object?>{
        'apiKey': _apiKey,
        'appUserId': _appUserId,
        'runningMode': _runningMode.name,
        'logLevel': _logLevel.name,
        'allowDeeplink': _allowDeeplink,
        'allowCampaigns': _allowCampaigns,
        if (_deeplink != null) 'deeplink': _deeplink,
        if (_automaticDeeplinkHandling != null)
          'automaticDeeplinkHandling': _automaticDeeplinkHandling,
        // The native bridges parse `anonymousUserId` into a UUID. An invalid
        // string is rejected there, with a log, and start() still succeeds.
        if (_anonymousUserId != null) 'anonymousUserId': _anonymousUserId,
        if (_anonymousUserId != null)
          'anonymousUserIdOverride': _anonymousUserIdOverride,
        // Present-with-null is an explicit clear; absent leaves the native
        // setting alone. `_proxyApi` alone cannot express that — see
        // `_proxyWasSet`. The standard codec preserves a null map value, so
        // both bridges read the difference with a containsKey check.
        if (_proxyWasSet) 'proxy': _proxyApi,
        if (_appHandlesRedemptionAlert != null)
          'appHandlesRedemptionAlert': _appHandlesRedemptionAlert,
        'stores': _stores.map((s) => s.name).toList(),
        'storekitVersion': _storekitVersion.name,
      },
    );
    return result ?? false;
  }
}
