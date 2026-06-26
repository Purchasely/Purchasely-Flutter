import 'package:flutter/material.dart';
import 'package:purchasely_flutter/native_view_widget.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

/// Renders a Purchasely presentation inline (embedded) inside a screen.
///
/// Build the [PLYPresentationRequest] with the fluent [PLYPresentationBuilder] and
/// pass it in. The [PLYPresentationView] preloads it and hands the resulting
/// `requestId` to the native inline view.
///
/// Inline vs modal: a modal/drawer presentation dismisses itself when the user
/// taps the close (✕) button. An **inline** view does not — tapping ✕ only
/// emits [PLYPresentationRequest.onCloseRequested]. It is up to the host to
/// react (here: pop this screen). Without wiring `onCloseRequested`, the close
/// button appears to do nothing.
class PresentationScreen extends StatelessWidget {
  final PLYPresentationRequest request;

  const PresentationScreen({Key? key, required this.request}) : super(key: key);

  /// Convenience constructor that builds a [PLYPresentationRequest] for a
  /// placement, wiring the close + dismiss callbacks to pop the screen.
  factory PresentationScreen.placement(
    String placementId, {
    Key? key,
    String? contentId,
    void Function()? onCloseRequested,
    void Function(PLYPresentationOutcome outcome)? onDismissed,
  }) {
    final request = PLYPresentationBuilder.placement(placementId)
        .contentId(contentId)
        .onPresented((presentation, error) {
      debugPrint('PLYPresentation presented — error=$error');
    }).onCloseRequested(() {
      // Inline views don't auto-dismiss: the ✕ button only fires this event,
      // so the host must close the view itself.
      debugPrint('PLYPresentation close requested (inline)');
      onCloseRequested?.call();
    }).onDismissed((outcome) {
      debugPrint(
          'PLYPresentation dismissed — purchaseResult=${outcome.purchaseResult}');
      onDismissed?.call(outcome);
    }).build();
    return PresentationScreen(key: key, request: request);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            // ── Contenu AU-DESSUS du PLYPresentationView ──────────────────
            Container(
              width: double.infinity,
              color: Colors.indigo,
              padding: const EdgeInsets.all(16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contenu au-dessus',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Le paywall ci-dessous est rendu en mode inline (embarqué).',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            // ── Le paywall inline ─────────────────────────────────────────
            Expanded(
              child: PLYPresentationView(request: request),
            ),

            // ── Contenu EN-DESSOUS du PLYPresentationView ─────────────────
            Container(
              width: double.infinity,
              color: Colors.indigo.shade50,
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Contenu en-dessous — appuyez sur la croix (✕) du paywall '
                'pour fermer cet écran.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.indigo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
