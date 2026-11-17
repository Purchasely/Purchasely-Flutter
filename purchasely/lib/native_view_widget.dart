import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'src/presentation.dart';
import 'src/presentation_outcome.dart';
import 'src/presentation_request.dart';

/// Renders a Purchasely presentation inline (embedded) inside the Flutter
/// widget tree, as opposed to a full-screen / modal presentation.
///
/// The widget preloads the supplied [PLYPresentationRequest] to obtain a stable
/// `requestId`, then hands that id to the native platform view through the
/// `{ "requestId": <id> }` creation params. The native side resolves the
/// preloaded presentation from that id and renders it inline.
///
/// Lifecycle: the embedded (inline) path surfaces its events through the same
/// `purchasely-presentation-events` channel as a full-screen presentation,
/// keyed by `requestId`. Once the native view is mounted it emits the same
/// `onPresented` envelope as the modal path, and when the inline presentation
/// is dismissed it emits the same `onDismissed` envelope (with the
/// `display()`-style [PLYPresentationOutcome]) — so the request's
/// [PLYPresentationRequest.onPresented] and
/// [PLYPresentationRequest.onDismissed] callbacks fire for the inline view too.
class PLYPresentationView extends StatefulWidget {
  /// The presentation request to render inline. Build it with
  /// `PLYPresentationBuilder.placement(...)...build()`.
  final PLYPresentationRequest request;

  /// Optional widget shown while the presentation is preloading.
  final Widget? loadingBuilder;

  /// Optional builder shown when preloading fails.
  final Widget Function(BuildContext context, PLYPresentationError error)?
      errorBuilder;

  // View type must match the one defined in the native side.
  static const String viewType = 'io.purchasely.purchasely_flutter/native_view';

  const PLYPresentationView({
    super.key,
    required this.request,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  State<PLYPresentationView> createState() => _PLYPresentationViewState();
}

class _PLYPresentationViewState extends State<PLYPresentationView> {
  PLYPresentation? _presentation;
  PLYPresentationError? _error;

  @override
  void initState() {
    super.initState();
    _preload();
  }

  Future<void> _preload() async {
    try {
      final presentation = await widget.request.preload();
      if (!mounted) return;
      setState(() => _presentation = presentation);
    } on PLYPresentationError catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = PLYPresentationError(message: e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return widget.errorBuilder?.call(context, error) ?? const SizedBox();
    }

    final presentation = _presentation;
    if (presentation == null) {
      return widget.loadingBuilder ??
          const Center(child: CircularProgressIndicator());
    }

    final creationParams = <String, dynamic>{
      'requestId': presentation.requestId,
    };

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Hybrid composition (the native view lives in the Android view
        // hierarchy) so touch events reach the embedded Purchasely paywall.
        // A plain virtual-display `AndroidView` does NOT reliably deliver taps
        // to the interactive paywall controls (close ✕, plan/purchase buttons),
        // which is why inline taps appeared to do nothing. The eager gesture
        // recognizer makes the platform view claim the gestures so Flutter does
        // not swallow them.
        return PlatformViewLink(
          viewType: PLYPresentationView.viewType,
          surfaceFactory: (context, controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer()),
              },
            );
          },
          onCreatePlatformView: (params) {
            final controller = PlatformViewsService.initExpensiveAndroidView(
              id: params.id,
              viewType: PLYPresentationView.viewType,
              layoutDirection:
                  Directionality.maybeOf(context) ?? TextDirection.ltr,
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
              onFocus: () => params.onFocusChanged(true),
            );
            controller
              ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
              ..create();
            return controller;
          },
        );
      case TargetPlatform.iOS:
        return SafeArea(
          child: UiKitView(
            viewType: PLYPresentationView.viewType,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
          ),
        );
      default:
        return Text('$defaultTargetPlatform is not supported yet.');
    }
  }
}
