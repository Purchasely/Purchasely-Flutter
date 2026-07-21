// Purchasely SDK — PLYPresentation request (lifecycle handle).

import 'dart:async';

import 'presentation.dart';
import 'presentation_outcome.dart';
import 'transition.dart';

/// Indirection used by [PLYPresentationRequest.preload] / [display] so the
/// public API can defer to the bridge without creating a circular import.
abstract class PLYPresentationRequestActions {
  static PLYPresentationRequestActions instance = _UninitialisedRequest();

  Future<PLYPresentation> preload(PLYPresentationRequest request);
  Future<PLYPresentationOutcome> display(
      PLYPresentationRequest request, PLYTransition? transition);
}

class _UninitialisedRequest extends PLYPresentationRequestActions {
  StateError _err() => StateError(
      'Purchasely bridge not initialised — call any presentation entry point first.');

  @override
  Future<PLYPresentation> preload(_) => throw _err();
  @override
  Future<PLYPresentationOutcome> display(_, __) => throw _err();
}

/// Internal source kind used when constructing a request.
enum PLYPresentationSourceKind { defaultSource, placementId, screenId }

class PLYPresentationSource {
  final PLYPresentationSourceKind kind;
  final String? id;

  const PLYPresentationSource._(this.kind, this.id);

  const PLYPresentationSource.defaultSource()
      : this._(PLYPresentationSourceKind.defaultSource, null);
  const PLYPresentationSource.placement(String id)
      : this._(PLYPresentationSourceKind.placementId, id);
  const PLYPresentationSource.screen(String id)
      : this._(PLYPresentationSourceKind.screenId, id);

  Map<String, Object?> toMap() => {
        'kind': kind.name,
        if (id != null) 'id': id,
      };
}

/// A configured presentation, ready to be preloaded or displayed.
///
/// Build one through [PLYPresentationBuilder] (in `presentation_builder.dart`).
///
/// Calling [preload] fetches the presentation from the backend without
/// presenting it. Calling [display] both fetches it (if not preloaded) and
/// shows it; the returned future completes at dismiss time with the final
/// [PLYPresentationOutcome].
class PLYPresentationRequest {
  /// Stable identifier shared between Dart and the native bridge so that
  /// callbacks and `close()` calls can be routed back to the right native
  /// request instance.
  final String requestId;
  final PLYPresentationSource source;
  final String? contentId;
  final String? backgroundColorHex;
  final String? progressColorHex;
  final bool? displayCloseButton;
  final bool? displayBackButton;

  /// Builder-seeded handlers. The bridge wires them to the native callback
  /// events. They are copied onto the loaded [PLYPresentation] once preload
  /// completes so the host app can also reassign them post-preload.
  final void Function(
      PLYPresentation presentation, PLYPresentationError? error)? onLoaded;
  final void Function(
      PLYPresentation? presentation, PLYPresentationError? error)? onPresented;
  final void Function()? onCloseRequested;
  final void Function(PLYPresentationOutcome outcome)? onDismissed;

  PLYPresentationRequest({
    required this.requestId,
    required this.source,
    this.contentId,
    this.backgroundColorHex,
    this.progressColorHex,
    this.displayCloseButton,
    this.displayBackButton,
    this.onLoaded,
    this.onPresented,
    this.onCloseRequested,
    this.onDismissed,
  });

  Map<String, Object?> toMap() => {
        'requestId': requestId,
        'source': source.toMap(),
        if (contentId != null) 'contentId': contentId,
        if (backgroundColorHex != null) 'backgroundColor': backgroundColorHex,
        if (progressColorHex != null) 'progressColor': progressColorHex,
        if (displayCloseButton != null)
          'displayCloseButton': displayCloseButton,
        if (displayBackButton != null) 'displayBackButton': displayBackButton,
      };

  /// Fetch and cache the presentation without displaying it. Resolves with
  /// the loaded [PLYPresentation] once the network round-trip completes.
  Future<PLYPresentation> preload() =>
      PLYPresentationRequestActions.instance.preload(this);

  /// Fetch (if needed) and display the presentation. The returned future
  /// completes at dismiss time with the final [PLYPresentationOutcome].
  Future<PLYPresentationOutcome> display([PLYTransition? transition]) =>
      PLYPresentationRequestActions.instance.display(this, transition);
}
