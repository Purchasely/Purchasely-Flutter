import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_google/purchasely_google.dart';
import 'package:purchasely_google/purchasely_google_method_channel.dart';
import 'package:purchasely_google/purchasely_google_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default instance is the method channel implementation', () {
    expect(
      PurchaselyGooglePlatform.instance,
      isA<MethodChannelPurchaselyGoogle>(),
    );
  });

  test('getPlatformVersion routes through the channel', () async {
    const channel = MethodChannel('purchasely_google');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return '6.0.0';
    });

    expect(await PurchaselyGoogle().getPlatformVersion(), '6.0.0');
    expect(calls.single.method, 'getPlatformVersion');

    messenger.setMockMethodCallHandler(channel, null);
  });
}
