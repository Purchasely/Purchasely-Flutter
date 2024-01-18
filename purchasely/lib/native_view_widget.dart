import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NativeView extends StatelessWidget {
  final Function onClose;
  final MethodChannel methodChannel = MethodChannel('your_channel_name');

  NativeView({required this.onClose});

  @override
  Widget build(BuildContext context) {
    const String viewType = 'NativeView';

    final Map<String, dynamic> creationParams = <String, dynamic>{
      'presentationId': 'promo-cm',
    };

    return AndroidView(
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (int id) {
        methodChannel.setMethodCallHandler((MethodCall call) {
          print("MethodCall: ${call.method}");
          if (call.method == 'onClose') {
            onClose();
          }
          return Future.value(null);
        });
      },
    );
  }
}