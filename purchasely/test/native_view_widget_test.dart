import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';
import 'package:purchasely_flutter/native_view_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PLYPresentationView', () {
    test('creates instance with all parameters', () {
      final presentation = PLYPresentation(
          'pres-123',
          'placement-123',
          'audience-123',
          'abtest-123',
          'variant-A',
          'en',
          600,
          PLYPresentationType.normal, [], {});

      final view = PLYPresentationView(
        presentation: presentation,
        placementId: 'placement-456',
        presentationId: 'presentation-789',
        contentId: 'content-123',
        callback: (result) {},
      );

      expect(view.presentation, presentation);
      expect(view.placementId, 'placement-456');
      expect(view.presentationId, 'presentation-789');
      expect(view.contentId, 'content-123');
      expect(view.callback, isNotNull);
    });

    test('creates instance with minimal parameters', () {
      final view = PLYPresentationView();

      expect(view.presentation, isNull);
      expect(view.placementId, isNull);
      expect(view.presentationId, isNull);
      expect(view.contentId, isNull);
      expect(view.callback, isNull);
    });

    test('has correct channel name', () {
      final view = PLYPresentationView();

      expect(view.channel, isA<MethodChannel>());
    });

    test('has correct view type', () {
      final view = PLYPresentationView();

      expect(view.viewType, 'io.purchasely.purchasely_flutter/native_view');
    });

    test('creates instance with only presentation', () {
      final presentation = PLYPresentation(
          'pres-123',
          'placement-123',
          null,
          null,
          null,
          'en',
          400,
          PLYPresentationType.fallback,
          [PLYPresentationPlan('plan-123', 'product-123', null, null)],
          {'theme': 'dark'});

      final view = PLYPresentationView(presentation: presentation);

      expect(view.presentation!.id, 'pres-123');
      expect(view.presentation!.type, PLYPresentationType.fallback);
    });

    test('creates instance with only placementId', () {
      final view = PLYPresentationView(placementId: 'placement-only');

      expect(view.placementId, 'placement-only');
      expect(view.presentation, isNull);
    });

    test('creates instance with only presentationId', () {
      final view = PLYPresentationView(presentationId: 'presentation-only');

      expect(view.presentationId, 'presentation-only');
      expect(view.presentation, isNull);
    });

    test('creates instance with only contentId', () {
      final view = PLYPresentationView(contentId: 'content-only');

      expect(view.contentId, 'content-only');
      expect(view.presentation, isNull);
    });

    test('creates instance with only callback', () {
      bool callbackCalled = false;
      final view = PLYPresentationView(
        callback: (result) {
          callbackCalled = true;
        },
      );

      expect(view.callback, isNotNull);
      // Invoke the callback to test it works
      view.callback!(
          PresentPresentationResult(PLYPurchaseResult.purchased, null));
      expect(callbackCalled, true);
    });

    test('callback receives correct result', () {
      PresentPresentationResult? receivedResult;
      final plan = PLYPlan(
          'plan-123',
          'product-123',
          'Premium',
          PLYPlanType.autoRenewingSubscription,
          9.99,
          '\$9.99',
          'USD',
          '\$',
          '9.99',
          'P1M',
          false,
          null,
          null,
          null,
          null,
          false);

      final view = PLYPresentationView(
        callback: (result) {
          receivedResult = result;
        },
      );

      final expectedResult =
          PresentPresentationResult(PLYPurchaseResult.restored, plan);
      view.callback!(expectedResult);

      expect(receivedResult, isNotNull);
      expect(receivedResult!.result, PLYPurchaseResult.restored);
      expect(receivedResult!.plan!.vendorId, 'plan-123');
    });

    testWidgets('build returns Text for unsupported platform',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      final view = PLYPresentationView(
        placementId: 'test-placement',
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));

      expect(find.textContaining('is not supported yet'), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('build returns Text for Linux platform',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      final view = PLYPresentationView(
        placementId: 'test-placement',
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));

      expect(find.textContaining('is not supported yet'), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('build returns Text for Fuchsia platform',
        (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

      final view = PLYPresentationView(
        placementId: 'test-placement',
      );

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));

      expect(find.textContaining('is not supported yet'), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    test('view type is consistent', () {
      final view1 = PLYPresentationView();
      final view2 = PLYPresentationView(placementId: 'test');

      expect(view1.viewType, view2.viewType);
    });
  });

  group('PLYPresentationView Integration with Purchasely', () {
    test('getPresentationView creates valid PLYPresentationView', () {
      final view = Purchasely.getPresentationView(
        placementId: 'placement-123',
        presentationId: 'presentation-456',
        contentId: 'content-789',
        callback: (result) {},
      );

      expect(view, isNotNull);
      expect(view, isA<PLYPresentationView>());
      expect(view!.placementId, 'placement-123');
      expect(view.presentationId, 'presentation-456');
      expect(view.contentId, 'content-789');
    });

    test('getPresentationView with presentation parameter', () {
      final presentation = PLYPresentation(
          'pres-123',
          'placement-123',
          'audience-123',
          'abtest-123',
          'variant-A',
          'en',
          600,
          PLYPresentationType.normal, [], {});

      final view = Purchasely.getPresentationView(
        presentation: presentation,
        callback: (result) {},
      );

      expect(view, isNotNull);
      expect(view!.presentation, presentation);
      expect(view.presentation!.id, 'pres-123');
    });

    test('getPresentationView with null parameters returns view', () {
      final view = Purchasely.getPresentationView();

      expect(view, isNotNull);
      expect(view!.presentation, isNull);
      expect(view.placementId, isNull);
      expect(view.presentationId, isNull);
      expect(view.contentId, isNull);
      expect(view.callback, isNull);
    });
  });
}
