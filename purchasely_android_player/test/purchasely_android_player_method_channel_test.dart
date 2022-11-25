import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_android_player/purchasely_android_player_method_channel.dart';

void main() {
  MethodChannelPurchaselyAndroidPlayer platform = MethodChannelPurchaselyAndroidPlayer();
  const MethodChannel channel = MethodChannel('purchasely_android_player');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
