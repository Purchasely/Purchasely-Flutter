
import 'purchasely_google_platform_interface.dart';

class PurchaselyGoogle {
  Future<String?> getPlatformVersion() {
    return PurchaselyGooglePlatform.instance.getPlatformVersion();
  }
}
