import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

class PLYPresentationView extends StatelessWidget {
  final PLYPresentation? presentation;
  final String? placementId;
  final String? presentationId;
  final String? contentId;
  final Function(PresentPresentationResult)? callback;

  // Channel name and view type must match the ones defined in the native side.
  final MethodChannel channel = MethodChannel('native_view_channel');
  final String viewType = 'io.purchasely.purchasely_flutter/native_view';

  PLYPresentationView({
    this.presentation,
    this.placementId,
    this.presentationId,
    this.contentId,
    this.callback,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'presentation': Purchasely.transformPLYPresentationToMap(presentation),
      'presentationId': this.presentationId,
      'placementId': this.placementId,
      'contentId': this.contentId,
    };

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        print('TargetPlatform = ANDROID');
        return AndroidView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (int id) {
            channel.setMethodCallHandler((MethodCall call) {
              if (call.method == 'onPresentationResult' && callback != null) {
                var viewResult = call.arguments['result'];
                var plan = call.arguments['plan'];
                callback!(PresentPresentationResult(
                    PLYPurchaseResult.values[viewResult],
                    plan != null ? Purchasely.transformToPLYPlan(plan) : null));
              }
              return Future.value(null);
            });
          },
        );
      case TargetPlatform.iOS:
        print('TargetPlatform = iOS');
        return SafeArea( // Wrap UiKitView with SafeArea
          child: UiKitView(
            viewType: viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: (int id) {
              channel.setMethodCallHandler((MethodCall call) {
                if (call.method == 'onPresentationResult' && callback != null) {
                  var viewResult = call.arguments['result'];
                  var plan = call.arguments['plan'];
                  callback!(PresentPresentationResult(
                      PLYPurchaseResult.values[viewResult],
                      plan != null ? Purchasely.transformToPLYPlan(plan) : null));
                }
                return Future.value(null);
              });
            },
          ),
        );
      default:
        return Text('$defaultTargetPlatform is not supported yet.');
    }
  }
}
