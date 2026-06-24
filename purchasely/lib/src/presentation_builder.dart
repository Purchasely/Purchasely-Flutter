// Purchasely SDK — Fluent builder for `PLYPresentationRequest`.

import 'dart:math';

import 'bridge.dart';
import 'presentation.dart';
import 'presentation_outcome.dart';
import 'presentation_request.dart';

final _rand = Random.secure();

/// Returns a 128-bit hex identifier suitable for cross-isolate routing.
///
/// The cross-platform contract uses a `requestId` for every
/// [PLYPresentationRequest] so events and lifecycle calls can be routed back from
/// native to Dart.
String _nextRequestId() {
  final buf = StringBuffer('ply_');
  for (var i = 0; i < 4; i++) {
    buf.write(_rand.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0'));
  }
  return buf.toString();
}

/// Fluent builder for a [PLYPresentationRequest].
///
/// Pick a source via [PLYPresentationBuilder.placement], [.screen] or
/// [.defaultSource], then chain configuration and callbacks, then [.build].
///
/// Example:
/// ```dart
/// final outcome = await PLYPresentationBuilder
///     .placement('home_screen')
///     .contentId('article-42')
///     .onPresented((p, err) => print('shown'))
///     .onDismissed((outcome) => print('dismissed: ${outcome.purchaseResult}'))
///     .build()
///     .display(const PLYTransition.modal());
/// ```
class PLYPresentationBuilder {
  final PLYPresentationSource _source;
  String? _contentId;
  String? _backgroundColorHex;
  String? _progressColorHex;
  bool? _displayCloseButton;
  bool? _displayBackButton;

  void Function(PLYPresentation presentation, PLYPresentationError? error)?
      _onLoaded;
  void Function(PLYPresentation? presentation, PLYPresentationError? error)?
      _onPresented;
  void Function()? _onCloseRequested;
  void Function(PLYPresentationOutcome outcome)? _onDismissed;

  PLYPresentationBuilder._(this._source);

  /// Source the presentation from a placement id.
  static PLYPresentationBuilder placement(String placementId) =>
      PLYPresentationBuilder._(PLYPresentationSource.placement(placementId));

  /// Source the presentation from a specific screen id (`presentation.id` on
  /// iOS, `presentation.screenId` on Android).
  static PLYPresentationBuilder screen(String screenId) =>
      PLYPresentationBuilder._(PLYPresentationSource.screen(screenId));

  /// Source the default presentation.
  static PLYPresentationBuilder defaultSource() =>
      PLYPresentationBuilder._(const PLYPresentationSource.defaultSource());

  PLYPresentationBuilder contentId(String? id) {
    _contentId = id;
    return this;
  }

  /// Background color of the loading screen, as a hex string (e.g. `#000000`).
  PLYPresentationBuilder backgroundColor(String? hex) {
    _backgroundColorHex = hex;
    return this;
  }

  /// Progress / spinner color, as a hex string (e.g. `#FFFFFF`).
  PLYPresentationBuilder progressColor(String? hex) {
    _progressColorHex = hex;
    return this;
  }

  /// Whether the SDK should render its close button.
  /// Android only at the moment — no-op on iOS.
  PLYPresentationBuilder displayCloseButton(bool show) {
    _displayCloseButton = show;
    return this;
  }

  /// Whether the SDK should render its back button.
  /// Android only at the moment — no-op on iOS.
  PLYPresentationBuilder displayBackButton(bool show) {
    _displayBackButton = show;
    return this;
  }

  PLYPresentationBuilder onLoaded(
      void Function(PLYPresentation presentation, PLYPresentationError? error)
          handler) {
    _onLoaded = handler;
    return this;
  }

  PLYPresentationBuilder onPresented(
      void Function(PLYPresentation? presentation, PLYPresentationError? error)
          handler) {
    _onPresented = handler;
    return this;
  }

  PLYPresentationBuilder onCloseRequested(void Function() handler) {
    _onCloseRequested = handler;
    return this;
  }

  PLYPresentationBuilder onDismissed(
      void Function(PLYPresentationOutcome outcome) handler) {
    _onDismissed = handler;
    return this;
  }

  /// Build the immutable [PLYPresentationRequest]. A stable [requestId] is
  /// generated for the bridge to route events back.
  PLYPresentationRequest build() {
    // Lazy install of the dispatcher so any presentation entry point
    // initialises it, not just PurchaselyBuilder.start().
    PurchaselyBridge.ensureInstalled();
    return PLYPresentationRequest(
      requestId: _nextRequestId(),
      source: _source,
      contentId: _contentId,
      backgroundColorHex: _backgroundColorHex,
      progressColorHex: _progressColorHex,
      displayCloseButton: _displayCloseButton,
      displayBackButton: _displayBackButton,
      onLoaded: _onLoaded,
      onPresented: _onPresented,
      onCloseRequested: _onCloseRequested,
      onDismissed: _onDismissed,
    );
  }
}
