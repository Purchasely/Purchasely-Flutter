import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';
import 'package:purchasely_flutter/native_view_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PLYPresentationView', () {
    const methodChannelName = 'purchasely';
    const eventChannelName = 'purchasely-presentation-events';
    late TestDefaultBinaryMessenger messenger;

    setUp(() {
      messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      messenger.setMockMethodCallHandler(
        const MethodChannel(methodChannelName),
        (call) async {
          switch (call.method) {
            case 'preload':
              return <String, Object?>{
                'screenId': 'screen_42',
                'placementId': (call.arguments as Map?)?['source']?['id'],
                'height': 600,
                'type': 0,
                'plans': <Map<String, Object?>>[],
              };
            default:
              return null;
          }
        },
      );
      messenger.setMockMessageHandler(
          eventChannelName, (message) async => null);

      PurchaselyBridge.debugReset();
      PurchaselyBridge.ensureInstalled();
    });

    tearDown(() {
      PurchaselyBridge.debugReset();
      messenger.setMockMethodCallHandler(
          const MethodChannel(methodChannelName), null);
      messenger.setMockMessageHandler(eventChannelName, null);
    });

    test('has correct view type', () {
      expect(PLYPresentationView.viewType,
          'io.purchasely.purchasely_flutter/native_view');
    });

    testWidgets('shows a loading indicator before preload resolves',
        (WidgetTester tester) async {
      final request = PresentationBuilder.placement('home').build();
      final view = PLYPresentationView(request: request);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));

      // First frame: preload future not yet resolved.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders an AndroidView with the requestId after preload',
        (WidgetTester tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final request = PresentationBuilder.placement('home').build();
        final view = PLYPresentationView(request: request);

        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.ltr,
              child: Scaffold(body: view),
            ),
          ),
        );
        // Let the preload future resolve, then rebuild.
        await tester.pumpAndSettle();

        final androidView =
            tester.widget<AndroidView>(find.byType(AndroidView));
        expect(androidView.viewType, PLYPresentationView.viewType);
        expect(androidView.layoutDirection, TextDirection.ltr);
        final params = androidView.creationParams as Map;
        expect(params['requestId'], request.requestId);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    });

    testWidgets('renders a UiKitView with the requestId on iOS',
        (WidgetTester tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final request = PresentationBuilder.placement('home').build();
        final view = PLYPresentationView(request: request);

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
        await tester.pumpAndSettle();

        final uiKitView = tester.widget<UiKitView>(find.byType(UiKitView));
        expect(uiKitView.viewType, PLYPresentationView.viewType);
        final params = uiKitView.creationParams as Map;
        expect(params['requestId'], request.requestId);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    });

    testWidgets('build returns Text for unsupported platform',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      final request = PresentationBuilder.placement('home').build();
      final view = PLYPresentationView(request: request);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
      await tester.pumpAndSettle();

      expect(find.textContaining('is not supported yet'), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });
  });
}
