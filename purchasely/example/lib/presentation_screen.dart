import 'dart:developer';

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

    Purchasely.setPaywallActionInterceptorCallback((PaywallActionInterceptorResult result) {
          print('Received action from paywall');
          inspect(result);

          if (result.action == PLYPaywallAction.navigate) {
            print('User wants to navigate');
            Purchasely.onProcessAction(true);
          } else if (result.action == PLYPaywallAction.close) {
            print('User wants to close paywall');
            Purchasely.onProcessAction(true);
          } else if (result.action == PLYPaywallAction.login) {
            print('User wants to login');
            //Present your own screen for user to log in
            onClose();
            Purchasely.userLogin('MY_USER_ID');
            Purchasely.onProcessAction(true);
          } else if (result.action == PLYPaywallAction.open_presentation) {
            print('User wants to open a new paywall');
            Purchasely.onProcessAction(true);
          } else if (result.action == PLYPaywallAction.purchase) {
            print('User wants to purchase');
            Purchasely.onProcessAction(true);
          } else if (result.action == PLYPaywallAction.restore) {
            print('User wants to restore his purchases');
            Purchasely.onProcessAction(true);
          } else {
            print('Action unknown ' + result.action.toString());
            Purchasely.onProcessAction(true);
          }
        });

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
