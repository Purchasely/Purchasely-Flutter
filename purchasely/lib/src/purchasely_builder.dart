// Purchasely SDK v6 — Fluent builder for SDK initialisation.

import 'dart:async';

import 'package:flutter/services.dart';

import 'bridge.dart';

/// Running mode for the SDK (v6).
///
/// Default in v6 is [V6RunningMode.observer] (was `full` in v5).
/// Named differently from the legacy v5 [V6RunningMode] (4 values) to avoid
/// an ambiguous re-export at the package boundary.
enum V6RunningMode { observer, full }

/// Log level for the SDK (v6).
///
/// Renamed from `V6LogLevel` to avoid an ambiguous re-export with the legacy
/// v5 enum of the same name (same values, but kept distinct for clarity).
enum V6LogLevel { debug, info, warn, error }

/// Storekit transaction handling on iOS.
enum StorekitVersion { storeKit1, storeKit2 }

/// Android stores supported by the SDK.
enum PLYStore { google, huawei, amazon }

/// Fluent builder for `Purchasely.start()`. Begin the chain with
/// `PurchaselyBuilder.apiKey('…')`, then chain modifiers, then call
/// `.start()`.
class PurchaselyBuilder {
  final String _apiKey;
  String? _appUserId;
  V6RunningMode _runningMode;
  V6LogLevel _logLevel;
  bool? _allowDeeplink;
  bool _allowCampaigns;
  // Android only
  List<PLYStore> _stores;
  // iOS only
  StorekitVersion _storekitVersion;

  PurchaselyBuilder._(this._apiKey,
      {String? appUserId,
      V6RunningMode runningMode = V6RunningMode.observer,
      V6LogLevel logLevel = V6LogLevel.error,
      bool? allowDeeplink,
      bool allowCampaigns = true,
      List<PLYStore> stores = const [PLYStore.google],
      StorekitVersion storekitVersion = StorekitVersion.storeKit2})
      : _appUserId = appUserId,
        _runningMode = runningMode,
        _logLevel = logLevel,
        _allowDeeplink = allowDeeplink,
        _allowCampaigns = allowCampaigns,
        _stores = List.of(stores),
        _storekitVersion = storekitVersion;

  /// Start the chain with an API key. The terminal `.start()` will refuse an
  /// empty key.
  static PurchaselyBuilder apiKey(String key) => PurchaselyBuilder._(key);

  PurchaselyBuilder appUserId(String? id) {
    _appUserId = id;
    return this;
  }

  PurchaselyBuilder runningMode(V6RunningMode mode) {
    _runningMode = mode;
    return this;
  }

  PurchaselyBuilder logLevel(V6LogLevel level) {
    _logLevel = level;
    return this;
  }

  /// Whether the SDK is allowed to open deeplinks.
  PurchaselyBuilder allowDeeplink(bool allow) {
    _allowDeeplink = allow;
    return this;
  }

  /// Whether the SDK is allowed to display campaign-driven presentations.
  PurchaselyBuilder allowCampaigns(bool allow) {
    _allowCampaigns = allow;
    return this;
  }

  /// Android-only: stores the SDK is allowed to use (priority order). On iOS
  /// this modifier is a no-op.
  PurchaselyBuilder stores(List<PLYStore> stores) {
    _stores = List.of(stores);
    return this;
  }

  /// iOS-only: StoreKit version to use. On Android this modifier is a no-op.
  PurchaselyBuilder storekitVersion(StorekitVersion version) {
    _storekitVersion = version;
    return this;
  }

  /// Start the SDK. Resolves to `true` once configured, throws a
  /// [PlatformException] otherwise.
  Future<bool> start() async {
    // Wire the v6 dispatcher (idempotent) so subsequent PresentationBuilder /
    // PresentationRequest calls have a live channel to talk to.
    PurchaselyV6Bridge.ensureInstalled();
    const channel = MethodChannel('purchasely');
    final result = await channel.invokeMethod<bool>(
      'v6/start',
      <String, Object?>{
        'apiKey': _apiKey,
        'appUserId': _appUserId,
        'runningMode': _runningMode.name,
        'logLevel': _logLevel.name,
        'allowDeeplink': _allowDeeplink,
        'allowCampaigns': _allowCampaigns,
        'stores': _stores.map((s) => s.name).toList(),
        'storekitVersion': _storekitVersion.name,
      },
    );
    return result ?? false;
  }
}
