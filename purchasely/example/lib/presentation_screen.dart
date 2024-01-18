import 'package:flutter/material.dart';
import 'package:purchasely_flutter/native_view_widget.dart';

class PresentationScreen extends StatelessWidget {
  final Function onClose;

  PresentationScreen({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: NativeView(onClose: () => onClose()),
          ),
        ],
      ),
    );
  }
}
