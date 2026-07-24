// Purchasely SDK — Loaded presentation handle.
//
// A `PLYPresentation` is what the SDK returns once a `PLYPresentationRequest` has
// been preloaded (or displayed). It carries metadata about the screen and
// exposes mutable callbacks the host app can reassign after preload.

import 'dart:async';

import 'presentation_outcome.dart';
import 'transition.dart';

/// Kind of presentation returned by the backend.
enum PLYPresentationType { normal, fallback, deactivated, client }

PLYPresentationType _typeFromInt(int? raw) {
  if (raw == null || raw < 0 || raw >= PLYPresentationType.values.length) {
    return PLYPresentationType.normal;
  }
  return PLYPresentationType.values[raw];
}

/// Plan summary embedded in a presentation payload.
class PLYPresentationPlan {
  final String? planVendorId;
  final String? storeProductId;
  final String? basePlanId;
  final String? offerId;

  const PLYPresentationPlan({
    this.planVendorId,
    this.storeProductId,
    this.basePlanId,
    this.offerId,
  });

  factory PLYPresentationPlan.fromMap(Map<dynamic, dynamic> map) {
    return PLYPresentationPlan(
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

/// A named exit from a Purchasely Custom Screen.
class PLYConnection {
  /// Connection vendor id configured in the Purchasely Console.
  final String? id;

  /// Whether this is the presentation's default connection.
  ///
  /// The current iOS SDK does not expose this flag publicly, so it is `false`
  /// on iOS until that native API is available. Calling [PLYPresentation.execute]
  /// without a connection still executes the native default on both platforms.
  final bool isDefault;

  const PLYConnection({this.id, this.isDefault = false});

  factory PLYConnection.fromMap(Map<dynamic, dynamic> map) => PLYConnection(
        id: map['id'] as String?,
        isDefault: map['isDefault'] as bool? ?? false,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'isDefault': isDefault,
      };
}

/// Indirection used by [PLYPresentation.display] / [close] / [back] so the
/// public API can defer to the bridge without creating a circular import.
abstract class PLYPresentationActions {
  /// Singleton wired up by `bridge.dart` once the package is initialised.
  static PLYPresentationActions instance = _UninitialisedActions();

  Future<PLYPresentationOutcome> display(
      PLYPresentation presentation, PLYTransition? transition);
  Future<void> close(PLYPresentation presentation);
  Future<void> back(PLYPresentation presentation);
  Future<void> execute(PLYPresentation presentation, PLYConnection? connection);
}

class _UninitialisedActions extends PLYPresentationActions {
  StateError _err() => StateError(
      'Purchasely bridge not initialised — call any presentation entry point first.');

  @override
  Future<PLYPresentationOutcome> display(_, __) => throw _err();
  @override
  Future<void> close(_) => throw _err();
  @override
  Future<void> back(_) => throw _err();
  @override
  Future<void> execute(_, __) => throw _err();
}

/// A loaded presentation. Returned from `PLYPresentationRequest.preload()` and
/// embedded in [PLYPresentationOutcome.presentation] at dismiss time.
///
/// Callbacks ([onPresented], [onCloseRequested], [onDismissed]) are mutable
/// so the host app can reassign them between preload and display.
class PLYPresentation {
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
  final PLYPresentationType type;
  final List<PLYPresentationPlan> plans;
  final Map<String, dynamic> metadata;
  final List<PLYConnection> connections;

  /// Internal id used only while this presentation is hosted as a Custom
  /// Screen inside a native Purchasely flow.
  final String? customScreenId;

  /// Optional pre-loaded handler — fires once when the presentation has been
  /// shown for the first time (or with an error if display failed).
  void Function(PLYPresentation? presentation, PLYPresentationError? error)?
      onPresented;

  /// Optional close-requested handler — fires when the user taps the native
  /// close button (or system back on Android). Does not fire when the
  /// presentation is dismissed programmatically.
  void Function()? onCloseRequested;

  /// Optional dismiss handler — fires when the presentation is fully
  /// dismissed (whatever the reason). Receives the full outcome.
  void Function(PLYPresentationOutcome outcome)? onDismissed;

  PLYPresentation({
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
    this.type = PLYPresentationType.normal,
    this.plans = const [],
    this.metadata = const {},
    this.connections = const [],
    this.customScreenId,
    this.onPresented,
    this.onCloseRequested,
    this.onDismissed,
  });

  /// Builds a [PLYPresentation] from the wire map sent by the native bridge.
  ///
  /// Tolerant of either wire format (`screenId` or `id`). The iOS bridge maps
  /// `id` -> `screenId` once at the SDK boundary; this fallback keeps the
  /// Dart-side parsing resilient.
  factory PLYPresentation.fromMap(Map<dynamic, dynamic> map) {
    final plansList = (map['plans'] as List?)
            ?.whereType<Map>()
            .map((e) => PLYPresentationPlan.fromMap(e))
            .toList() ??
        const <PLYPresentationPlan>[];

    final metadata = <String, dynamic>{};
    (map['metadata'] as Map?)?.forEach((key, value) {
      if (key is String) metadata[key] = value;
    });

    final connections = (map['connections'] as List?)
            ?.whereType<Map>()
            .map(PLYConnection.fromMap)
            .toList() ??
        const <PLYConnection>[];

    final rawType = map['type'];
    final typeIndex = rawType is int
        ? rawType
        : rawType is String
            ? _typeIndexFromString(rawType)
            : null;

    return PLYPresentation(
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
      connections: connections,
      customScreenId: map['customScreenId'] as String?,
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
        'connections':
            connections.map((connection) => connection.toMap()).toList(),
        if (customScreenId != null) 'customScreenId': customScreenId,
      };

  /// Re-display the presentation (matches `display()` on the native SDKs).
  ///
  /// The returned future completes at dismiss time with the final outcome.
  Future<PLYPresentationOutcome> display([PLYTransition? transition]) =>
      PLYPresentationActions.instance.display(this, transition);

  /// Close the presentation programmatically (matches `close()` on Android).
  Future<void> close() => PLYPresentationActions.instance.close(this);

  /// Navigate to the previous flow step or dismiss the current one
  /// (matches `back()` on Android).
  Future<void> back() => PLYPresentationActions.instance.back(this);

  /// Executes a connection's configured actions. Passing no connection asks
  /// the native SDK to execute the presentation's default connection.
  Future<void> execute([PLYConnection? connection]) =>
      PLYPresentationActions.instance.execute(this, connection);
}

/// Convenience extension so a preload future can be chained directly to display:
/// `await request.preload().display(const PLYTransition.drawer(...))`.
extension FuturePresentationDisplay on Future<PLYPresentation> {
  Future<PLYPresentationOutcome> display([PLYTransition? transition]) =>
      then((p) => p.display(transition));
}
