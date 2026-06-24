// Purchasely SDK — Presentation transitions.

/// Display transition type for a presentation.
enum TransitionType {
  fullScreen,
  push,
  modal,
  drawer,
  popin,
  inlinePaywall,
}

/// Unit a [PLYTransitionDimension] value is expressed in. Mirrors the native
/// Android `PLYDimensionType` ( `pixel` / `percentage` ).
enum PLYDimensionType { pixel, percentage }

/// A single transition dimension (width or height), expressed either as a
/// fixed size in density-independent pixels ([PLYDimensionType.pixel]) or as a
/// ratio of the available screen dimension ([PLYDimensionType.percentage],
/// `0.0`–`1.0`).
///
/// Mirrors the native `PLYTransitionDimension` (Android) / `PLYDimension`
/// (iOS) used for `drawer`/`popin` sizing. Serializes to
/// `{ 'type': 'pixel' | 'percentage', 'value': <double> }`.
class PLYTransitionDimension {
  final PLYDimensionType type;
  final double value;

  const PLYTransitionDimension({required this.type, required this.value});

  /// Fixed size in density-independent pixels.
  const PLYTransitionDimension.pixel(this.value)
      : type = PLYDimensionType.pixel;

  /// Ratio of the available screen dimension, in `0.0`–`1.0`.
  const PLYTransitionDimension.percentage(this.value)
      : type = PLYDimensionType.percentage;

  Map<String, Object?> toMap() => {
        'type': type == PLYDimensionType.pixel ? 'pixel' : 'percentage',
        'value': value,
      };
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
/// [width] (popin only) and [height] (drawer + popin) size the surface via the
/// native dimension model — see [PLYTransitionDimension]. [dismissible]
/// defaults to `true` on the native side.
class Transition {
  final TransitionType type;
  final PLYTransitionDimension? width;
  final PLYTransitionDimension? height;
  final bool? dismissible;
  final TransitionColors? backgroundColors;

  const Transition({
    required this.type,
    this.width,
    this.height,
    this.dismissible,
    this.backgroundColors,
  });

  const Transition.fullScreen() : this(type: TransitionType.fullScreen);
  const Transition.modal({bool? dismissible})
      : this(type: TransitionType.modal, dismissible: dismissible);
  const Transition.push() : this(type: TransitionType.push);

  Map<String, Object?> toMap() => {
        'type': _typeToWire(type),
        if (width != null) 'width': width!.toMap(),
        if (height != null) 'height': height!.toMap(),
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
