import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import 'presentation.dart';

/// Builds the Flutter UI hosted for a Purchasely Custom Screen flow step.
typedef PLYCustomScreenBuilder = Widget Function(
  BuildContext context,
  PLYCustomScreenPresentation presentation,
);

/// A presentation handle bound to the exact native Custom Screen flow step.
class PLYCustomScreenPresentation extends PLYPresentation {
  PLYCustomScreenPresentation._(PLYPresentation presentation)
      : super(
          requestId: presentation.requestId,
          screenId: presentation.screenId,
          placementId: presentation.placementId,
          contentId: presentation.contentId,
          audienceId: presentation.audienceId,
          abTestId: presentation.abTestId,
          abTestVariantId: presentation.abTestVariantId,
          campaignId: presentation.campaignId,
          flowId: presentation.flowId,
          language: presentation.language,
          height: presentation.height,
          type: presentation.type,
          plans: presentation.plans,
          metadata: presentation.metadata,
          connections: presentation.connections,
          customScreenId: presentation.customScreenId,
        );

  factory PLYCustomScreenPresentation.fromMap(Map<dynamic, dynamic> map) {
    final presentation = PLYPresentation.fromMap(map);
    if (presentation.customScreenId == null) {
      throw const FormatException(
        'Custom Screen payload is missing customScreenId',
      );
    }
    return PLYCustomScreenPresentation._(presentation);
  }

  String get _id => customScreenId!;

  @override
  Future<void> execute([PLYConnection? connection]) => _invoke(
        'customScreenExecuteConnection',
        <String, Object?>{
          'customScreenId': _id,
          'connectionId': connection?.id,
        },
      );

  @override
  Future<void> back() => _invoke(
        'customScreenBack',
        <String, Object?>{'customScreenId': _id},
      );

  @override
  Future<void> close() => _invoke(
        'customScreenClose',
        <String, Object?>{'customScreenId': _id},
      );

  /// Sends a navigation call, treating a missing or already-torn-down native
  /// Custom Screen (e.g. the step was popped, or an engine/registry teardown
  /// race) as a benign no-op instead of surfacing an unhandled isolate error.
  Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await PurchaselyCustomScreens._channel.invokeMethod<void>(method, args);
    } on PlatformException catch (error) {
      debugPrint('Purchasely Custom Screen $method ignored: ${error.code}');
    } on MissingPluginException catch (_) {
      debugPrint('Purchasely Custom Screen $method ignored: no native handler');
    }
  }
}

/// Runtime used by the dedicated Dart entrypoint of a Custom Screen.
abstract final class PurchaselyCustomScreens {
  static const MethodChannel _channel =
      MethodChannel('purchasely-custom-screen');

  /// Starts the widget tree for one native Custom Screen flow step.
  ///
  /// The app entrypoint must accept the engine arguments and forward them:
  ///
  /// ```dart
  /// @pragma('vm:entry-point')
  /// void purchaselyCustomScreen(List<String> args) {
  ///   PurchaselyCustomScreens.run(args, (context, presentation) {
  ///     return MyCustomStep(presentation: presentation);
  ///   });
  /// }
  /// ```
  static void run(List<String> entrypointArgs, PLYCustomScreenBuilder builder) {
    WidgetsFlutterBinding.ensureInitialized();
    if (entrypointArgs.isEmpty || entrypointArgs.first.isEmpty) {
      runApp(const _CustomScreenError(
        message: 'Purchasely Custom Screen entrypoint received no id.',
      ));
      return;
    }
    runApp(_CustomScreenHost(
      customScreenId: entrypointArgs.first,
      builder: builder,
    ));
  }
}

class _CustomScreenHost extends StatefulWidget {
  const _CustomScreenHost({
    required this.customScreenId,
    required this.builder,
  });

  final String customScreenId;
  final PLYCustomScreenBuilder builder;

  @override
  State<_CustomScreenHost> createState() => _CustomScreenHostState();
}

class _CustomScreenHostState extends State<_CustomScreenHost> {
  late final Future<PLYCustomScreenPresentation> _presentation = _load();

  Future<PLYCustomScreenPresentation> _load() async {
    final raw = await PurchaselyCustomScreens._channel
        .invokeMapMethod<dynamic, dynamic>(
      'getCustomScreenPresentation',
      <String, Object?>{'customScreenId': widget.customScreenId},
    );
    if (raw == null) {
      throw StateError('The native Custom Screen is no longer available.');
    }
    return PLYCustomScreenPresentation.fromMap(raw);
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.fromView(
      view: View.of(context),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: FutureBuilder<PLYCustomScreenPresentation>(
          future: _presentation,
          builder: (context, snapshot) {
            final presentation = snapshot.data;
            if (presentation != null) {
              try {
                return widget.builder(context, presentation);
              } catch (error) {
                return ErrorWidget.withDetails(
                  message: 'Custom Screen builder failed: $error',
                );
              }
            }
            if (snapshot.hasError) {
              return _CustomScreenError(
                message: 'Unable to load Purchasely Custom Screen: '
                    '${snapshot.error}',
              );
            }
            return const SizedBox.expand();
          },
        ),
      ),
    );
  }
}

class _CustomScreenError extends StatelessWidget {
  const _CustomScreenError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Text(message)),
      );
}
