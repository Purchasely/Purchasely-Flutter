import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:purchasely_flutter/native_view_widget.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

class PresentationScreen extends StatelessWidget {
  final Map<String, dynamic> properties;
  final Function(PresentPresentationResult)? callback;

  PresentationScreen({required this.properties, this.callback});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Wrap with SafeArea
      child: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: _buildPresentationView(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPresentationView() {
    // You can set a paywall action interceptor if you want to handle the close differently,
    // handle login or make the purchase yourself
    Purchasely.setPaywallActionInterceptorCallback(
        (PaywallActionInterceptorResult result) {
      print('Received action from paywall');
      inspect(result);

      if (result.action == PLYPaywallAction.navigate) {
        print('User wants to navigate');
        Purchasely.onProcessAction(true);
      } else if (result.action == PLYPaywallAction.close) {
        print('User wants to close paywall');
        Purchasely.onProcessAction(true);
      } else if (result.action == PLYPaywallAction.close_all) {
        print('User wants to close all screens');
        Purchasely.onProcessAction(true);
      } else if (result.action == PLYPaywallAction.login) {
        print('User wants to login');
        //Present your own screen for user to log in
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
        presentation: properties['presentation'],
        presentationId: properties['presentationId'],
        placementId: properties['placementId'],
        contentId: properties['contentId'],
        callback: callback ??
            (PresentPresentationResult result) {
              print(
                  'Presentation result:${result.result} - plan:${result.plan?.vendorId}');
            });

    return presentationView ?? Container();
  }
}
