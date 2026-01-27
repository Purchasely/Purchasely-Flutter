import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'purchasely_google_method_channel.dart';

abstract class PurchaselyGooglePlatform extends PlatformInterface {
  /// Constructs a PurchaselyGooglePlatform.
  PurchaselyGooglePlatform() : super(token: _token);

  static final Object _token = Object();

  static PurchaselyGooglePlatform _instance = MethodChannelPurchaselyGoogle();

  /// The default instance of [PurchaselyGooglePlatform] to use.
  ///
  /// Defaults to [MethodChannelPurchaselyGoogle].
  static PurchaselyGooglePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PurchaselyGooglePlatform] when
  /// they register themselves.
  static set instance(PurchaselyGooglePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
