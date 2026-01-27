import 'purchasely_android_player_platform_interface.dart';

class PurchaselyAndroidPlayer {
  Future<String?> getPlatformVersion() {
    return PurchaselyAndroidPlayerPlatform.instance.getPlatformVersion();
  }
}
