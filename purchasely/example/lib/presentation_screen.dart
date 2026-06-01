import 'package:flutter/material.dart';
import 'package:purchasely_flutter/native_view_widget.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

/// Renders a Purchasely presentation inline (embedded) inside a screen.
///
/// Build the [PresentationRequest] with the fluent [PresentationBuilder] and
/// pass it in. The [PLYPresentationView] preloads it and hands the resulting
/// `requestId` to the native inline view.
class PresentationScreen extends StatelessWidget {
  final PresentationRequest request;

  const PresentationScreen({Key? key, required this.request}) : super(key: key);

  /// Convenience constructor that builds a [PresentationRequest] for a
  /// placement, wiring the dismiss callback to pop the screen.
  factory PresentationScreen.placement(
    String placementId, {
    Key? key,
    String? contentId,
    void Function(PresentationOutcome outcome)? onDismissed,
  }) {
    final request = PresentationBuilder.placement(placementId)
        .contentId(contentId)
        .onPresented((presentation, error) {
      debugPrint('Presentation presented — error=$error');
    }).onDismissed((outcome) {
      debugPrint(
          'Presentation dismissed — purchaseResult=${outcome.purchaseResult}');
      onDismissed?.call(outcome);
    }).build();
    return PresentationScreen(key: key, request: request);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: PLYPresentationView(request: request),
            )
          ],
        ),
      ),
    );
  }
}
