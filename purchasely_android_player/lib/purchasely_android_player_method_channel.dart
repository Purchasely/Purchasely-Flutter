import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'purchasely_android_player_platform_interface.dart';

/// An implementation of [PurchaselyAndroidPlayerPlatform] that uses method channels.
class MethodChannelPurchaselyAndroidPlayer
    extends PurchaselyAndroidPlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('purchasely_android_player');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
