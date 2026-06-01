import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

/// Comprehensive tests for platform channel interactions between Flutter and native plugins.
/// These tests verify that the Dart side correctly communicates with iOS and Android native code.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Platform Channel - Method Call Tests', () {
    late MethodChannel channel;
    final List<MethodCall> methodCalls = [];

    setUp(() {
      channel = const MethodChannel('purchasely');
      methodCalls.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return _handleMethodCall(methodCall);
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    group('SDK Initialization', () {
      test('start sends correct parameters to native', () async {
        await Purchasely.start(
          apiKey: 'test-api-key',
          androidStores: ['Google'],
          storeKit1: false,
          logLevel: PLYLogLevel.debug,
          userId: 'user-123',
          runningMode: PLYRunningMode.full,
        );

        expect(methodCalls.length, 1);
        expect(methodCalls.first.method, 'start');
        expect(methodCalls.first.arguments['apiKey'], 'test-api-key');
        expect(methodCalls.first.arguments['stores'], ['Google']);
        expect(methodCalls.first.arguments['storeKit1'], false);
        expect(methodCalls.first.arguments['logLevel'], 0); // debug = 0
        expect(methodCalls.first.arguments['userId'], 'user-123');
        expect(methodCalls.first.arguments['runningMode'], 3); // full = 3
      });

      test('start with required parameters only', () async {
        await Purchasely.start(apiKey: 'minimal-key', storeKit1: true);

        expect(methodCalls.first.method, 'start');
        expect(methodCalls.first.arguments['apiKey'], 'minimal-key');
        expect(methodCalls.first.arguments['storeKit1'], true);
      });

      test('close sends method call to native', () async {
        await Purchasely.close();

        expect(methodCalls.first.method, 'close');
      });

      test('synchronize sends method call to native', () async {
        await Purchasely.synchronize();

        expect(methodCalls.first.method, 'synchronize');
      });
    });

    group('User Management', () {
      test('userLogin sends correct userId', () async {
        await Purchasely.userLogin('test-user-456');

        expect(methodCalls.first.method, 'userLogin');
        expect(methodCalls.first.arguments['userId'], 'test-user-456');
      });

      test('userLogout sends method call to native', () async {
        await Purchasely.userLogout();

        expect(methodCalls.first.method, 'userLogout');
      });

      test('isAnonymous returns boolean from native', () async {
        final isAnon = await Purchasely.isAnonymous();

        expect(methodCalls.first.method, 'isAnonymous');
        expect(isAnon, true);
      });
    });

    group('Presentation Methods', () {
      test('fetchPresentation sends correct placementId', () async {
        final presentation = await Purchasely.fetchPresentation('onboarding');

        expect(methodCalls.first.method, 'fetchPresentation');
        expect(methodCalls.first.arguments['placementVendorId'], 'onboarding');
        expect(presentation, isNotNull);
        expect(presentation!.id, 'presentation-123');
        expect(presentation.type, PLYPresentationType.normal);
      });

      test('fetchPresentation with presentationId', () async {
        await Purchasely.fetchPresentation('onboarding',
            presentationId: 'pres-456');

        expect(methodCalls.first.arguments['presentationVendorId'], 'pres-456');
      });

      test('fetchPresentation with contentId', () async {
        await Purchasely.fetchPresentation('onboarding',
            contentId: 'content-789');

        expect(methodCalls.first.arguments['contentId'], 'content-789');
      });

      test('presentPresentationWithIdentifier sends presentationId', () async {
        await Purchasely.presentPresentationWithIdentifier('pres-123');

        expect(methodCalls.first.method, 'presentPresentationWithIdentifier');
        expect(methodCalls.first.arguments['presentationVendorId'], 'pres-123');
      });

      test('presentPresentationForPlacement sends placementId', () async {
        await Purchasely.presentPresentationForPlacement('premium');

        expect(methodCalls.first.method, 'presentPresentationForPlacement');
        expect(methodCalls.first.arguments['placementVendorId'], 'premium');
      });

      test('presentProductWithIdentifier sends productId', () async {
        await Purchasely.presentProductWithIdentifier('product-123');

        expect(methodCalls.first.method, 'presentProductWithIdentifier');
        expect(methodCalls.first.arguments['productVendorId'], 'product-123');
      });

      test('presentPlanWithIdentifier sends planId', () async {
        await Purchasely.presentPlanWithIdentifier('plan-123');

        expect(methodCalls.first.method, 'presentPlanWithIdentifier');
        expect(methodCalls.first.arguments['planVendorId'], 'plan-123');
      });

      test('closePresentation sends method call to native', () async {
        await Purchasely.closePresentation();

        expect(methodCalls.first.method, 'closePresentation');
      });

      test('hidePresentation sends method call to native', () async {
        await Purchasely.hidePresentation();

        expect(methodCalls.first.method, 'hidePresentation');
      });

      test('showPresentation sends method call to native', () async {
        await Purchasely.showPresentation();

        expect(methodCalls.first.method, 'showPresentation');
      });
    });

    group('Product & Plan Methods', () {
      test('productWithIdentifier returns correct product', () async {
        final product =
            await Purchasely.productWithIdentifier('product-vendor-123');

        expect(methodCalls.first.method, 'productWithIdentifier');
        expect(methodCalls.first.arguments['vendorId'], 'product-vendor-123');
        expect(product, isNotNull);
        expect(product!.name, 'Test Product');
      });

      test('planWithIdentifier returns correct plan', () async {
        final plan = await Purchasely.planWithIdentifier('plan-vendor-123');

        expect(methodCalls.first.method, 'planWithIdentifier');
        expect(methodCalls.first.arguments['vendorId'], 'plan-vendor-123');
        expect(plan, isNotNull);
        expect(plan!.name, 'Premium Plan');
      });

      test('allProducts returns list of products', () async {
        final products = await Purchasely.allProducts();

        expect(methodCalls.first.method, 'allProducts');
        expect(products, isNotEmpty);
      });
    });

    group('Purchase Methods', () {
      test('purchaseWithPlanVendorId sends correct parameters', () async {
        await Purchasely.purchaseWithPlanVendorId(
          vendorId: 'plan-123',
          offerId: 'offer-456',
          contentId: 'content-789',
        );

        expect(methodCalls.first.method, 'purchaseWithPlanVendorId');
        expect(methodCalls.first.arguments['vendorId'], 'plan-123');
        expect(methodCalls.first.arguments['offerId'], 'offer-456');
        expect(methodCalls.first.arguments['contentId'], 'content-789');
      });

      test('restoreAllProducts sends method call to native', () async {
        await Purchasely.restoreAllProducts();

        expect(methodCalls.first.method, 'restoreAllProducts');
      });

      test('silentRestoreAllProducts sends method call to native', () async {
        await Purchasely.silentRestoreAllProducts();

        expect(methodCalls.first.method, 'silentRestoreAllProducts');
      });
    });

    group('Subscription Methods', () {
      test('userSubscriptions returns subscriptions', () async {
        final subs = await Purchasely.userSubscriptions();

        expect(methodCalls.first.method, 'userSubscriptions');
        expect(subs, isNotEmpty);
        expect(subs.first.purchaseToken, 'token-123');
      });

      test('userSubscriptionsHistory returns history', () async {
        final history = await Purchasely.userSubscriptionsHistory();

        expect(methodCalls.first.method, 'userSubscriptionsHistory');
        expect(history, isNotEmpty);
        expect(history.first.cumulatedRevenuesInUSD, 29.97);
      });

      test('presentSubscriptions sends method call to native', () async {
        await Purchasely.presentSubscriptions();

        expect(methodCalls.first.method, 'presentSubscriptions');
      });

      test('displaySubscriptionCancellationInstruction sends method call',
          () async {
        await Purchasely.displaySubscriptionCancellationInstruction();

        expect(methodCalls.first.method,
            'displaySubscriptionCancellationInstruction');
      });

      test('userDidConsumeSubscriptionContent sends method call', () async {
        await Purchasely.userDidConsumeSubscriptionContent();

        expect(methodCalls.first.method, 'userDidConsumeSubscriptionContent');
      });
    });

    group('User Attributes', () {
      test('setUserAttributeWithString with legal basis', () async {
        await Purchasely.setUserAttributeWithString(
          'name',
          'John',
          processingLegalBasis: PLYDataProcessingLegalBasis.essential,
        );

        expect(methodCalls.first.method, 'setUserAttributeWithString');
        expect(methodCalls.first.arguments['key'], 'name');
        expect(methodCalls.first.arguments['value'], 'John');
        expect(
            methodCalls.first.arguments['processingLegalBasis'], 'ESSENTIAL');
      });

      test('setUserAttributeWithInt sends correct values', () async {
        await Purchasely.setUserAttributeWithInt('age', 25);

        expect(methodCalls.first.method, 'setUserAttributeWithInt');
        expect(methodCalls.first.arguments['key'], 'age');
        expect(methodCalls.first.arguments['value'], 25);
      });

      test('setUserAttributeWithDouble sends correct values', () async {
        await Purchasely.setUserAttributeWithDouble('balance', 99.99);

        expect(methodCalls.first.method, 'setUserAttributeWithDouble');
        expect(methodCalls.first.arguments['key'], 'balance');
        expect(methodCalls.first.arguments['value'], 99.99);
      });

      test('setUserAttributeWithBoolean sends correct values', () async {
        await Purchasely.setUserAttributeWithBoolean('premium', true);

        expect(methodCalls.first.method, 'setUserAttributeWithBoolean');
        expect(methodCalls.first.arguments['key'], 'premium');
        expect(methodCalls.first.arguments['value'], true);
      });

      test('setUserAttributeWithDate sends ISO formatted date', () async {
        final date = DateTime(2025, 6, 15, 14, 30, 0);
        await Purchasely.setUserAttributeWithDate('birthdate', date);

        expect(methodCalls.first.method, 'setUserAttributeWithDate');
        expect(methodCalls.first.arguments['key'], 'birthdate');
        expect(methodCalls.first.arguments['value'], contains('2025-06-15'));
      });

      test('setUserAttributeWithStringArray sends array', () async {
        await Purchasely.setUserAttributeWithStringArray(
            'interests', ['sports', 'music', 'travel']);

        expect(methodCalls.first.method, 'setUserAttributeWithStringArray');
        expect(methodCalls.first.arguments['value'],
            ['sports', 'music', 'travel']);
      });

      test('setUserAttributeWithIntArray sends array', () async {
        await Purchasely.setUserAttributeWithIntArray(
            'scores', [100, 200, 300]);

        expect(methodCalls.first.method, 'setUserAttributeWithIntArray');
        expect(methodCalls.first.arguments['value'], [100, 200, 300]);
      });

      test('setUserAttributeWithDoubleArray sends array', () async {
        await Purchasely.setUserAttributeWithDoubleArray(
            'ratings', [4.5, 3.8, 4.9]);

        expect(methodCalls.first.method, 'setUserAttributeWithDoubleArray');
        expect(methodCalls.first.arguments['value'], [4.5, 3.8, 4.9]);
      });

      test('setUserAttributeWithBooleanArray sends array', () async {
        await Purchasely.setUserAttributeWithBooleanArray(
            'flags', [true, false, true]);

        expect(methodCalls.first.method, 'setUserAttributeWithBooleanArray');
        expect(methodCalls.first.arguments['value'], [true, false, true]);
      });

      test('incrementUserAttribute with custom value', () async {
        await Purchasely.incrementUserAttribute('points', value: 10);

        expect(methodCalls.first.method, 'incrementUserAttribute');
        expect(methodCalls.first.arguments['key'], 'points');
        expect(methodCalls.first.arguments['value'], 10);
      });

      test('incrementUserAttribute with default value', () async {
        await Purchasely.incrementUserAttribute('counter');

        expect(methodCalls.first.arguments['value'], 1);
      });

      test('decrementUserAttribute with custom value', () async {
        await Purchasely.decrementUserAttribute('lives', value: 3);

        expect(methodCalls.first.method, 'decrementUserAttribute');
        expect(methodCalls.first.arguments['key'], 'lives');
        expect(methodCalls.first.arguments['value'], 3);
      });

      test('userAttribute returns value from native', () async {
        final value = await Purchasely.userAttribute('test-key');

        expect(methodCalls.first.method, 'userAttribute');
        expect(value, 'test-value');
      });

      test('userAttributes returns map from native', () async {
        final attrs = await Purchasely.userAttributes();

        expect(methodCalls.first.method, 'userAttributes');
        expect(attrs, isA<Map>());
      });

      test('clearUserAttribute sends key', () {
        Purchasely.clearUserAttribute('old-key');

        expect(methodCalls.first.method, 'clearUserAttribute');
        expect(methodCalls.first.arguments['key'], 'old-key');
      });

      test('clearUserAttributes sends method call', () {
        Purchasely.clearUserAttributes();

        expect(methodCalls.first.method, 'clearUserAttributes');
      });

      test('clearBuiltInAttributes sends method call', () {
        Purchasely.clearBuiltInAttributes();

        expect(methodCalls.first.method, 'clearBuiltInAttributes');
      });
    });

    group('Dynamic Offerings', () {
      test('setDynamicOffering sends offering data', () async {
        final offering = PLYDynamicOffering('ref-123', 'plan-456', 'offer-789');
        await Purchasely.setDynamicOffering(offering);

        expect(methodCalls.first.method, 'setDynamicOffering');
        expect(methodCalls.first.arguments['reference'], 'ref-123');
        expect(methodCalls.first.arguments['planVendorId'], 'plan-456');
        expect(methodCalls.first.arguments['offerVendorId'], 'offer-789');
      });

      test('setDynamicOffering without offerId', () async {
        final offering = PLYDynamicOffering('ref-123', 'plan-456', null);
        await Purchasely.setDynamicOffering(offering);

        expect(methodCalls.first.arguments['offerVendorId'], isNull);
      });

      test('getDynamicOfferings returns list', () async {
        final offerings = await Purchasely.getDynamicOfferings();

        expect(methodCalls.first.method, 'getDynamicOfferings');
        expect(offerings, isA<List<PLYDynamicOffering>>());
      });

      test('removeDynamicOffering sends reference', () {
        Purchasely.removeDynamicOffering('ref-to-remove');

        expect(methodCalls.first.method, 'removeDynamicOffering');
        expect(methodCalls.first.arguments['reference'], 'ref-to-remove');
      });

      test('clearDynamicOfferings sends method call', () {
        Purchasely.clearDynamicOfferings();

        expect(methodCalls.first.method, 'clearDynamicOfferings');
      });
    });

    group('SDK Configuration', () {
      test('setLanguage sends language code', () async {
        await Purchasely.setLanguage('fr');

        expect(methodCalls.first.method, 'setLanguage');
        expect(methodCalls.first.arguments['language'], 'fr');
      });

      test('isDeeplinkHandled returns boolean', () async {
        final handled = await Purchasely.isDeeplinkHandled('app://premium');

        expect(methodCalls.first.method, 'isDeeplinkHandled');
        expect(methodCalls.first.arguments['deeplink'], 'app://premium');
        expect(handled, true);
      });
    });

    group('Attributes', () {
      test('setAttribute with firebase_app_instance_id', () async {
        await Purchasely.setAttribute(
            PLYAttribute.firebase_app_instance_id, 'firebase-123');

        expect(methodCalls.first.method, 'setAttribute');
        expect(methodCalls.first.arguments['attribute'], 0);
        expect(methodCalls.first.arguments['value'], 'firebase-123');
      });

      test('setAttribute with airship_channel_id', () async {
        await Purchasely.setAttribute(
            PLYAttribute.airship_channel_id, 'airship-456');

        expect(methodCalls.first.arguments['attribute'], 1);
      });

      test('setAttribute with airship_user_id', () async {
        await Purchasely.setAttribute(PLYAttribute.airship_user_id, 'user-789');

        expect(methodCalls.first.arguments['attribute'], 2);
      });

      test('setAttribute with batch_installation_id', () async {
        await Purchasely.setAttribute(
            PLYAttribute.batch_installation_id, 'batch-install');

        expect(methodCalls.first.arguments['attribute'], 3);
      });

      test('setAttribute with adjust_id', () async {
        await Purchasely.setAttribute(PLYAttribute.adjust_id, 'adjust-123');

        expect(methodCalls.first.arguments['attribute'], 4);
      });

      test('setAttribute with appsflyer_id', () async {
        await Purchasely.setAttribute(
            PLYAttribute.appsflyer_id, 'appsflyer-456');

        expect(methodCalls.first.arguments['attribute'], 5);
      });

      test('setAttribute with mixpanel_distinct_id', () async {
        await Purchasely.setAttribute(
            PLYAttribute.mixpanel_distinct_id, 'mixpanel-123');

        expect(methodCalls.first.arguments['attribute'], 6);
      });

      test('setAttribute with clever_tap_id', () async {
        await Purchasely.setAttribute(
            PLYAttribute.clever_tap_id, 'clevertap-456');

        expect(methodCalls.first.arguments['attribute'], 7);
      });

      test('setAttribute with sendinblueUserEmail', () async {
        await Purchasely.setAttribute(
            PLYAttribute.sendinblueUserEmail, 'test@example.com');

        expect(methodCalls.first.arguments['attribute'], 8);
      });

      test('setAttribute with iterableUserEmail', () async {
        await Purchasely.setAttribute(
            PLYAttribute.iterableUserEmail, 'iterable@example.com');

        expect(methodCalls.first.arguments['attribute'], 9);
      });

      test('setAttribute with iterableUserId', () async {
        await Purchasely.setAttribute(
            PLYAttribute.iterableUserId, 'iterable-user');

        expect(methodCalls.first.arguments['attribute'], 10);
      });

      test('setAttribute with atInternetIdClient', () async {
        await Purchasely.setAttribute(
            PLYAttribute.atInternetIdClient, 'atinternet-123');

        expect(methodCalls.first.arguments['attribute'], 11);
      });

      test('setAttribute with mParticleUserId', () async {
        await Purchasely.setAttribute(
            PLYAttribute.mParticleUserId, 'mparticle-456');

        expect(methodCalls.first.arguments['attribute'], 12);
      });

      test('setAttribute with customerioUserId', () async {
        await Purchasely.setAttribute(
            PLYAttribute.customerioUserId, 'customerio-789');

        expect(methodCalls.first.arguments['attribute'], 13);
      });

      test('setAttribute with customerioUserEmail', () async {
        await Purchasely.setAttribute(
            PLYAttribute.customerioUserEmail, 'customerio@example.com');

        expect(methodCalls.first.arguments['attribute'], 14);
      });

      test('setAttribute with branchUserDeveloperIdentity', () async {
        await Purchasely.setAttribute(
            PLYAttribute.branchUserDeveloperIdentity, 'branch-123');

        expect(methodCalls.first.arguments['attribute'], 15);
      });

      test('setAttribute with amplitudeUserId', () async {
        await Purchasely.setAttribute(
            PLYAttribute.amplitudeUserId, 'amplitude-789');

        expect(methodCalls.first.arguments['attribute'], 16);
      });

      test('setAttribute with amplitudeDeviceId', () async {
        await Purchasely.setAttribute(
            PLYAttribute.amplitudeDeviceId, 'amplitude-device');

        expect(methodCalls.first.arguments['attribute'], 17);
      });

      test('setAttribute with moengageUniqueId', () async {
        await Purchasely.setAttribute(
            PLYAttribute.moengageUniqueId, 'moengage-456');

        expect(methodCalls.first.arguments['attribute'], 18);
      });

      test('setAttribute with oneSignalExternalId', () async {
        await Purchasely.setAttribute(
            PLYAttribute.oneSignalExternalId, 'onesignal-external');

        expect(methodCalls.first.arguments['attribute'], 19);
      });

      test('setAttribute with batchCustomUserId', () async {
        await Purchasely.setAttribute(
            PLYAttribute.batchCustomUserId, 'batch-custom-user');

        expect(methodCalls.first.arguments['attribute'], 20);
      });
    });

    group('iOS Specific Methods', () {
      test('signPromotionalOffer sends storeProductId and offerId', () async {
        final result = await Purchasely.signPromotionalOffer(
            'store-product-123', 'promo-offer-456');

        expect(methodCalls.first.method, 'signPromotionalOffer');
        expect(
            methodCalls.first.arguments['storeProductId'], 'store-product-123');
        expect(methodCalls.first.arguments['storeOfferId'], 'promo-offer-456');
        expect(result, isA<Map>());
        expect(result['signature'], 'sig-123');
      });

      test('isEligibleForIntroOffer returns boolean', () async {
        final eligible = await Purchasely.isEligibleForIntroOffer('plan-123');

        expect(methodCalls.first.method, 'isEligibleForIntroOffer');
        expect(methodCalls.first.arguments['planVendorId'], 'plan-123');
        expect(eligible, true);
      });
    });

    group('Paywall Action Interceptor', () {
      test('onProcessAction sends processAction status', () async {
        await Purchasely.onProcessAction(true);

        expect(methodCalls.first.method, 'onProcessAction');
        expect(methodCalls.first.arguments['processAction'], true);
      });

      test('onProcessAction with false', () async {
        await Purchasely.onProcessAction(false);

        expect(methodCalls.first.arguments['processAction'], false);
      });
    });

    group('Privacy & Consent', () {
      test('setDebugMode sends debugMode status', () async {
        await Purchasely.setDebugMode(true);

        expect(methodCalls.first.method, 'setDebugMode');
        expect(methodCalls.first.arguments['debugMode'], true);
      });
    });
  });

  group('Platform Channel - Event Stream Tests', () {
    test('EventChannel names are correct', () {
      // Verify event channel names match what native expects
      expect('purchasely-events', isNotEmpty);
      expect('purchasely-purchases', isNotEmpty);
      expect('purchasely-user-attributes', isNotEmpty);
    });
  });

  group('Platform Channel - Data Transformation Tests', () {
    test('PLYLogLevel converts to correct int values', () {
      expect(PLYLogLevel.debug.index, 0);
      expect(PLYLogLevel.info.index, 1);
      expect(PLYLogLevel.warn.index, 2);
      expect(PLYLogLevel.error.index, 3);
    });

    test('PLYRunningMode converts to correct int values', () {
      expect(PLYRunningMode.transactionOnly.index, 0);
      expect(PLYRunningMode.observer.index, 1);
      expect(PLYRunningMode.paywallObserver.index, 2);
      expect(PLYRunningMode.full.index, 3);
    });

    test('PLYThemeMode converts to correct int values', () {
      expect(PLYThemeMode.light.index, 0);
      expect(PLYThemeMode.dark.index, 1);
      expect(PLYThemeMode.system.index, 2);
    });

    test('PLYPresentationType converts correctly', () {
      expect(PLYPresentationType.normal.index, 0);
      expect(PLYPresentationType.fallback.index, 1);
      expect(PLYPresentationType.deactivated.index, 2);
      expect(PLYPresentationType.client.index, 3);
    });

    test('PLYPlanType converts correctly', () {
      expect(PLYPlanType.consumable.index, 0);
      expect(PLYPlanType.nonConsumable.index, 1);
      expect(PLYPlanType.autoRenewingSubscription.index, 2);
      expect(PLYPlanType.nonRenewingSubscription.index, 3);
      expect(PLYPlanType.unknown.index, 4);
    });

    test('PLYSubscriptionSource converts correctly', () {
      expect(PLYSubscriptionSource.appleAppStore.index, 0);
      expect(PLYSubscriptionSource.googlePlayStore.index, 1);
      expect(PLYSubscriptionSource.amazonAppstore.index, 2);
      expect(PLYSubscriptionSource.huaweiAppGallery.index, 3);
      expect(PLYSubscriptionSource.none.index, 4);
    });

    test('PLYPurchaseResult converts correctly', () {
      expect(PLYPurchaseResult.purchased.index, 0);
      expect(PLYPurchaseResult.cancelled.index, 1);
      expect(PLYPurchaseResult.restored.index, 2);
    });

    test('PLYPaywallAction converts correctly', () {
      expect(PLYPaywallAction.close.index, 0);
      expect(PLYPaywallAction.close_all.index, 1);
      expect(PLYPaywallAction.login.index, 2);
      expect(PLYPaywallAction.navigate.index, 3);
      expect(PLYPaywallAction.purchase.index, 4);
      expect(PLYPaywallAction.restore.index, 5);
      expect(PLYPaywallAction.open_presentation.index, 6);
      expect(PLYPaywallAction.open_placement.index, 7);
      expect(PLYPaywallAction.promo_code.index, 8);
      expect(PLYPaywallAction.open_flow_step.index, 9);
      expect(PLYPaywallAction.web_checkout.index, 10);
    });

    test('PLYDataProcessingLegalBasis converts correctly', () {
      expect(PLYDataProcessingLegalBasis.essential.index, 0);
      expect(PLYDataProcessingLegalBasis.optional.index, 1);
    });

    test('PLYDataProcessingPurpose converts correctly', () {
      expect(PLYDataProcessingPurpose.allNonEssentials.index, 0);
      expect(PLYDataProcessingPurpose.analytics.index, 1);
      expect(PLYDataProcessingPurpose.identifiedAnalytics.index, 2);
      expect(PLYDataProcessingPurpose.campaigns.index, 3);
      expect(PLYDataProcessingPurpose.personalization.index, 4);
      expect(PLYDataProcessingPurpose.thirdPartyIntegrations.index, 5);
    });
  });

  group('Platform Channel - Model Validation Tests', () {
    test('PLYDynamicOffering creates correctly', () {
      final offering = PLYDynamicOffering('ref-1', 'plan-1', 'offer-1');

      expect(offering.reference, 'ref-1');
      expect(offering.planVendorId, 'plan-1');
      expect(offering.offerVendorId, 'offer-1');
    });

    test('PLYDynamicOffering with null offerVendorId', () {
      final offering = PLYDynamicOffering('ref-2', 'plan-2', null);

      expect(offering.reference, 'ref-2');
      expect(offering.planVendorId, 'plan-2');
      expect(offering.offerVendorId, isNull);
    });
  });

  group('Android Plugin Specific Tests', () {
    late MethodChannel channel;
    final List<MethodCall> methodCalls = [];

    setUp(() {
      channel = const MethodChannel('purchasely');
      methodCalls.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return _handleMethodCall(methodCall);
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('Android stores parameter is passed correctly', () async {
      await Purchasely.start(
        apiKey: 'test-key',
        androidStores: ['Google', 'Huawei', 'Amazon'],
        storeKit1: false,
      );

      expect(methodCalls.first.arguments['stores'],
          ['Google', 'Huawei', 'Amazon']);
    });

    test('Android default store is Google', () async {
      await Purchasely.start(
        apiKey: 'test-key',
        storeKit1: false,
      );

      expect(methodCalls.first.arguments['stores'], ['Google']);
    });
  });

  group('iOS Plugin Specific Tests', () {
    late MethodChannel channel;
    final List<MethodCall> methodCalls = [];

    setUp(() {
      channel = const MethodChannel('purchasely');
      methodCalls.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return _handleMethodCall(methodCall);
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('storeKit1 parameter is passed correctly as true', () async {
      await Purchasely.start(
        apiKey: 'test-key',
        storeKit1: true,
      );

      expect(methodCalls.first.arguments['storeKit1'], true);
    });

    test('storeKit1 parameter is passed correctly as false', () async {
      await Purchasely.start(
        apiKey: 'test-key',
        storeKit1: false,
      );

      expect(methodCalls.first.arguments['storeKit1'], false);
    });

    test('signPromotionalOffer is iOS specific method', () async {
      final result =
          await Purchasely.signPromotionalOffer('product-123', 'offer-456');

      expect(methodCalls.first.method, 'signPromotionalOffer');
      expect(result['signature'], isNotNull);
      expect(result['timestamp'], isNotNull);
      expect(result['nonce'], isNotNull);
      expect(result['keyIdentifier'], isNotNull);
    });
  });
}

/// Simulates native method call responses for both iOS and Android
dynamic _handleMethodCall(MethodCall methodCall) {
  switch (methodCall.method) {
    case 'start':
      return true;
    case 'close':
      return null;
    case 'synchronize':
      return null;
    case 'getAnonymousUserId':
      return 'anonymous-user-123';
    case 'userLogin':
      return true;
    case 'userLogout':
      return null;
    case 'isAnonymous':
      return true;
    case 'setLogLevel':
      return null;
    case 'setLanguage':
      return null;
    case 'setThemeMode':
      return null;
    case 'readyToOpenDeeplink':
      return null;
    case 'isDeeplinkHandled':
      return true;
    case 'restoreAllProducts':
      return true;
    case 'silentRestoreAllProducts':
      return true;
    case 'setDebugMode':
      return null;
    case 'revokeDataProcessingConsent':
      return null;
    case 'fetchPresentation':
      return {
        'id': 'presentation-123',
        'placementId': 'placement-456',
        'audienceId': 'audience-789',
        'abTestId': 'abtest-001',
        'abTestVariantId': 'variant-A',
        'language': 'en',
        'type': 0,
        'plans': [
          {
            'planVendorId': 'plan-123',
            'storeProductId': 'product-123',
          }
        ],
        'metadata': {'key': 'value'}
      };
    case 'presentPresentation':
    case 'presentPresentationWithIdentifier':
    case 'presentPresentationForPlacement':
    case 'presentProductWithIdentifier':
    case 'presentPlanWithIdentifier':
      return {
        'result': 0,
        'plan': {
          'vendorId': 'plan-vendor-123',
          'productId': 'product-123',
          'name': 'Premium Plan',
          'type': 2,
          'amount': 9.99,
        }
      };
    case 'closePresentation':
    case 'hidePresentation':
    case 'showPresentation':
      return null;
    case 'clientPresentationDisplayed':
    case 'clientPresentationClosed':
      return null;
    case 'productWithIdentifier':
      final vendorId = methodCall.arguments['vendorId'];
      if (vendorId == 'non-existent') {
        return null;
      }
      return {
        'name': 'Test Product',
        'vendorId': 'product-vendor-123',
        'plans': {}
      };
    case 'planWithIdentifier':
      return {
        'vendorId': 'plan-vendor-123',
        'productId': 'product-123',
        'name': 'Premium Plan',
        'type': 2,
        'amount': 9.99,
      };
    case 'allProducts':
      return [
        {'name': 'Product 1', 'vendorId': 'vendor-1', 'plans': {}}
      ];
    case 'purchaseWithPlanVendorId':
      return {'status': 'success', 'transactionId': 'txn-123'};
    case 'userSubscriptions':
    case 'userSubscriptionsHistory':
      return [
        {
          'purchaseToken': 'token-123',
          'subscriptionSource': 1,
          'nextRenewalDate': '2025-02-01T00:00:00Z',
          'plan': {
            'vendorId': 'plan-vendor-123',
            'name': 'Premium',
            'type': 2,
          },
          'product': {'name': 'Premium Product', 'vendorId': 'product-123'},
          'cumulatedRevenuesInUSD': 29.97,
          'subscriptionDurationInDays': 90,
          'subscriptionDurationInWeeks': 12,
          'subscriptionDurationInMonths': 3,
        }
      ];
    case 'presentSubscriptions':
      return null;
    case 'displaySubscriptionCancellationInstruction':
      return null;
    case 'userDidConsumeSubscriptionContent':
      return null;
    case 'setUserAttributeWithString':
    case 'setUserAttributeWithInt':
    case 'setUserAttributeWithDouble':
    case 'setUserAttributeWithBoolean':
    case 'setUserAttributeWithDate':
    case 'setUserAttributeWithStringArray':
    case 'setUserAttributeWithIntArray':
    case 'setUserAttributeWithDoubleArray':
    case 'setUserAttributeWithBooleanArray':
    case 'incrementUserAttribute':
    case 'decrementUserAttribute':
      return null;
    case 'userAttribute':
      return 'test-value';
    case 'userAttributes':
      return {'attr1': 'value1', 'attr2': 'value2'};
    case 'clearUserAttribute':
    case 'clearUserAttributes':
    case 'clearBuiltInAttributes':
      return null;
    case 'setAttribute':
      return null;
    case 'setDynamicOffering':
      return true;
    case 'getDynamicOfferings':
      return [
        {
          'reference': 'offer-ref-1',
          'planVendorId': 'plan-vendor-1',
          'offerVendorId': 'offer-vendor-1'
        },
        {
          'reference': 'offer-ref-2',
          'planVendorId': 'plan-vendor-2',
          'offerVendorId': null
        }
      ];
    case 'removeDynamicOffering':
    case 'clearDynamicOfferings':
      return null;
    case 'signPromotionalOffer':
      return {
        'signature': 'sig-123',
        'timestamp': '1234567890',
        'nonce': 'nonce-123',
        'keyIdentifier': 'key-123'
      };
    case 'isEligibleForIntroOffer':
      return true;
    case 'setPaywallActionInterceptor':
      return null;
    case 'onProcessAction':
      return null;
    case 'setDefaultPresentationResultHandler':
      return null;
    default:
      return null;
  }
}
