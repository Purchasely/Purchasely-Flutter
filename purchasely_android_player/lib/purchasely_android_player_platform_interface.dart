import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'purchasely_android_player_method_channel.dart';

abstract class PurchaselyAndroidPlayerPlatform extends PlatformInterface {
  /// Constructs a PurchaselyAndroidPlayerPlatform.
  PurchaselyAndroidPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static PurchaselyAndroidPlayerPlatform _instance =
      MethodChannelPurchaselyAndroidPlayer();

  /// The default instance of [PurchaselyAndroidPlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelPurchaselyAndroidPlayer].
  static PurchaselyAndroidPlayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PurchaselyAndroidPlayerPlatform] when
  /// they register themselves.
  static set instance(PurchaselyAndroidPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
