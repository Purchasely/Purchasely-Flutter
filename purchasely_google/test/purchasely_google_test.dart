import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_google/purchasely_google.dart';
import 'package:purchasely_google/purchasely_google_platform_interface.dart';
import 'package:purchasely_google/purchasely_google_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPurchaselyGooglePlatform 
    with MockPlatformInterfaceMixin
    implements PurchaselyGooglePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final PurchaselyGooglePlatform initialPlatform = PurchaselyGooglePlatform.instance;

  test('$MethodChannelPurchaselyGoogle is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPurchaselyGoogle>());
  });

  test('getPlatformVersion', () async {
    PurchaselyGoogle purchaselyGooglePlugin = PurchaselyGoogle();
    MockPurchaselyGooglePlatform fakePlatform = MockPurchaselyGooglePlatform();
    PurchaselyGooglePlatform.instance = fakePlatform;
  
    expect(await purchaselyGooglePlugin.getPlatformVersion(), '42');
  });
}
