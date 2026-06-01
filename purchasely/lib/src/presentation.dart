// Purchasely SDK — Loaded presentation handle.
//
// A `Presentation` is what the SDK returns once a `PresentationRequest` has
// been preloaded (or displayed). It carries metadata about the screen and
// exposes mutable callbacks the host app can reassign after preload.

import 'dart:async';

import 'presentation_outcome.dart';
import 'transition.dart';

/// Kind of presentation returned by the backend.
enum PresentationType { normal, fallback, deactivated, client }

PresentationType _typeFromInt(int? raw) {
  if (raw == null || raw < 0 || raw >= PresentationType.values.length) {
    return PresentationType.normal;
  }
  return PresentationType.values[raw];
}

/// Plan summary embedded in a presentation payload.
class PresentationPlan {
  final String? planVendorId;
  final String? storeProductId;
  final String? basePlanId;
  final String? offerId;

  const PresentationPlan({
    this.planVendorId,
    this.storeProductId,
    this.basePlanId,
    this.offerId,
  });

  factory PresentationPlan.fromMap(Map<dynamic, dynamic> map) {
    return PresentationPlan(
      planVendorId: map['planVendorId'] as String?,
      storeProductId: map['storeProductId'] as String?,
      basePlanId: map['basePlanId'] as String?,
      offerId: map['offerId'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
        'planVendorId': planVendorId,
        'storeProductId': storeProductId,
        'basePlanId': basePlanId,
        'offerId': offerId,
      };
}

/// Indirection used by [Presentation.display] / [close] / [back] so the
/// public API can defer to the bridge without creating a circular import.
abstract class PresentationActions {
  /// Singleton wired up by `bridge.dart` once the package is initialised.
  static PresentationActions instance = _UninitialisedActions();

  Future<PresentationOutcome> display(
      Presentation presentation, Transition? transition);
  Future<void> close(Presentation presentation);
  Future<void> back(Presentation presentation);
}

class _UninitialisedActions extends PresentationActions {
  StateError _err() => StateError(
      'Purchasely bridge not initialised — call any presentation entry point first.');

  @override
  Future<PresentationOutcome> display(_, __) => throw _err();
  @override
  Future<void> close(_) => throw _err();
  @override
  Future<void> back(_) => throw _err();
}

/// A loaded presentation. Returned from `PresentationRequest.preload()` and
/// embedded in [PresentationOutcome.presentation] at dismiss time.
///
/// Callbacks ([onPresented], [onCloseRequested], [onDismissed]) are mutable
/// so the host app can reassign them between preload and display.
class Presentation {
  /// Internal request identifier used by the bridge to route subsequent calls
  /// (close/back/display) back to the right native request.
  final String requestId;

  /// Public identifier of the screen (aka Purchasely "presentation"). Maps to
  /// `presentation.id` on iOS until the iOS native API exposes `screenId`.
  final String? screenId;

  final String? placementId;
  final String? contentId;
  final String? audienceId;
  final String? abTestId;
  final String? abTestVariantId;
  final String? campaignId;
  final String? flowId;
  final String? language;
  final int height;
  final PresentationType type;
  final List<PresentationPlan> plans;
  final Map<String, dynamic> metadata;

  /// Optional pre-loaded handler — fires once when the presentation has been
  /// shown for the first time (or with an error if display failed).
  void Function(Presentation? presentation, PresentationError? error)?
      onPresented;

  /// Optional close-requested handler — fires when the user taps the native
  /// close button (or system back on Android). Does not fire when the
  /// presentation is dismissed programmatically.
  void Function()? onCloseRequested;

  /// Optional dismiss handler — fires when the presentation is fully
  /// dismissed (whatever the reason). Receives the full outcome.
  void Function(PresentationOutcome outcome)? onDismissed;

  Presentation({
    required this.requestId,
    this.screenId,
    this.placementId,
    this.contentId,
    this.audienceId,
    this.abTestId,
    this.abTestVariantId,
    this.campaignId,
    this.flowId,
    this.language,
    this.height = 0,
    this.type = PresentationType.normal,
    this.plans = const [],
    this.metadata = const {},
    this.onPresented,
    this.onCloseRequested,
    this.onDismissed,
  });

  /// Builds a [Presentation] from the wire map sent by the native bridge.
  ///
  /// Tolerant of either wire format (`screenId` or `id`). The iOS bridge maps
  /// `id` -> `screenId` once at the SDK boundary; this fallback keeps the
  /// Dart-side parsing resilient.
  factory Presentation.fromMap(Map<dynamic, dynamic> map) {
    final plansList = (map['plans'] as List?)
            ?.whereType<Map>()
            .map((e) => PresentationPlan.fromMap(e))
            .toList() ??
        const <PresentationPlan>[];

    final metadata = <String, dynamic>{};
    (map['metadata'] as Map?)?.forEach((key, value) {
      if (key is String) metadata[key] = value;
    });

    final rawType = map['type'];
    final typeIndex = rawType is int
        ? rawType
        : rawType is String
            ? _typeIndexFromString(rawType)
            : null;

    return Presentation(
      requestId: map['requestId'] as String? ?? '',
      screenId: (map['screenId'] ?? map['id']) as String?,
      placementId: map['placementId'] as String?,
      contentId: map['contentId'] as String?,
      audienceId: map['audienceId'] as String?,
      abTestId: map['abTestId'] as String?,
      abTestVariantId: map['abTestVariantId'] as String?,
      campaignId: map['campaignId'] as String?,
      flowId: map['flowId'] as String?,
      language: map['language'] as String?,
      height: (map['height'] as num?)?.toInt() ?? 0,
      type: _typeFromInt(typeIndex),
      plans: plansList,
      metadata: metadata,
    );
  }

  static int? _typeIndexFromString(String value) {
    switch (value.toLowerCase()) {
      case 'normal':
        return 0;
      case 'fallback':
        return 1;
      case 'deactivated':
        return 2;
      case 'client':
        return 3;
      default:
        return null;
    }
  }

  Map<String, Object?> toMap() => {
        'requestId': requestId,
        'screenId': screenId,
        'placementId': placementId,
        'contentId': contentId,
        'audienceId': audienceId,
        'abTestId': abTestId,
        'abTestVariantId': abTestVariantId,
        'campaignId': campaignId,
        'flowId': flowId,
        'language': language,
        'height': height,
        'type': type.index,
        'plans': plans.map((p) => p.toMap()).toList(),
        'metadata': metadata,
      };

  /// Re-display the presentation (matches `display()` on the native SDKs).
  ///
  /// The returned future completes at dismiss time with the final outcome.
  Future<PresentationOutcome> display([Transition? transition]) =>
      PresentationActions.instance.display(this, transition);

  /// Close the presentation programmatically (matches `close()` on Android).
  Future<void> close() => PresentationActions.instance.close(this);

  /// Navigate to the previous flow step or dismiss the current one
  /// (matches `back()` on Android).
  Future<void> back() => PresentationActions.instance.back(this);
}
