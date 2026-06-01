import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/presentation.dart';
import 'src/presentation_outcome.dart';
import 'src/presentation_request.dart';

/// Renders a Purchasely presentation inline (embedded) inside the Flutter
/// widget tree, as opposed to a full-screen / modal presentation.
///
/// The widget preloads the supplied [PresentationRequest] to obtain a stable
/// `requestId`, then hands that id to the native platform view through the
/// `{ "requestId": <id> }` creation params. The native side resolves the
/// preloaded presentation from that id and renders it inline.
///
/// Lifecycle: the embedded (inline) path surfaces its dismissal/outcome through
/// the same `purchasely-presentation-events` channel as a full-screen
/// presentation, keyed by `requestId`. When the inline presentation is
/// dismissed, the native view emits the same `onDismissed` envelope (with the
/// `display()`-style [PresentationOutcome]) as the modal path, so the request's
/// [PresentationRequest.onDismissed] callback fires for the inline view too.
class PLYPresentationView extends StatefulWidget {
  /// The presentation request to render inline. Build it with
  /// `PresentationBuilder.placement(...)...build()`.
  final PresentationRequest request;

  /// Optional widget shown while the presentation is preloading.
  final Widget? loadingBuilder;

  /// Optional builder shown when preloading fails.
  final Widget Function(BuildContext context, PresentationError error)?
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
  Presentation? _presentation;
  PresentationError? _error;

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
    } on PresentationError catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = PresentationError(message: e.toString()));
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
        return AndroidView(
          viewType: PLYPresentationView.viewType,
          layoutDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
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
