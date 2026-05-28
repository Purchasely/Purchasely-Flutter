// Purchasely SDK v6 — Fluent builder for `PresentationRequest`.

import 'presentation.dart';
import 'presentation_outcome.dart';
import 'presentation_request.dart';
import 'request_id.dart';

/// Fluent builder for a [PresentationRequest].
///
/// Pick a source via [PresentationBuilder.placement], [.screen] or
/// [.defaultSource], then chain configuration and callbacks, then [.build].
///
/// Example:
/// ```dart
/// final outcome = await PresentationBuilder
///     .placement('home_screen')
///     .contentId('article-42')
///     .onPresented((p, err) => print('shown'))
///     .onDismissed((outcome) => print('dismissed: ${outcome.purchaseResult}'))
///     .build()
///     .display(const Transition.modal());
/// ```
class PresentationBuilder {
  PresentationSource _source;
  String? _contentId;
  String? _backgroundColorHex;
  String? _progressColorHex;
  bool? _displayCloseButton;
  bool? _displayBackButton;

  void Function(Presentation presentation, PresentationError? error)? _onLoaded;
  void Function(Presentation? presentation, PresentationError? error)?
      _onPresented;
  void Function()? _onCloseRequested;
  void Function(PresentationOutcome outcome)? _onDismissed;

  PresentationBuilder._(this._source);

  /// Source the presentation from a placement id.
  static PresentationBuilder placement(String placementId) =>
      PresentationBuilder._(PresentationSource.placement(placementId));

  /// Source the presentation from a specific screen id (`presentation.id` on
  /// iOS, `presentation.screenId` on Android).
  static PresentationBuilder screen(String screenId) =>
      PresentationBuilder._(PresentationSource.screen(screenId));

  /// Source the default presentation.
  static PresentationBuilder defaultSource() =>
      PresentationBuilder._(const PresentationSource.defaultSource());

  PresentationBuilder contentId(String? id) {
    _contentId = id;
    return this;
  }

  /// Background color of the loading screen, as a hex string (e.g. `#000000`).
  PresentationBuilder backgroundColor(String? hex) {
    _backgroundColorHex = hex;
    return this;
  }

  /// Progress / spinner color, as a hex string (e.g. `#FFFFFF`).
  PresentationBuilder progressColor(String? hex) {
    _progressColorHex = hex;
    return this;
  }

  /// Whether the SDK should render its close button.
  /// Android only at the moment — no-op on iOS.
  PresentationBuilder displayCloseButton(bool show) {
    _displayCloseButton = show;
    return this;
  }

  /// Whether the SDK should render its back button.
  /// Android only at the moment — no-op on iOS.
  PresentationBuilder displayBackButton(bool show) {
    _displayBackButton = show;
    return this;
  }

  PresentationBuilder onLoaded(
      void Function(Presentation presentation, PresentationError? error)
          handler) {
    _onLoaded = handler;
    return this;
  }

  PresentationBuilder onPresented(
      void Function(Presentation? presentation, PresentationError? error)
          handler) {
    _onPresented = handler;
    return this;
  }

  PresentationBuilder onCloseRequested(void Function() handler) {
    _onCloseRequested = handler;
    return this;
  }

  PresentationBuilder onDismissed(
      void Function(PresentationOutcome outcome) handler) {
    _onDismissed = handler;
    return this;
  }

  /// Build the immutable [PresentationRequest]. A stable [requestId] is
  /// generated for the bridge to route events back.
  PresentationRequest build() {
    return PresentationRequest(
      requestId: nextRequestId(),
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
