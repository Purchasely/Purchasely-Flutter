// Purchasely SDK v6 — Presentation transitions.

/// Display transition type for a presentation.
enum TransitionType {
  fullScreen,
  push,
  modal,
  drawer,
  popin,
  inlinePaywall,
}

/// Background color configuration for a transition.
class TransitionColors {
  /// Hex color (e.g. `#000000`) used in light mode.
  final String? light;

  /// Hex color used in dark mode.
  final String? dark;

  const TransitionColors({this.light, this.dark});

  Map<String, Object?> toMap() => {
        if (light != null) 'light': light,
        if (dark != null) 'dark': dark,
      };
}

/// Display transition for a presentation (`PresentationRequest.display(...)`).
///
/// [heightPercentage] is used for `drawer` and `popin` transitions (0..1).
/// [dismissible] defaults to `true`.
class Transition {
  final TransitionType type;
  final double? heightPercentage;
  final bool? dismissible;
  final TransitionColors? backgroundColors;

  const Transition({
    required this.type,
    this.heightPercentage,
    this.dismissible,
    this.backgroundColors,
  });

  const Transition.fullScreen() : this(type: TransitionType.fullScreen);
  const Transition.modal({bool? dismissible})
      : this(type: TransitionType.modal, dismissible: dismissible);
  const Transition.push() : this(type: TransitionType.push);

  Map<String, Object?> toMap() => {
        'type': _typeToWire(type),
        if (heightPercentage != null) 'heightPercentage': heightPercentage,
        if (dismissible != null) 'dismissible': dismissible,
        if (backgroundColors != null)
          'backgroundColors': backgroundColors!.toMap(),
      };

  static String _typeToWire(TransitionType t) {
    switch (t) {
      case TransitionType.fullScreen:
        return 'fullScreen';
      case TransitionType.push:
        return 'push';
      case TransitionType.modal:
        return 'modal';
      case TransitionType.drawer:
        return 'drawer';
      case TransitionType.popin:
        return 'popin';
      case TransitionType.inlinePaywall:
        return 'inlinePaywall';
    }
  }
}
