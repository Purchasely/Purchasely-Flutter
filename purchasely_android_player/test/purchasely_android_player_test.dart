import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_android_player/purchasely_android_player.dart';
import 'package:purchasely_android_player/purchasely_android_player_platform_interface.dart';
import 'package:purchasely_android_player/purchasely_android_player_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPurchaselyAndroidPlayerPlatform 
    with MockPlatformInterfaceMixin
    implements PurchaselyAndroidPlayerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final PurchaselyAndroidPlayerPlatform initialPlatform = PurchaselyAndroidPlayerPlatform.instance;

  test('$MethodChannelPurchaselyAndroidPlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPurchaselyAndroidPlayer>());
  });

  test('getPlatformVersion', () async {
    PurchaselyAndroidPlayer purchaselyAndroidPlayerPlugin = PurchaselyAndroidPlayer();
    MockPurchaselyAndroidPlayerPlatform fakePlatform = MockPurchaselyAndroidPlayerPlatform();
    PurchaselyAndroidPlayerPlatform.instance = fakePlatform;
  
    expect(await purchaselyAndroidPlayerPlugin.getPlatformVersion(), '42');
  });
}
