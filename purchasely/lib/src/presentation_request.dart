// Purchasely SDK — Presentation request (lifecycle handle).

import 'dart:async';

import 'presentation.dart';
import 'presentation_outcome.dart';
import 'transition.dart';

/// Indirection used by [PresentationRequest.preload] / [display] so the
/// public API can defer to the bridge without creating a circular import.
abstract class PresentationRequestActions {
  static PresentationRequestActions instance = _UninitialisedRequest();

  Future<Presentation> preload(PresentationRequest request);
  Future<PresentationOutcome> display(
      PresentationRequest request, Transition? transition);
}

class _UninitialisedRequest extends PresentationRequestActions {
  StateError _err() => StateError(
      'Purchasely bridge not initialised — call any presentation entry point first.');

  @override
  Future<Presentation> preload(_) => throw _err();
  @override
  Future<PresentationOutcome> display(_, __) => throw _err();
}

/// Internal source kind used when constructing a request.
enum PresentationSourceKind { defaultSource, placementId, screenId }

class PresentationSource {
  final PresentationSourceKind kind;
  final String? id;

  const PresentationSource._(this.kind, this.id);

  const PresentationSource.defaultSource()
      : this._(PresentationSourceKind.defaultSource, null);
  const PresentationSource.placement(String id)
      : this._(PresentationSourceKind.placementId, id);
  const PresentationSource.screen(String id)
      : this._(PresentationSourceKind.screenId, id);

  Map<String, Object?> toMap() => {
        'kind': kind.name,
        if (id != null) 'id': id,
      };
}

/// A configured presentation, ready to be preloaded or displayed.
///
/// Build one through [PresentationBuilder] (in `presentation_builder.dart`).
///
/// Calling [preload] fetches the presentation from the backend without
/// presenting it. Calling [display] both fetches it (if not preloaded) and
/// shows it; the returned future completes at dismiss time with the final
/// [PresentationOutcome].
class PresentationRequest {
  /// Stable identifier shared between Dart and the native bridge so that
  /// callbacks and `close()` calls can be routed back to the right native
  /// request instance.
  final String requestId;
  final PresentationSource source;
  final String? contentId;
  final String? backgroundColorHex;
  final String? progressColorHex;
  final bool? displayCloseButton;
  final bool? displayBackButton;

  /// Builder-seeded handlers. The bridge wires them to the native callback
  /// events. They are copied onto the loaded [Presentation] once preload
  /// completes so the host app can also reassign them post-preload.
  final void Function(Presentation presentation, PresentationError? error)?
      onLoaded;
  final void Function(Presentation? presentation, PresentationError? error)?
      onPresented;
  final void Function()? onCloseRequested;
  final void Function(PresentationOutcome outcome)? onDismissed;

  PresentationRequest({
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
  /// the loaded [Presentation] once the network round-trip completes.
  Future<Presentation> preload() =>
      PresentationRequestActions.instance.preload(this);

  /// Fetch (if needed) and display the presentation. The returned future
  /// completes at dismiss time with the final [PresentationOutcome].
  Future<PresentationOutcome> display([Transition? transition]) =>
      PresentationRequestActions.instance.display(this, transition);
}
