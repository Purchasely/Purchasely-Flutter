import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_android_player/purchasely_android_player.dart';
import 'package:purchasely_android_player/purchasely_android_player_method_channel.dart';
import 'package:purchasely_android_player/purchasely_android_player_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default instance is the method channel implementation', () {
    expect(
      PurchaselyAndroidPlayerPlatform.instance,
      isA<MethodChannelPurchaselyAndroidPlayer>(),
    );
  });

  test('getPlatformVersion routes through the channel', () async {
    const channel = MethodChannel('purchasely_android_player');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return '6.0.0';
    });

    expect(await PurchaselyAndroidPlayer().getPlatformVersion(), '6.0.0');
    expect(calls.single.method, 'getPlatformVersion');

    messenger.setMockMethodCallHandler(channel, null);
  });
}
