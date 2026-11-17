// Purchasely SDK — PLYPresentation transitions.

/// Display transition type for a presentation.
enum PLYTransitionType {
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
class PLYTransitionColors {
  /// Hex color (e.g. `#000000`) used in light mode.
  final String? light;

  /// Hex color used in dark mode.
  final String? dark;

  const PLYTransitionColors({this.light, this.dark});

  Map<String, Object?> toMap() => {
        if (light != null) 'light': light,
        if (dark != null) 'dark': dark,
      };
}

/// Display transition for a presentation (`PLYPresentationRequest.display(...)`).
///
/// [width] (popin only) and [height] (drawer + popin) size the surface via the
/// native dimension model — see [PLYTransitionDimension]. [dismissible]
/// defaults to `true` on the native side.
class PLYTransition {
  final PLYTransitionType type;
  final PLYTransitionDimension? width;
  final PLYTransitionDimension? height;
  final bool? dismissible;
  final PLYTransitionColors? backgroundColors;

  const PLYTransition({
    required this.type,
    this.width,
    this.height,
    this.dismissible,
    this.backgroundColors,
  });

  const PLYTransition.fullScreen() : this(type: PLYTransitionType.fullScreen);
  const PLYTransition.modal({bool? dismissible})
      : this(type: PLYTransitionType.modal, dismissible: dismissible);
  const PLYTransition.push() : this(type: PLYTransitionType.push);
  const PLYTransition.drawer({
    PLYTransitionDimension? height,
    bool? dismissible,
    PLYTransitionColors? backgroundColors,
  }) : this(
          type: PLYTransitionType.drawer,
          height: height,
          dismissible: dismissible,
          backgroundColors: backgroundColors,
        );
  const PLYTransition.popin({
    PLYTransitionDimension? width,
    PLYTransitionDimension? height,
    bool? dismissible,
    PLYTransitionColors? backgroundColors,
  }) : this(
          type: PLYTransitionType.popin,
          width: width,
          height: height,
          dismissible: dismissible,
          backgroundColors: backgroundColors,
        );

  Map<String, Object?> toMap() => {
        'type': _typeToWire(type),
        if (width != null) 'width': width!.toMap(),
        if (height != null) 'height': height!.toMap(),
        if (dismissible != null) 'dismissible': dismissible,
        if (backgroundColors != null)
          'backgroundColors': backgroundColors!.toMap(),
      };

  static String _typeToWire(PLYTransitionType t) {
    switch (t) {
      case PLYTransitionType.fullScreen:
        return 'fullScreen';
      case PLYTransitionType.push:
        return 'push';
      case PLYTransitionType.modal:
        return 'modal';
      case PLYTransitionType.drawer:
        return 'drawer';
      case PLYTransitionType.popin:
        return 'popin';
      case PLYTransitionType.inlinePaywall:
        return 'inlinePaywall';
    }
  }
}
