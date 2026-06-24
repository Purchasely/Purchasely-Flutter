// Purchasely SDK — Fluent builder for SDK initialisation.

import 'dart:async';

import 'package:flutter/services.dart';

import 'bridge.dart';

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
/// `PLYPurchaselyBuilder.apiKey('…')`, then chain modifiers, then call
/// `.start()`.
class PLYPurchaselyBuilder {
  final String _apiKey;
  String? _appUserId;
  PLYRunningMode _runningMode;
  PLYLogLevel _logLevel;
  bool? _allowDeeplink;
  bool? _allowCampaigns;
  // Android only
  List<PLYStore> _stores;
  // iOS only
  PLYStorekitVersion _storekitVersion;

  PLYPurchaselyBuilder._(this._apiKey,
      {String? appUserId,
      PLYRunningMode runningMode = PLYRunningMode.observer,
      PLYLogLevel logLevel = PLYLogLevel.error,
      bool? allowDeeplink,
      bool? allowCampaigns,
      List<PLYStore> stores = const [PLYStore.google],
      PLYStorekitVersion storekitVersion = PLYStorekitVersion.storeKit2})
      : _appUserId = appUserId,
        _runningMode = runningMode,
        _logLevel = logLevel,
        _allowDeeplink = allowDeeplink,
        _allowCampaigns = allowCampaigns,
        _stores = List.of(stores),
        _storekitVersion = storekitVersion;

  static PLYPurchaselyBuilder apiKey(String key) => PLYPurchaselyBuilder._(key);

  PLYPurchaselyBuilder appUserId(String? id) {
    _appUserId = id;
    return this;
  }

  PLYPurchaselyBuilder runningMode(PLYRunningMode mode) {
    _runningMode = mode;
    return this;
  }

  PLYPurchaselyBuilder logLevel(PLYLogLevel level) {
    _logLevel = level;
    return this;
  }

  /// Whether the SDK is allowed to open deeplinks.
  PLYPurchaselyBuilder allowDeeplink(bool allow) {
    _allowDeeplink = allow;
    return this;
  }

  /// Whether the SDK is allowed to display campaign-driven presentations.
  /// Omit this modifier to keep each native SDK's default/backend-configured value.
  PLYPurchaselyBuilder allowCampaigns(bool allow) {
    _allowCampaigns = allow;
    return this;
  }

  /// Android-only: stores the SDK is allowed to use (priority order). On iOS
  /// this modifier is a no-op.
  PLYPurchaselyBuilder stores(List<PLYStore> stores) {
    _stores = List.of(stores);
    return this;
  }

  /// iOS-only: StoreKit version to use. On Android this modifier is a no-op.
  PLYPurchaselyBuilder storekitVersion(PLYStorekitVersion version) {
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
        if (_allowCampaigns != null) 'allowCampaigns': _allowCampaigns,
        'stores': _stores.map((s) => s.name).toList(),
        'storekitVersion': _storekitVersion.name,
      },
    );
    return result ?? false;
  }
}
