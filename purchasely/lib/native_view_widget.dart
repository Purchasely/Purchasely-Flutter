import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

class PLYPresentationView extends StatelessWidget {
  final Function onClose;
  final Function onLoaded;

  final PLYPresentation? presentation;
  final String? placementId;
  final String? presentationId;
  final String? contentId;

  // Channel name and view type must match the ones defined in the native side.
  final MethodChannel channel = MethodChannel('native_view_channel');
  final String viewType = 'io.purchasely.purchasely_flutter/native_view';

  PLYPresentationView({
    required this.onLoaded,
    required this.onClose,
    this.presentation,
    this.placementId,
    this.presentationId,
    this.contentId,
  });

  @override
  Widget build(BuildContext context) {

    final Map<String, dynamic> creationParams = <String, dynamic>{
      'presentation': Purchasely.transformPLYPresentationToMap(presentation),
      'presentationId': this.presentationId,
      'placementId': this.placementId,
      'contentId': this.contentId,
    };

    return AndroidView(
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (int id) {
        channel.setMethodCallHandler((MethodCall call) {
          switch (call.method) {
            case 'onClose':
              onClose();
              break;
            case 'onLoaded':
              onLoaded();
              break;
            default:
              break;
          }
          return Future.value(null);
        });
      },
    );
  }
}
