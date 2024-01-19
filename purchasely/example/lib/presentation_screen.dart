import 'package:flutter/material.dart';
import 'package:purchasely_flutter/native_view_widget.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

class PresentationScreen extends StatelessWidget {
  final Function onClose;
  final Function onLoaded;
  final Map<String, dynamic> properties;

  PresentationScreen(
      {required this.properties,
      required this.onClose,
      required this.onLoaded});

  @override
  Widget build(BuildContext context) {

    PLYPresentationView? presentationView = Purchasely.getPresentationView(
      onLoaded: onLoaded,
      onClose: onClose,
      presentation: properties['presentation'],
      presentationId: properties['presentationId'],
      placementId: properties['placementId'],
      contentId: properties['contentId'],
    );

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: presentationView ?? Container(),
          )
        ],
      ),
    );
  }
}
