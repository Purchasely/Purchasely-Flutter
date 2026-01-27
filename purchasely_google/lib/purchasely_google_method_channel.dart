import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'purchasely_google_platform_interface.dart';

/// An implementation of [PurchaselyGooglePlatform] that uses method channels.
class MethodChannelPurchaselyGoogle extends PurchaselyGooglePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('purchasely_google');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
