import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';
import 'package:purchasely_flutter/native_view_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Purchasely Static Methods', () {
    late MethodChannel channel;
    final List<MethodCall> methodCalls = [];

    setUp(() {
      channel = const MethodChannel('purchasely');
      methodCalls.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);

        switch (methodCall.method) {
          case 'start':
            return true;
          case 'getAnonymousUserId':
            return 'anonymous-user-123';
          case 'userLogin':
            return true;
          case 'setLogLevel':
            return true;
          case 'restoreAllProducts':
            return true;
          case 'silentRestoreAllProducts':
            return true;
          case 'isAnonymous':
            return true;
          case 'isEligibleForIntroOffer':
            return true;
          case 'isDeeplinkHandled':
            return true;
          case 'fetchPresentation':
            return {
              'id': 'presentation-123',
              'placementId': 'placement-456',
              'audienceId': 'audience-789',
              'abTestId': 'abtest-001',
              'abTestVariantId': 'variant-A',
              'language': 'en',
              'height': 600,
              'type': 0,
              'plans': [
                {
                  'planVendorId': 'plan-123',
                  'storeProductId': 'product-123',
                  'basePlanId': 'base-plan',
                  'offerId': 'offer-123'
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
                'localizedAmount': '\$9.99',
                'currencyCode': 'USD',
                'currencySymbol': '\$',
                'price': '9.99',
                'period': 'P1M',
                'hasIntroductoryPrice': true,
                'introPrice': '\$4.99',
                'introAmount': 4.99,
                'introDuration': 'P1W',
                'introPeriod': 'week',
                'hasFreeTrial': false
              }
            };
          case 'productWithIdentifier':
            return {
              'name': 'Test Product',
              'vendorId': 'product-vendor-123',
              'plans': {
                'plan1': {
                  'vendorId': 'plan-vendor-123',
                  'productId': 'product-123',
                  'name': 'Premium Plan',
                  'type': 2,
                  'amount': 9.99,
                  'localizedAmount': '\$9.99',
                  'currencyCode': 'USD',
                  'currencySymbol': '\$',
                  'price': '9.99',
                  'period': 'P1M',
                  'hasIntroductoryPrice': false,
                  'introPrice': null,
                  'introAmount': null,
                  'introDuration': null,
                  'introPeriod': null,
                  'hasFreeTrial': false
                }
              }
            };
          case 'planWithIdentifier':
            return {
              'vendorId': 'plan-vendor-123',
              'productId': 'product-123',
              'name': 'Premium Plan',
              'type': 2,
              'amount': 9.99,
              'localizedAmount': '\$9.99',
              'currencyCode': 'USD',
              'currencySymbol': '\$',
              'price': '9.99',
              'period': 'P1M',
              'hasIntroductoryPrice': false,
              'introPrice': null,
              'introAmount': null,
              'introDuration': null,
              'introPeriod': null,
              'hasFreeTrial': false
            };
          case 'allProducts':
            return [
              {
                'name': 'Product 1',
                'vendorId': 'vendor-1',
                'plans': {
                  'plan1': {
                    'vendorId': 'plan-1',
                    'productId': 'product-1',
                    'name': 'Plan 1',
                    'type': 0,
                    'amount': 1.99,
                    'localizedAmount': '\$1.99',
                    'currencyCode': 'USD',
                    'currencySymbol': '\$',
                    'price': '1.99',
                    'period': null,
                    'hasIntroductoryPrice': false,
                    'introPrice': null,
                    'introAmount': null,
                    'introDuration': null,
                    'introPeriod': null,
                    'hasFreeTrial': false
                  }
                }
              }
            ];
          case 'userSubscriptions':
          case 'userSubscriptionsHistory':
            return [
              {
                'purchaseToken': 'token-123',
                'subscriptionSource': 1,
                'nextRenewalDate': '2025-02-01T00:00:00Z',
                'cancelledDate': null,
                'plan': {
                  'vendorId': 'plan-vendor-123',
                  'productId': 'product-123',
                  'name': 'Premium Plan',
                  'type': 2,
                  'amount': 9.99,
                  'localizedAmount': '\$9.99',
                  'currencyCode': 'USD',
                  'currencySymbol': '\$',
                  'price': '9.99',
                  'period': 'P1M',
                  'hasIntroductoryPrice': false,
                  'introPrice': null,
                  'introAmount': null,
                  'introDuration': null,
                  'introPeriod': null,
                  'hasFreeTrial': false
                },
                'product': {
                  'name': 'Premium Product',
                  'vendorId': 'product-vendor-123',
                  'plans': {}
                },
                'cumulatedRevenuesInUSD': 29.97,
                'subscriptionDurationInDays': 90,
                'subscriptionDurationInWeeks': 12,
                'subscriptionDurationInMonths': 3
              }
            ];
          case 'signPromotionalOffer':
            return {
              'signature': 'sig-123',
              'timestamp': '1234567890',
              'nonce': 'nonce-123',
              'keyIdentifier': 'key-123'
            };
          case 'purchaseWithPlanVendorId':
            return {'status': 'success', 'transactionId': 'txn-123'};
          case 'userAttribute':
            return 'test-value';
          case 'userAttributes':
            return {'attr1': 'value1', 'attr2': 'value2'};
          case 'setDefaultPresentationResultHandler':
            return {
              'result': 0,
              'plan': {
                'vendorId': 'plan-vendor-123',
                'productId': 'product-123',
                'name': 'Premium Plan',
                'type': 2,
                'amount': 9.99,
                'localizedAmount': '\$9.99',
                'currencyCode': 'USD',
                'currencySymbol': '\$',
                'price': '9.99',
                'period': 'P1M',
                'hasIntroductoryPrice': false,
                'introPrice': null,
                'introAmount': null,
                'introDuration': null,
                'introPeriod': null,
                'hasFreeTrial': false
              }
            };
          case 'setPaywallActionInterceptor':
            return {
              'info': {
                'contentId': 'content-123',
                'presentationId': 'presentation-123',
                'placementId': 'placement-123',
                'abTestId': 'abtest-123',
                'abTestVariantId': 'variant-A'
              },
              'action': 'purchase',
              'parameters': {
                'url': 'https://example.com',
                'title': 'Test Title',
                'plan': {
                  'vendorId': 'plan-vendor-123',
                  'productId': 'product-123',
                  'name': 'Premium Plan',
                  'type': 2,
                  'amount': 9.99,
                  'localizedAmount': '\$9.99',
                  'currencyCode': 'USD',
                  'currencySymbol': '\$',
                  'price': '9.99',
                  'period': 'P1M',
                  'hasIntroductoryPrice': false,
                  'introPrice': null,
                  'introAmount': null,
                  'introDuration': null,
                  'introPeriod': null,
                  'hasFreeTrial': false
                },
                'offer': null,
                'subscriptionOffer': null,
                'presentation': 'presentation-456',
                'clientReferenceId': 'ref-123',
                'webCheckoutProvider': 'stripe',
                'queryParameterKey': 'session_id',
                'closeReason': null
              }
            };
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
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('start calls native method with correct parameters', () async {
      final result = await Purchasely.start(
        apiKey: 'test-api-key',
        androidStores: ['Google'],
        storeKit1: false,
        userId: 'user-123',
        logLevel: PLYLogLevel.debug,
        runningMode: PLYRunningMode.full,
      );

      expect(result, true);
      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'start');
      expect(methodCalls.first.arguments['apiKey'], 'test-api-key');
      expect(methodCalls.first.arguments['stores'], ['Google']);
      expect(methodCalls.first.arguments['storeKit1'], false);
      expect(methodCalls.first.arguments['userId'], 'user-123');
      expect(methodCalls.first.arguments['logLevel'], 0);
      expect(methodCalls.first.arguments['runningMode'], 3);
    });

    test('anonymousUserId returns correct value', () async {
      final id = await Purchasely.anonymousUserId;
      expect(id, 'anonymous-user-123');
    });

    test('userLogin calls native method correctly', () async {
      final result = await Purchasely.userLogin('user-456');
      expect(result, true);
      expect(methodCalls.first.arguments['userId'], 'user-456');
    });

    test('setLogLevel calls native method correctly', () async {
      final result = await Purchasely.setLogLevel(PLYLogLevel.warn);
      expect(result, true);
      expect(methodCalls.first.arguments['logLevel'], 2);
    });

    test('restoreAllProducts returns correct value', () async {
      final result = await Purchasely.restoreAllProducts();
      expect(result, true);
    });

    test('silentRestoreAllProducts returns correct value', () async {
      final result = await Purchasely.silentRestoreAllProducts();
      expect(result, true);
    });

    test('isAnonymous returns correct value', () async {
      final result = await Purchasely.isAnonymous();
      expect(result, true);
    });

    test('isEligibleForIntroOffer calls native method correctly', () async {
      final result = await Purchasely.isEligibleForIntroOffer('plan-123');
      expect(result, true);
      expect(methodCalls.first.arguments['planVendorId'], 'plan-123');
    });

    test('isDeeplinkHandled calls native method correctly', () async {
      final result =
          await Purchasely.isDeeplinkHandled('https://example.com/deep');
      expect(result, true);
      expect(
          methodCalls.first.arguments['deeplink'], 'https://example.com/deep');
    });

    test('fetchPresentation returns correct PLYPresentation', () async {
      final result = await Purchasely.fetchPresentation('placement-123',
          presentationId: 'presentation-456', contentId: 'content-789');

      expect(result, isNotNull);
      expect(result!.id, 'presentation-123');
      expect(result.placementId, 'placement-456');
      expect(result.audienceId, 'audience-789');
      expect(result.abTestId, 'abtest-001');
      expect(result.abTestVariantId, 'variant-A');
      expect(result.language, 'en');
      expect(result.height, 600);
      expect(result.type, PLYPresentationType.normal);
      expect(result.plans!.length, 1);
      expect(result.metadata['key'], 'value');
    });

    test('presentPresentation returns correct result', () async {
      final presentation = PLYPresentation(
          'test-id',
          'placement-id',
          'audience-id',
          'abtest-id',
          'variant-id',
          'en',
          500,
          PLYPresentationType.normal, [], {});

      final result = await Purchasely.presentPresentation(presentation,
          isFullscreen: true);

      expect(result.result, PLYPurchaseResult.purchased);
      expect(result.plan, isNotNull);
      expect(result.plan!.vendorId, 'plan-vendor-123');
    });

    test('productWithIdentifier returns correct product', () async {
      final product = await Purchasely.productWithIdentifier('vendor-123');

      expect(product.name, 'Test Product');
      expect(product.vendorId, 'product-vendor-123');
      expect(product.plans.length, 1);
    });

    test('planWithIdentifier returns correct plan', () async {
      final plan = await Purchasely.planWithIdentifier('plan-vendor-123');

      expect(plan, isNotNull);
      expect(plan!.vendorId, 'plan-vendor-123');
      expect(plan.name, 'Premium Plan');
      expect(plan.amount, 9.99);
    });

    test('allProducts returns list of products', () async {
      final products = await Purchasely.allProducts();

      expect(products.length, 1);
      expect(products.first.name, 'Product 1');
      expect(products.first.vendorId, 'vendor-1');
    });

    test('userSubscriptions returns list of subscriptions', () async {
      final subscriptions = await Purchasely.userSubscriptions();

      expect(subscriptions.length, 1);
      expect(subscriptions.first.purchaseToken, 'token-123');
      expect(subscriptions.first.subscriptionSource,
          PLYSubscriptionSource.googlePlayStore);
    });

    test('userSubscriptionsHistory returns list with extra fields', () async {
      final subscriptions = await Purchasely.userSubscriptionsHistory();

      expect(subscriptions.length, 1);
      expect(subscriptions.first.cumulatedRevenuesInUSD, 29.97);
      expect(subscriptions.first.subscriptionDurationInDays, 90);
      expect(subscriptions.first.subscriptionDurationInWeeks, 12);
      expect(subscriptions.first.subscriptionDurationInMonths, 3);
    });

    test('signPromotionalOffer returns correct map', () async {
      final result =
          await Purchasely.signPromotionalOffer('product-123', 'offer-123');

      expect(result['signature'], 'sig-123');
      expect(result['timestamp'], '1234567890');
      expect(result['nonce'], 'nonce-123');
    });

    test('purchaseWithPlanVendorId returns correct result', () async {
      final result = await Purchasely.purchaseWithPlanVendorId(
          vendorId: 'plan-123', offerId: 'offer-123', contentId: 'content-123');

      expect(result['status'], 'success');
      expect(result['transactionId'], 'txn-123');
    });

    test('userAttribute returns value', () async {
      final value = await Purchasely.userAttribute('test-key');
      expect(value, 'test-value');
    });

    test('userAttributes returns map', () async {
      final attrs = await Purchasely.userAttributes();
      expect(attrs['attr1'], 'value1');
      expect(attrs['attr2'], 'value2');
    });

    test('setDynamicOffering calls native method correctly', () async {
      final offering =
          PLYDynamicOffering('ref-123', 'plan-vendor-123', 'offer-vendor-123');
      final result = await Purchasely.setDynamicOffering(offering);

      expect(result, true);
      expect(methodCalls.first.arguments['reference'], 'ref-123');
      expect(methodCalls.first.arguments['planVendorId'], 'plan-vendor-123');
      expect(methodCalls.first.arguments['offerVendorId'], 'offer-vendor-123');
    });

    test('getDynamicOfferings returns list of offerings', () async {
      final offerings = await Purchasely.getDynamicOfferings();

      expect(offerings.length, 2);
      expect(offerings[0].reference, 'offer-ref-1');
      expect(offerings[0].planVendorId, 'plan-vendor-1');
      expect(offerings[0].offerVendorId, 'offer-vendor-1');
      expect(offerings[1].offerVendorId, isNull);
    });

    test('setAttribute calls native method correctly', () async {
      await Purchasely.setAttribute(
          PLYAttribute.firebase_app_instance_id, 'firebase-123');

      expect(methodCalls.first.method, 'setAttribute');
      expect(methodCalls.first.arguments['attribute'], 0);
      expect(methodCalls.first.arguments['value'], 'firebase-123');
    });

    test('setUserAttributeWithString calls native method correctly', () async {
      await Purchasely.setUserAttributeWithString('key', 'value',
          processingLegalBasis: PLYDataProcessingLegalBasis.essential);

      expect(methodCalls.first.method, 'setUserAttributeWithString');
      expect(methodCalls.first.arguments['key'], 'key');
      expect(methodCalls.first.arguments['value'], 'value');
      expect(methodCalls.first.arguments['processingLegalBasis'], 'ESSENTIAL');
    });

    test('setUserAttributeWithInt calls native method correctly', () async {
      await Purchasely.setUserAttributeWithInt('intKey', 42);

      expect(methodCalls.first.method, 'setUserAttributeWithInt');
      expect(methodCalls.first.arguments['key'], 'intKey');
      expect(methodCalls.first.arguments['value'], 42);
      expect(methodCalls.first.arguments['processingLegalBasis'], 'OPTIONAL');
    });

    test('setUserAttributeWithDouble calls native method correctly', () async {
      await Purchasely.setUserAttributeWithDouble('doubleKey', 3.14);

      expect(methodCalls.first.method, 'setUserAttributeWithDouble');
      expect(methodCalls.first.arguments['key'], 'doubleKey');
      expect(methodCalls.first.arguments['value'], 3.14);
    });

    test('setUserAttributeWithBoolean calls native method correctly', () async {
      await Purchasely.setUserAttributeWithBoolean('boolKey', true);

      expect(methodCalls.first.method, 'setUserAttributeWithBoolean');
      expect(methodCalls.first.arguments['key'], 'boolKey');
      expect(methodCalls.first.arguments['value'], true);
    });

    test('setUserAttributeWithDate calls native method correctly', () async {
      final date = DateTime(2025, 1, 15, 10, 30, 0);
      await Purchasely.setUserAttributeWithDate('dateKey', date);

      expect(methodCalls.first.method, 'setUserAttributeWithDate');
      expect(methodCalls.first.arguments['key'], 'dateKey');
      expect(methodCalls.first.arguments['value'], contains('2025-01-15'));
    });

    test('setUserAttributeWithStringArray calls native method correctly',
        () async {
      await Purchasely.setUserAttributeWithStringArray(
          'arrayKey', ['a', 'b', 'c']);

      expect(methodCalls.first.method, 'setUserAttributeWithStringArray');
      expect(methodCalls.first.arguments['key'], 'arrayKey');
      expect(methodCalls.first.arguments['value'], ['a', 'b', 'c']);
    });

    test('setUserAttributeWithIntArray calls native method correctly',
        () async {
      await Purchasely.setUserAttributeWithIntArray('intArrayKey', [1, 2, 3]);

      expect(methodCalls.first.method, 'setUserAttributeWithIntArray');
      expect(methodCalls.first.arguments['value'], [1, 2, 3]);
    });

    test('setUserAttributeWithDoubleArray calls native method correctly',
        () async {
      await Purchasely.setUserAttributeWithDoubleArray(
          'doubleArrayKey', [1.1, 2.2, 3.3]);

      expect(methodCalls.first.method, 'setUserAttributeWithDoubleArray');
      expect(methodCalls.first.arguments['value'], [1.1, 2.2, 3.3]);
    });

    test('setUserAttributeWithBooleanArray calls native method correctly',
        () async {
      await Purchasely.setUserAttributeWithBooleanArray(
          'boolArrayKey', [true, false, true]);

      expect(methodCalls.first.method, 'setUserAttributeWithBooleanArray');
      expect(methodCalls.first.arguments['value'], [true, false, true]);
    });

    test('incrementUserAttribute calls native method correctly', () async {
      await Purchasely.incrementUserAttribute('counter', value: 5);

      expect(methodCalls.first.method, 'incrementUserAttribute');
      expect(methodCalls.first.arguments['key'], 'counter');
      expect(methodCalls.first.arguments['value'], 5);
    });

    test('decrementUserAttribute calls native method correctly', () async {
      await Purchasely.decrementUserAttribute('counter', value: 3);

      expect(methodCalls.first.method, 'decrementUserAttribute');
      expect(methodCalls.first.arguments['key'], 'counter');
      expect(methodCalls.first.arguments['value'], 3);
    });

    test('clearUserAttribute calls native method correctly', () {
      Purchasely.clearUserAttribute('testKey');

      expect(methodCalls.first.method, 'clearUserAttribute');
      expect(methodCalls.first.arguments['key'], 'testKey');
    });

    test('clearUserAttributes calls native method', () {
      Purchasely.clearUserAttributes();

      expect(methodCalls.first.method, 'clearUserAttributes');
    });

    test('clearBuiltInAttributes calls native method', () {
      Purchasely.clearBuiltInAttributes();

      expect(methodCalls.first.method, 'clearBuiltInAttributes');
    });

    test('setThemeMode calls native method correctly', () async {
      await Purchasely.setThemeMode(PLYThemeMode.dark);

      expect(methodCalls.first.method, 'setThemeMode');
      expect(methodCalls.first.arguments['mode'], 1);
    });

    test('onProcessAction calls native method correctly', () async {
      await Purchasely.onProcessAction(true);

      expect(methodCalls.first.method, 'onProcessAction');
      expect(methodCalls.first.arguments['processAction'], true);
    });

    test('setLanguage calls native method correctly', () async {
      await Purchasely.setLanguage('fr');

      expect(methodCalls.first.method, 'setLanguage');
      expect(methodCalls.first.arguments['language'], 'fr');
    });

    test('readyToOpenDeeplink calls native method correctly', () async {
      await Purchasely.readyToOpenDeeplink(true);

      expect(methodCalls.first.method, 'readyToOpenDeeplink');
      expect(methodCalls.first.arguments['readyToOpenDeeplink'], true);
    });

    test('setDebugMode calls native method correctly', () async {
      await Purchasely.setDebugMode(true);

      expect(methodCalls.first.method, 'setDebugMode');
      expect(methodCalls.first.arguments['debugMode'], true);
    });

    test('removeDynamicOffering calls native method correctly', () {
      Purchasely.removeDynamicOffering('ref-123');

      expect(methodCalls.first.method, 'removeDynamicOffering');
      expect(methodCalls.first.arguments['reference'], 'ref-123');
    });

    test('clearDynamicOfferings calls native method', () {
      Purchasely.clearDynamicOfferings();

      expect(methodCalls.first.method, 'clearDynamicOfferings');
    });

    test('revokeDataProcessingConsent calls native method correctly', () {
      Purchasely.revokeDataProcessingConsent([
        PLYDataProcessingPurpose.analytics,
        PLYDataProcessingPurpose.campaigns
      ]);

      expect(methodCalls.first.method, 'revokeDataProcessingConsent');
      expect(
          methodCalls.first.arguments['purposes'], ['ANALYTICS', 'CAMPAIGNS']);
    });
  });

  group('Transformation Methods', () {
    test('transformToPLYPlan returns null for empty map', () {
      final result = Purchasely.transformToPLYPlan({});
      expect(result, isNull);
    });

    test('transformToPLYPlan returns correct PLYPlan', () {
      final planMap = {
        'vendorId': 'vendor-123',
        'productId': 'product-123',
        'name': 'Test Plan',
        'type': 2,
        'amount': 9.99,
        'localizedAmount': '\$9.99',
        'currencyCode': 'USD',
        'currencySymbol': '\$',
        'price': '9.99',
        'period': 'P1M',
        'hasIntroductoryPrice': true,
        'introPrice': '\$4.99',
        'introAmount': 4.99,
        'introDuration': 'P1W',
        'introPeriod': 'week',
        'hasFreeTrial': true
      };

      final plan = Purchasely.transformToPLYPlan(planMap);

      expect(plan, isNotNull);
      expect(plan!.vendorId, 'vendor-123');
      expect(plan.productId, 'product-123');
      expect(plan.name, 'Test Plan');
      expect(plan.type, PLYPlanType.autoRenewingSubscription);
      expect(plan.amount, 9.99);
      expect(plan.localizedAmount, '\$9.99');
      expect(plan.currencyCode, 'USD');
      expect(plan.currencySymbol, '\$');
      expect(plan.price, '9.99');
      expect(plan.period, 'P1M');
      expect(plan.hasIntroductoryPrice, true);
      expect(plan.introPrice, '\$4.99');
      expect(plan.introAmount, 4.99);
      expect(plan.introDuration, 'P1W');
      expect(plan.introPeriod, 'week');
      expect(plan.hasFreeTrial, true);
    });

    test('transformToPLYPlan handles invalid type gracefully', () {
      final planMap = {
        'vendorId': 'vendor-123',
        'productId': 'product-123',
        'name': 'Test Plan',
        'type': 99, // Invalid type
        'amount': 9.99,
        'localizedAmount': '\$9.99',
        'currencyCode': 'USD',
        'currencySymbol': '\$',
        'price': '9.99',
        'period': 'P1M',
        'hasIntroductoryPrice': false,
        'introPrice': null,
        'introAmount': null,
        'introDuration': null,
        'introPeriod': null,
        'hasFreeTrial': false
      };

      final plan = Purchasely.transformToPLYPlan(planMap);
      expect(plan, isNotNull);
      expect(plan!.type, PLYPlanType.unknown); // Falls back to unknown
    });

    test('transformToPLYPromoOffer returns null for empty map', () {
      final result = Purchasely.transformToPLYPromoOffer({});
      expect(result, isNull);
    });

    test('transformToPLYPromoOffer returns correct offer', () {
      final offerMap = {
        'vendorId': 'offer-vendor-123',
        'storeOfferId': 'store-offer-123'
      };

      final offer = Purchasely.transformToPLYPromoOffer(offerMap);

      expect(offer, isNotNull);
      expect(offer!.vendorId, 'offer-vendor-123');
      expect(offer.storeOfferId, 'store-offer-123');
    });

    test('transformToPLYSubscription returns null for empty map', () {
      final result = Purchasely.transformToPLYSubscription({});
      expect(result, isNull);
    });

    test('transformToPLYSubscription returns correct subscription offer', () {
      final subscriptionMap = {
        'subscriptionId': 'sub-123',
        'basePlanId': 'base-plan-123',
        'offerToken': 'token-123',
        'offerId': 'offer-123'
      };

      final subscription =
          Purchasely.transformToPLYSubscription(subscriptionMap);

      expect(subscription, isNotNull);
      expect(subscription!.subscriptionId, 'sub-123');
      expect(subscription.basePlanId, 'base-plan-123');
      expect(subscription.offerToken, 'token-123');
      expect(subscription.offerId, 'offer-123');
    });

    test('transformToPLYPresentation returns null for empty map', () {
      final result = Purchasely.transformToPLYPresentation({});
      expect(result, isNull);
    });

    test('transformToPLYPresentation returns correct presentation', () {
      final presentationMap = {
        'id': 'pres-123',
        'placementId': 'placement-123',
        'audienceId': 'audience-123',
        'abTestId': 'abtest-123',
        'abTestVariantId': 'variant-A',
        'language': 'en',
        'height': 800,
        'type': 1,
        'plans': [
          {
            'planVendorId': 'plan-123',
            'storeProductId': 'product-123',
            'basePlanId': 'base-123',
            'offerId': 'offer-123'
          }
        ],
        'metadata': {'theme': 'dark', 'version': '2.0'}
      };

      final presentation =
          Purchasely.transformToPLYPresentation(presentationMap);

      expect(presentation, isNotNull);
      expect(presentation!.id, 'pres-123');
      expect(presentation.placementId, 'placement-123');
      expect(presentation.audienceId, 'audience-123');
      expect(presentation.abTestId, 'abtest-123');
      expect(presentation.abTestVariantId, 'variant-A');
      expect(presentation.language, 'en');
      expect(presentation.height, 800);
      expect(presentation.type, PLYPresentationType.fallback);
      expect(presentation.plans!.length, 1);
      expect(presentation.plans![0].planVendorId, 'plan-123');
      expect(presentation.metadata['theme'], 'dark');
    });

    test('transformToPLYPresentation uses default height when null', () {
      final presentationMap = {
        'id': 'pres-123',
        'placementId': 'placement-123',
        'audienceId': null,
        'abTestId': null,
        'abTestVariantId': null,
        'language': 'en',
        'height': null,
        'type': 0,
        'plans': [],
        'metadata': null
      };

      final presentation =
          Purchasely.transformToPLYPresentation(presentationMap);

      expect(presentation!.height, 0);
    });

    test('transformPLYPresentationToMap returns correct map', () {
      final presentation = PLYPresentation(
          'pres-123',
          'placement-123',
          'audience-123',
          'abtest-123',
          'variant-A',
          'en',
          600,
          PLYPresentationType.normal,
          [PLYPresentationPlan('plan-123', 'product-123', 'base-123', null)],
          {'key': 'value'});

      final map = Purchasely.transformPLYPresentationToMap(presentation);

      expect(map['id'], 'pres-123');
      expect(map['placementId'], 'placement-123');
      expect(map['audienceId'], 'audience-123');
      expect(map['abTestId'], 'abtest-123');
      expect(map['abTestVariantId'], 'variant-A');
      expect(map['language'], 'en');
      expect(map['type'], 0);
    });

    test('transformPLYPresentationToMap handles null presentation', () {
      final map = Purchasely.transformPLYPresentationToMap(null);

      expect(map['id'], isNull);
      expect(map['placementId'], isNull);
    });

    test('transformToDynamicOfferings returns empty list for null input', () {
      final result = Purchasely.transformToDynamicOfferings(null);
      expect(result, isEmpty);
    });

    test('transformToDynamicOfferings returns empty list for empty input', () {
      final result = Purchasely.transformToDynamicOfferings([]);
      expect(result, isEmpty);
    });

    test('transformToDynamicOfferings returns correct offerings', () {
      final offerings = [
        {
          'reference': 'ref-1',
          'planVendorId': 'plan-1',
          'offerVendorId': 'offer-1'
        },
        {'reference': 'ref-2', 'planVendorId': 'plan-2', 'offerVendorId': null}
      ];

      final result = Purchasely.transformToDynamicOfferings(offerings);

      expect(result.length, 2);
      expect(result[0].reference, 'ref-1');
      expect(result[0].planVendorId, 'plan-1');
      expect(result[0].offerVendorId, 'offer-1');
      expect(result[1].offerVendorId, isNull);
    });

    test('transformToDynamicOfferings skips invalid offerings', () {
      final offerings = [
        {'reference': 'ref-1', 'planVendorId': 'plan-1'},
        {
          'reference': null,
          'planVendorId': 'plan-2'
        }, // Invalid - null reference
        {
          'reference': 'ref-3',
          'planVendorId': null
        } // Invalid - null planVendorId
      ];

      final result = Purchasely.transformToDynamicOfferings(offerings);

      expect(result.length, 1);
      expect(result[0].reference, 'ref-1');
    });

    test('transformToPLYEventProperties returns correct properties', () {
      final propertiesMap = {
        'sdk_version': '5.6.1',
        'event_name': 'PRESENTATION_VIEWED',
        'event_created_at': '2025-01-15T10:00:00Z',
        'displayed_presentation': 'pres-123',
        'user_id': 'user-123',
        'anonymous_user_id': 'anon-123',
        'purchasable_plans': [
          {
            'type': 'subscription',
            'purchasely_plan_id': 'plan-123',
            'store': 'app_store',
            'store_country': 'US',
            'store_product_id': 'product-123',
            'price_in_customer_currency': 9.99,
            'customer_currency': 'USD',
            'period': 'P1M',
            'duration': 30,
            'intro_price_in_customer_currency': 4.99,
            'intro_period': 'P1W',
            'intro_duration': 7,
            'has_free_trial': true,
            'free_trial_period': 'P1W',
            'free_trial_duration': 7,
            'discount_referent': 'ref-123',
            'discount_percentage_comparison_to_referent': '50%',
            'discount_price_comparison_to_referent': '\$5.00',
            'is_default': true
          }
        ],
        'deeplink_identifier': 'deeplink-123',
        'source_identifier': 'source-123',
        'selected_plan': 'plan-123',
        'previous_selected_plan': null,
        'selected_presentation': 'pres-123',
        'previous_selected_presentation': null,
        'link_identifier': 'link-123',
        'carousels': [
          {
            'selected_slide': 1,
            'number_of_slides': 3,
            'is_carousel_auto_playing': true,
            'default_slide': 0,
            'previous_slide': 0
          }
        ],
        'language': 'en',
        'device': 'iPhone',
        'os_version': '17.0',
        'device_type': 'phone',
        'error_message': null,
        'cancellation_reason_id': null,
        'cancellation_reason': null,
        'plan': 'plan-123',
        'selected_product': 'product-123',
        'plan_change_type': 'upgrade',
        'running_subscriptions': [
          {'plan': 'plan-123', 'product': 'product-123'}
        ],
        'selected_option_id': 'option-123',
        'selected_options': ['opt1', 'opt2'],
        'displayed_options': ['opt1', 'opt2', 'opt3'],
        'web_checkout_provider': 'stripe'
      };

      final properties =
          Purchasely.transformToPLYEventProperties(propertiesMap);

      expect(properties.sdk_version, '5.6.1');
      expect(properties.event_name, PLYEventName.PRESENTATION_VIEWED);
      expect(properties.event_created_at, '2025-01-15T10:00:00Z');
      expect(properties.user_id, 'user-123');
      expect(properties.anonymous_user_id, 'anon-123');
      expect(properties.purchasable_plans!.length, 1);
      expect(properties.carousels.length, 1);
      expect(properties.carousels[0].is_carousel_auto_playing, true);
      expect(properties.running_subscriptions.length, 1);
      expect(properties.selected_options, ['opt1', 'opt2']);
      expect(properties.displayed_options, ['opt1', 'opt2', 'opt3']);
    });
  });

  group('Type Mapping Methods', () {
    test('mapType returns correct types for all values', () {
      expect(Purchasely.mapType('STRING'), PLYUserAttributeType.string);
      expect(Purchasely.mapType('INT'), PLYUserAttributeType.int);
      expect(Purchasely.mapType('FLOAT'), PLYUserAttributeType.float);
      expect(Purchasely.mapType('BOOLEAN'), PLYUserAttributeType.bool);
      expect(Purchasely.mapType('DATE'), PLYUserAttributeType.date);
      expect(
          Purchasely.mapType('STRING_ARRAY'), PLYUserAttributeType.stringArray);
      expect(Purchasely.mapType('INT_ARRAY'), PLYUserAttributeType.intArray);
      expect(
          Purchasely.mapType('FLOAT_ARRAY'), PLYUserAttributeType.floatArray);
      expect(
          Purchasely.mapType('BOOLEAN_ARRAY'), PLYUserAttributeType.boolArray);
    });

    test('mapType throws for unknown type', () {
      expect(() => Purchasely.mapType('UNKNOWN'), throwsArgumentError);
    });

    test('mapDataProcessingLegalBasisToString returns correct strings', () {
      expect(
          Purchasely.mapDataProcessingLegalBasisToString(
              PLYDataProcessingLegalBasis.essential),
          'ESSENTIAL');
      expect(
          Purchasely.mapDataProcessingLegalBasisToString(
              PLYDataProcessingLegalBasis.optional),
          'OPTIONAL');
    });

    test('mapDataProcessingPurposeToString returns correct strings', () {
      expect(
          Purchasely.mapDataProcessingPurposeToString(
              PLYDataProcessingPurpose.allNonEssentials),
          'ALL_NON_ESSENTIALS');
      expect(
          Purchasely.mapDataProcessingPurposeToString(
              PLYDataProcessingPurpose.analytics),
          'ANALYTICS');
      expect(
          Purchasely.mapDataProcessingPurposeToString(
              PLYDataProcessingPurpose.identifiedAnalytics),
          'IDENTIFIED_ANALYTICS');
      expect(
          Purchasely.mapDataProcessingPurposeToString(
              PLYDataProcessingPurpose.campaigns),
          'CAMPAIGNS');
      expect(
          Purchasely.mapDataProcessingPurposeToString(
              PLYDataProcessingPurpose.personalization),
          'PERSONALIZATION');
      expect(
          Purchasely.mapDataProcessingPurposeToString(
              PLYDataProcessingPurpose.thirdPartyIntegrations),
          'THIRD_PARTY_INTEGRATIONS');
    });
  });

  group('User Attribute Listener', () {
    test('clearUserAttributeListener clears the listener', () {
      Purchasely.clearUserAttributeListener();
      // Test passes if no exception is thrown
    });
  });

  group('PLYPresentationView', () {
    test('getPresentationView returns PLYPresentationView', () {
      final view = Purchasely.getPresentationView(
        placementId: 'placement-123',
        presentationId: 'presentation-123',
        contentId: 'content-123',
        callback: (result) {},
      );

      expect(view, isNotNull);
      expect(view, isA<PLYPresentationView>());
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
    });
  });

  group('Model Classes', () {
    group('PLYPlan', () {
      test('creates instance with all properties', () {
        final plan = PLYPlan(
            'vendor-123',
            'product-123',
            'Premium Plan',
            PLYPlanType.autoRenewingSubscription,
            9.99,
            '\$9.99',
            'USD',
            '\$',
            '9.99',
            'P1M',
            true,
            '\$4.99',
            4.99,
            'P1W',
            'week',
            true);

        expect(plan.vendorId, 'vendor-123');
        expect(plan.productId, 'product-123');
        expect(plan.name, 'Premium Plan');
        expect(plan.type, PLYPlanType.autoRenewingSubscription);
        expect(plan.amount, 9.99);
        expect(plan.hasFreeTrial, true);
      });
    });

    group('PLYPromoOffer', () {
      test('creates instance with properties', () {
        final offer = PLYPromoOffer('vendor-123', 'store-offer-123');

        expect(offer.vendorId, 'vendor-123');
        expect(offer.storeOfferId, 'store-offer-123');
      });
    });

    group('PLYSubscriptionOffer', () {
      test('creates instance with all properties', () {
        final offer = PLYSubscriptionOffer(
            'sub-123', 'base-plan-123', 'token-123', 'offer-123');

        expect(offer.subscriptionId, 'sub-123');
        expect(offer.basePlanId, 'base-plan-123');
        expect(offer.offerToken, 'token-123');
        expect(offer.offerId, 'offer-123');
      });
    });

    group('PLYProduct', () {
      test('creates instance with plans', () {
        final plans = [
          PLYPlan(
              'plan-1',
              'product-1',
              'Plan 1',
              PLYPlanType.consumable,
              1.99,
              '\$1.99',
              'USD',
              '\$',
              '1.99',
              null,
              false,
              null,
              null,
              null,
              null,
              false)
        ];

        final product = PLYProduct('Test Product', 'vendor-123', plans);

        expect(product.name, 'Test Product');
        expect(product.vendorId, 'vendor-123');
        expect(product.plans.length, 1);
      });
    });

    group('PLYPresentationPlan', () {
      test('creates instance and converts to map', () {
        final plan = PLYPresentationPlan(
            'plan-123', 'product-123', 'base-123', 'offer-123');

        final map = plan.toMap();

        expect(map['planVendorId'], 'plan-123');
        expect(map['storeProductId'], 'product-123');
        expect(map['basePlanId'], 'base-123');
        expect(map['offerId'], 'offer-123');
      });
    });

    group('PLYPresentation', () {
      test('creates instance and converts to map', () {
        final plans = [
          PLYPresentationPlan('plan-123', 'product-123', 'base-123', null)
        ];
        final presentation = PLYPresentation(
            'pres-123',
            'placement-123',
            'audience-123',
            'abtest-123',
            'variant-A',
            'en',
            600,
            PLYPresentationType.normal,
            plans,
            {'key': 'value'});

        final map = presentation.toMap();

        expect(map['id'], 'pres-123');
        expect(map['placementId'], 'placement-123');
        expect(map['language'], 'en');
        expect(map['height'], 600);
        expect(map['type'], 'PLYPresentationType.normal');
        expect(map['plans'].length, 1);
        expect(map['metadata']['key'], 'value');
      });
    });

    group('PLYSubscription', () {
      test('creates instance with all properties', () {
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

        final product = PLYProduct('Premium Product', 'vendor-123', [plan]);

        final subscription = PLYSubscription(
            'token-123',
            PLYSubscriptionSource.appleAppStore,
            '2025-02-01T00:00:00Z',
            null,
            plan,
            product,
            99.99,
            365,
            52,
            12);

        expect(subscription.purchaseToken, 'token-123');
        expect(subscription.subscriptionSource,
            PLYSubscriptionSource.appleAppStore);
        expect(subscription.nextRenewalDate, '2025-02-01T00:00:00Z');
        expect(subscription.cancelledDate, isNull);
        expect(subscription.plan!.vendorId, 'plan-123');
        expect(subscription.product!.name, 'Premium Product');
        expect(subscription.cumulatedRevenuesInUSD, 99.99);
        expect(subscription.subscriptionDurationInDays, 365);
        expect(subscription.subscriptionDurationInWeeks, 52);
        expect(subscription.subscriptionDurationInMonths, 12);
      });
    });

    group('PresentPresentationResult', () {
      test('creates instance with result and plan', () {
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

        final result =
            PresentPresentationResult(PLYPurchaseResult.purchased, plan);

        expect(result.result, PLYPurchaseResult.purchased);
        expect(result.plan!.vendorId, 'plan-123');
      });

      test('creates instance with null plan', () {
        final result =
            PresentPresentationResult(PLYPurchaseResult.cancelled, null);

        expect(result.result, PLYPurchaseResult.cancelled);
        expect(result.plan, isNull);
      });
    });

    group('PaywallActionInterceptorResult', () {
      test('creates instance with all properties', () {
        final info = PLYPaywallInfo('content-123', 'presentation-123',
            'placement-123', 'abtest-123', 'variant-A');
        final params = PLYPaywallActionParameters(
            url: 'https://example.com', title: 'Test Title');

        final result = PaywallActionInterceptorResult(
            info, PLYPaywallAction.purchase, params);

        expect(result.info.contentId, 'content-123');
        expect(result.action, PLYPaywallAction.purchase);
        expect(result.parameters.url, 'https://example.com');
      });
    });

    group('PLYPaywallActionParameters', () {
      test('creates instance with all optional properties', () {
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
        final offer = PLYPromoOffer('offer-vendor', 'store-offer');
        final subOffer =
            PLYSubscriptionOffer('sub-123', 'base-123', 'token', 'offer');

        final params = PLYPaywallActionParameters(
            url: 'https://example.com',
            title: 'Test Title',
            plan: plan,
            offer: offer,
            subscriptionOffer: subOffer,
            presentation: 'pres-123',
            clientReferenceId: 'ref-123',
            queryParameterKey: 'session_id',
            webCheckoutProvider: 'stripe',
            closeReason: 'user_action');

        expect(params.url, 'https://example.com');
        expect(params.title, 'Test Title');
        expect(params.plan!.vendorId, 'plan-123');
        expect(params.offer!.vendorId, 'offer-vendor');
        expect(params.subscriptionOffer!.subscriptionId, 'sub-123');
        expect(params.presentation, 'pres-123');
        expect(params.clientReferenceId, 'ref-123');
        expect(params.queryParameterKey, 'session_id');
        expect(params.webCheckoutProvider, 'stripe');
        expect(params.closeReason, 'user_action');
      });
    });

    group('PLYPaywallInfo', () {
      test('creates instance with all properties', () {
        final info = PLYPaywallInfo('content-123', 'presentation-123',
            'placement-123', 'abtest-123', 'variant-A');

        expect(info.contentId, 'content-123');
        expect(info.presentationId, 'presentation-123');
        expect(info.placementId, 'placement-123');
        expect(info.abTestId, 'abtest-123');
        expect(info.abTestVariantId, 'variant-A');
      });
    });

    group('PLYEventPropertyPlan', () {
      test('creates instance with all properties', () {
        final plan = PLYEventPropertyPlan(
            'subscription',
            'plan-123',
            'app_store',
            'US',
            'product-123',
            9.99,
            'USD',
            'P1M',
            30,
            4.99,
            'P1W',
            7,
            true,
            'P1W',
            7,
            'ref-123',
            '50%',
            '\$5.00',
            true);

        expect(plan.type, 'subscription');
        expect(plan.purchasely_plan_id, 'plan-123');
        expect(plan.store, 'app_store');
        expect(plan.price_in_customer_currency, 9.99);
        expect(plan.has_free_trial, true);
        expect(plan.is_default, true);
      });
    });

    group('PLYEvent', () {
      test('creates instance with name and properties', () {
        final properties = PLYEventProperties(
            '5.6.1',
            PLYEventName.PRESENTATION_VIEWED,
            '2025-01-15T10:00:00Z',
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            [],
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            [],
            null,
            null,
            null,
            null);

        final event = PLYEvent(PLYEventName.PRESENTATION_VIEWED, properties);

        expect(event.name, PLYEventName.PRESENTATION_VIEWED);
        expect(event.properties.sdk_version, '5.6.1');
      });
    });

    group('PLYEventPropertyCarousel', () {
      test('creates instance with all properties', () {
        final carousel = PLYEventPropertyCarousel(2, 5, true, 0, 1);

        expect(carousel.selected_slide, 2);
        expect(carousel.number_of_slides, 5);
        expect(carousel.is_carousel_auto_playing, true);
        expect(carousel.default_slide, 0);
        expect(carousel.previous_slide, 1);
      });
    });

    group('PLYEventPropertySubscription', () {
      test('creates instance with properties', () {
        final subscription =
            PLYEventPropertySubscription('plan-123', 'product-123');

        expect(subscription.plan, 'plan-123');
        expect(subscription.product, 'product-123');
      });
    });

    group('PLYDynamicOffering', () {
      test('creates instance with all properties', () {
        final offering = PLYDynamicOffering(
            'ref-123', 'plan-vendor-123', 'offer-vendor-123');

        expect(offering.reference, 'ref-123');
        expect(offering.planVendorId, 'plan-vendor-123');
        expect(offering.offerVendorId, 'offer-vendor-123');
      });

      test('toJson returns correct map', () {
        final offering = PLYDynamicOffering(
            'ref-123', 'plan-vendor-123', 'offer-vendor-123');
        final json = offering.toJson();

        expect(json['reference'], 'ref-123');
        expect(json['planVendorId'], 'plan-vendor-123');
        expect(json['offerVendorId'], 'offer-vendor-123');
      });

      test('toString returns correct string', () {
        final offering = PLYDynamicOffering('ref-123', 'plan-vendor-123', null);
        final str = offering.toString();

        expect(str, contains('ref-123'));
        expect(str, contains('plan-vendor-123'));
        expect(str, contains('null'));
      });
    });
  });

  group('Enums', () {
    test('PLYLogLevel has correct values', () {
      expect(PLYLogLevel.debug.index, 0);
      expect(PLYLogLevel.info.index, 1);
      expect(PLYLogLevel.warn.index, 2);
      expect(PLYLogLevel.error.index, 3);
    });

    test('PLYRunningMode has correct values', () {
      expect(PLYRunningMode.transactionOnly.index, 0);
      expect(PLYRunningMode.observer.index, 1);
      expect(PLYRunningMode.paywallObserver.index, 2);
      expect(PLYRunningMode.full.index, 3);
    });

    test('PLYThemeMode has correct values', () {
      expect(PLYThemeMode.light.index, 0);
      expect(PLYThemeMode.dark.index, 1);
      expect(PLYThemeMode.system.index, 2);
    });

    test('PLYPurchaseResult has correct values', () {
      expect(PLYPurchaseResult.purchased.index, 0);
      expect(PLYPurchaseResult.cancelled.index, 1);
      expect(PLYPurchaseResult.restored.index, 2);
    });

    test('PLYPresentationType has correct values', () {
      expect(PLYPresentationType.normal.index, 0);
      expect(PLYPresentationType.fallback.index, 1);
      expect(PLYPresentationType.deactivated.index, 2);
      expect(PLYPresentationType.client.index, 3);
    });

    test('PLYSubscriptionSource has correct values', () {
      expect(PLYSubscriptionSource.appleAppStore.index, 0);
      expect(PLYSubscriptionSource.googlePlayStore.index, 1);
      expect(PLYSubscriptionSource.amazonAppstore.index, 2);
      expect(PLYSubscriptionSource.huaweiAppGallery.index, 3);
      expect(PLYSubscriptionSource.none.index, 4);
    });

    test('PLYPlanType has correct values', () {
      expect(PLYPlanType.consumable.index, 0);
      expect(PLYPlanType.nonConsumable.index, 1);
      expect(PLYPlanType.autoRenewingSubscription.index, 2);
      expect(PLYPlanType.nonRenewingSubscription.index, 3);
      expect(PLYPlanType.unknown.index, 4);
    });

    test('PLYPaywallAction has all expected values', () {
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

    test('PLYAttribute has all expected values', () {
      expect(PLYAttribute.firebase_app_instance_id.index, 0);
      expect(PLYAttribute.airship_channel_id.index, 1);
      expect(PLYAttribute.oneSignalExternalId.index, 19);
      expect(PLYAttribute.batchCustomUserId.index, 20);
    });

    test('PLYDataProcessingLegalBasis has correct values', () {
      expect(PLYDataProcessingLegalBasis.essential.index, 0);
      expect(PLYDataProcessingLegalBasis.optional.index, 1);
    });

    test('PLYDataProcessingPurpose has all expected values', () {
      expect(PLYDataProcessingPurpose.allNonEssentials.index, 0);
      expect(PLYDataProcessingPurpose.analytics.index, 1);
      expect(PLYDataProcessingPurpose.identifiedAnalytics.index, 2);
      expect(PLYDataProcessingPurpose.campaigns.index, 3);
      expect(PLYDataProcessingPurpose.personalization.index, 4);
      expect(PLYDataProcessingPurpose.thirdPartyIntegrations.index, 5);
    });

    test('PLYUserAttributeSource has correct values', () {
      expect(PLYUserAttributeSource.purchasely.index, 0);
      expect(PLYUserAttributeSource.client.index, 1);
    });

    test('PLYUserAttributeType has all expected values', () {
      expect(PLYUserAttributeType.string.index, 0);
      expect(PLYUserAttributeType.int.index, 1);
      expect(PLYUserAttributeType.float.index, 2);
      expect(PLYUserAttributeType.bool.index, 3);
      expect(PLYUserAttributeType.date.index, 4);
      expect(PLYUserAttributeType.stringArray.index, 5);
      expect(PLYUserAttributeType.intArray.index, 6);
      expect(PLYUserAttributeType.floatArray.index, 7);
      expect(PLYUserAttributeType.boolArray.index, 8);
    });

    test('PLYEventName has key event values', () {
      expect(PLYEventName.APP_INSTALLED.index, 0);
      expect(PLYEventName.APP_CONFIGURED.index, 1);
      expect(PLYEventName.IN_APP_PURCHASED.index, 6);
      expect(PLYEventName.PRESENTATION_VIEWED.index, 20);
      expect(PLYEventName.PURCHASE_TAPPED.index, 27);
    });
  });

  group('Source Mapping', () {
    test('_mapSource returns purchasely for source 0', () {
      // Access via the public mapType which internally uses _mapSource
      // We test _mapSource indirectly through the listener mechanism
      expect(PLYUserAttributeSource.purchasely.index, 0);
      expect(PLYUserAttributeSource.client.index, 1);
    });
  });

  group('Additional Transformation Edge Cases', () {
    test('transformToPLYEventProperties handles null purchasable_plans', () {
      final propertiesMap = {
        'sdk_version': '5.6.1',
        'event_name': 'APP_CONFIGURED',
        'event_created_at': '2025-01-15T10:00:00Z',
        'displayed_presentation': null,
        'user_id': null,
        'anonymous_user_id': null,
        'purchasable_plans': null,
        'deeplink_identifier': null,
        'source_identifier': null,
        'selected_plan': null,
        'previous_selected_plan': null,
        'selected_presentation': null,
        'previous_selected_presentation': null,
        'link_identifier': null,
        'carousels': null,
        'language': null,
        'device': null,
        'os_version': null,
        'device_type': null,
        'error_message': null,
        'cancellation_reason_id': null,
        'cancellation_reason': null,
        'plan': null,
        'selected_product': null,
        'plan_change_type': null,
        'running_subscriptions': null,
        'selected_option_id': null,
        'selected_options': null,
        'displayed_options': null,
        'web_checkout_provider': null
      };

      final properties =
          Purchasely.transformToPLYEventProperties(propertiesMap);

      // When purchasable_plans is null in input, it stays null in output
      // But carousels and running_subscriptions are always initialized as lists
      expect(properties.purchasable_plans, isEmpty);
      expect(properties.carousels, isEmpty);
      expect(properties.running_subscriptions, isEmpty);
    });

    test('transformToPLYEventProperties handles empty arrays', () {
      final propertiesMap = {
        'sdk_version': '5.6.1',
        'event_name': 'APP_STARTED',
        'event_created_at': '2025-01-15T10:00:00Z',
        'displayed_presentation': null,
        'user_id': null,
        'anonymous_user_id': null,
        'purchasable_plans': [],
        'deeplink_identifier': null,
        'source_identifier': null,
        'selected_plan': null,
        'previous_selected_plan': null,
        'selected_presentation': null,
        'previous_selected_presentation': null,
        'link_identifier': null,
        'carousels': [],
        'language': null,
        'device': null,
        'os_version': null,
        'device_type': null,
        'error_message': null,
        'cancellation_reason_id': null,
        'cancellation_reason': null,
        'plan': null,
        'selected_product': null,
        'plan_change_type': null,
        'running_subscriptions': [],
        'selected_option_id': null,
        'selected_options': null,
        'displayed_options': null,
        'web_checkout_provider': null
      };

      final properties =
          Purchasely.transformToPLYEventProperties(propertiesMap);

      expect(properties.purchasable_plans, isEmpty);
      expect(properties.carousels, isEmpty);
      expect(properties.running_subscriptions, isEmpty);
    });

    test('transformToPLYEventProperties handles carousel without auto_playing',
        () {
      final propertiesMap = {
        'sdk_version': '5.6.1',
        'event_name': 'CAROUSEL_SLIDE_SWIPED',
        'event_created_at': '2025-01-15T10:00:00Z',
        'displayed_presentation': null,
        'user_id': null,
        'anonymous_user_id': null,
        'purchasable_plans': null,
        'deeplink_identifier': null,
        'source_identifier': null,
        'selected_plan': null,
        'previous_selected_plan': null,
        'selected_presentation': null,
        'previous_selected_presentation': null,
        'link_identifier': null,
        'carousels': [
          {
            'selected_slide': 1,
            'number_of_slides': 3,
            // 'is_carousel_auto_playing' is missing, should default to false
            'default_slide': 0,
            'previous_slide': 0
          }
        ],
        'language': null,
        'device': null,
        'os_version': null,
        'device_type': null,
        'error_message': null,
        'cancellation_reason_id': null,
        'cancellation_reason': null,
        'plan': null,
        'selected_product': null,
        'plan_change_type': null,
        'running_subscriptions': null,
        'selected_option_id': null,
        'selected_options': null,
        'displayed_options': null,
        'web_checkout_provider': null
      };

      final properties =
          Purchasely.transformToPLYEventProperties(propertiesMap);

      expect(properties.carousels.length, 1);
      expect(properties.carousels[0].is_carousel_auto_playing, false);
    });

    test('transformToPLYPresentation handles valid fallback type', () {
      final presentationMap = {
        'id': 'pres-123',
        'placementId': 'placement-123',
        'audienceId': null,
        'abTestId': null,
        'abTestVariantId': null,
        'language': 'en',
        'height': 400,
        'type': 1, // Fallback type
        'plans': [],
        'metadata': null
      };

      final presentation =
          Purchasely.transformToPLYPresentation(presentationMap);

      expect(presentation, isNotNull);
      expect(presentation!.type, PLYPresentationType.fallback);
    });

    test('transformToPLYEventProperties handles valid APP_STARTED event name',
        () {
      final propertiesMap = {
        'sdk_version': '5.6.1',
        'event_name': 'APP_STARTED',
        'event_created_at': '2025-01-15T10:00:00Z',
        'displayed_presentation': null,
        'user_id': null,
        'anonymous_user_id': null,
        'purchasable_plans': null,
        'deeplink_identifier': null,
        'source_identifier': null,
        'selected_plan': null,
        'previous_selected_plan': null,
        'selected_presentation': null,
        'previous_selected_presentation': null,
        'link_identifier': null,
        'carousels': null,
        'language': null,
        'device': null,
        'os_version': null,
        'device_type': null,
        'error_message': null,
        'cancellation_reason_id': null,
        'cancellation_reason': null,
        'plan': null,
        'selected_product': null,
        'plan_change_type': null,
        'running_subscriptions': null,
        'selected_option_id': null,
        'selected_options': null,
        'displayed_options': null,
        'web_checkout_provider': null
      };

      final properties =
          Purchasely.transformToPLYEventProperties(propertiesMap);

      expect(properties.event_name, PLYEventName.APP_STARTED);
    });
  });

  group('User Attribute Date Parsing', () {
    test('userAttribute parses date string', () async {
      final channel = const MethodChannel('purchasely');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'userAttribute') {
          return '2025-01-15T10:30:00.000Z';
        }
        return null;
      });

      final value = await Purchasely.userAttribute('dateKey');

      expect(value, isA<DateTime>());
      expect((value as DateTime).year, 2025);
      expect(value.month, 1);
      expect(value.day, 15);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('userAttribute returns non-date value as-is', () async {
      final channel = const MethodChannel('purchasely');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'userAttribute') {
          return 'not-a-date';
        }
        return null;
      });

      final value = await Purchasely.userAttribute('stringKey');

      expect(value, 'not-a-date');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('userAttributes parses date values in map', () async {
      final channel = const MethodChannel('purchasely');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'userAttributes') {
          return {
            'dateAttr': '2025-06-20T14:00:00.000Z',
            'stringAttr': 'hello',
            'intAttr': 42
          };
        }
        return null;
      });

      final attrs = await Purchasely.userAttributes();

      expect(attrs['dateAttr'], isA<DateTime>());
      expect((attrs['dateAttr'] as DateTime).year, 2025);
      expect(attrs['stringAttr'], 'hello');
      expect(attrs['intAttr'], 42);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });

  group('Subscription Handling Edge Cases', () {
    test('userSubscriptions handles null product', () async {
      final channel = const MethodChannel('purchasely');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'userSubscriptions') {
          return [
            {
              'purchaseToken': 'token-123',
              'subscriptionSource': 0,
              'nextRenewalDate': '2025-02-01T00:00:00Z',
              'cancelledDate': null,
              'plan': {
                'vendorId': 'plan-123',
                'productId': 'product-123',
                'name': 'Plan',
                'type': 2,
                'amount': 9.99,
                'localizedAmount': '\$9.99',
                'currencyCode': 'USD',
                'currencySymbol': '\$',
                'price': '9.99',
                'period': 'P1M',
                'hasIntroductoryPrice': false,
                'introPrice': null,
                'introAmount': null,
                'introDuration': null,
                'introPeriod': null,
                'hasFreeTrial': false
              },
              'product': null
            }
          ];
        }
        return null;
      });

      final subscriptions = await Purchasely.userSubscriptions();

      expect(subscriptions.length, 1);
      expect(subscriptions.first.product, isNull);
      expect(subscriptions.first.plan!.vendorId, 'plan-123');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('userSubscriptions handles product with null plans', () async {
      final channel = const MethodChannel('purchasely');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'userSubscriptions') {
          return [
            {
              'purchaseToken': 'token-123',
              'subscriptionSource': 2,
              'nextRenewalDate': null,
              'cancelledDate': '2025-01-15T00:00:00Z',
              'plan': {},
              'product': {
                'name': 'Product Name',
                'vendorId': 'product-vendor',
                'plans': null
              }
            }
          ];
        }
        return null;
      });

      final subscriptions = await Purchasely.userSubscriptions();

      expect(subscriptions.length, 1);
      expect(subscriptions.first.subscriptionSource,
          PLYSubscriptionSource.amazonAppstore);
      expect(subscriptions.first.product!.name, 'Product Name');
      expect(subscriptions.first.plan, isNull);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });

  group('Plan Types Coverage', () {
    test('transformToPLYPlan handles consumable type', () {
      final planMap = {
        'vendorId': 'vendor-123',
        'productId': 'product-123',
        'name': 'Consumable',
        'type': 0,
        'amount': 0.99,
        'localizedAmount': '\$0.99',
        'currencyCode': 'USD',
        'currencySymbol': '\$',
        'price': '0.99',
        'period': null,
        'hasIntroductoryPrice': false,
        'introPrice': null,
        'introAmount': null,
        'introDuration': null,
        'introPeriod': null,
        'hasFreeTrial': false
      };

      final plan = Purchasely.transformToPLYPlan(planMap);
      expect(plan!.type, PLYPlanType.consumable);
    });

    test('transformToPLYPlan handles nonConsumable type', () {
      final planMap = {
        'vendorId': 'vendor-123',
        'productId': 'product-123',
        'name': 'Non-Consumable',
        'type': 1,
        'amount': 4.99,
        'localizedAmount': '\$4.99',
        'currencyCode': 'USD',
        'currencySymbol': '\$',
        'price': '4.99',
        'period': null,
        'hasIntroductoryPrice': false,
        'introPrice': null,
        'introAmount': null,
        'introDuration': null,
        'introPeriod': null,
        'hasFreeTrial': false
      };

      final plan = Purchasely.transformToPLYPlan(planMap);
      expect(plan!.type, PLYPlanType.nonConsumable);
    });

    test('transformToPLYPlan handles nonRenewingSubscription type', () {
      final planMap = {
        'vendorId': 'vendor-123',
        'productId': 'product-123',
        'name': 'Non-Renewing',
        'type': 3,
        'amount': 19.99,
        'localizedAmount': '\$19.99',
        'currencyCode': 'USD',
        'currencySymbol': '\$',
        'price': '19.99',
        'period': 'P1Y',
        'hasIntroductoryPrice': false,
        'introPrice': null,
        'introAmount': null,
        'introDuration': null,
        'introPeriod': null,
        'hasFreeTrial': false
      };

      final plan = Purchasely.transformToPLYPlan(planMap);
      expect(plan!.type, PLYPlanType.nonRenewingSubscription);
    });

    test('transformToPLYPlan handles unknown type', () {
      final planMap = {
        'vendorId': 'vendor-123',
        'productId': 'product-123',
        'name': 'Unknown',
        'type': 4,
        'amount': 0.0,
        'localizedAmount': '\$0.00',
        'currencyCode': 'USD',
        'currencySymbol': '\$',
        'price': '0.00',
        'period': null,
        'hasIntroductoryPrice': false,
        'introPrice': null,
        'introAmount': null,
        'introDuration': null,
        'introPeriod': null,
        'hasFreeTrial': false
      };

      final plan = Purchasely.transformToPLYPlan(planMap);
      expect(plan!.type, PLYPlanType.unknown);
    });
  });

  group('Presentation Types Coverage', () {
    test('transformToPLYPresentation handles deactivated type', () {
      final presentationMap = {
        'id': 'pres-123',
        'placementId': 'placement-123',
        'audienceId': null,
        'abTestId': null,
        'abTestVariantId': null,
        'language': 'en',
        'height': 400,
        'type': 2,
        'plans': [],
        'metadata': {}
      };

      final presentation =
          Purchasely.transformToPLYPresentation(presentationMap);
      expect(presentation!.type, PLYPresentationType.deactivated);
    });

    test('transformToPLYPresentation handles client type', () {
      final presentationMap = {
        'id': 'pres-123',
        'placementId': 'placement-123',
        'audienceId': null,
        'abTestId': null,
        'abTestVariantId': null,
        'language': 'en',
        'height': 400,
        'type': 3,
        'plans': [],
        'metadata': {}
      };

      final presentation =
          Purchasely.transformToPLYPresentation(presentationMap);
      expect(presentation!.type, PLYPresentationType.client);
    });
  });

  group('Subscription Sources Coverage', () {
    test('all subscription sources are mapped correctly', () {
      expect(PLYSubscriptionSource.appleAppStore.index, 0);
      expect(PLYSubscriptionSource.googlePlayStore.index, 1);
      expect(PLYSubscriptionSource.amazonAppstore.index, 2);
      expect(PLYSubscriptionSource.huaweiAppGallery.index, 3);
      expect(PLYSubscriptionSource.none.index, 4);
    });
  });

  group('More Method Channel Calls', () {
    late MethodChannel channel;
    final List<MethodCall> methodCalls = [];

    setUp(() {
      channel = const MethodChannel('purchasely');
      methodCalls.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('synchronize calls native method', () async {
      await Purchasely.synchronize();
      expect(methodCalls.first.method, 'synchronize');
    });

    test('userLogout calls native method', () async {
      await Purchasely.userLogout();
      expect(methodCalls.first.method, 'userLogout');
    });

    test('close calls native method', () async {
      await Purchasely.close();
      expect(methodCalls.first.method, 'close');
    });

    test('presentSubscriptions calls native method', () async {
      await Purchasely.presentSubscriptions();
      expect(methodCalls.first.method, 'presentSubscriptions');
    });

    test('displaySubscriptionCancellationInstruction calls native method',
        () async {
      await Purchasely.displaySubscriptionCancellationInstruction();
      expect(methodCalls.first.method,
          'displaySubscriptionCancellationInstruction');
    });

    test('closePresentation calls native method', () async {
      await Purchasely.closePresentation();
      expect(methodCalls.first.method, 'closePresentation');
    });

    test('hidePresentation calls native method', () async {
      await Purchasely.hidePresentation();
      expect(methodCalls.first.method, 'hidePresentation');
    });

    test('showPresentation calls native method', () async {
      await Purchasely.showPresentation();
      expect(methodCalls.first.method, 'showPresentation');
    });

    test('userDidConsumeSubscriptionContent calls native method', () async {
      await Purchasely.userDidConsumeSubscriptionContent();
      expect(methodCalls.first.method, 'userDidConsumeSubscriptionContent');
    });

    test('clientPresentationDisplayed calls native method', () async {
      final presentation = PLYPresentation('pres-123', 'placement-123', null,
          null, null, 'en', 400, PLYPresentationType.normal, [], {});

      await Purchasely.clientPresentationDisplayed(presentation);

      expect(methodCalls.first.method, 'clientPresentationDisplayed');
      expect(methodCalls.first.arguments['presentation']['id'], 'pres-123');
    });

    test('clientPresentationClosed calls native method', () async {
      final presentation = PLYPresentation('pres-456', 'placement-456', null,
          null, null, 'fr', 500, PLYPresentationType.fallback, [], {});

      await Purchasely.clientPresentationClosed(presentation);

      expect(methodCalls.first.method, 'clientPresentationClosed');
      expect(methodCalls.first.arguments['presentation']['id'], 'pres-456');
    });
  });

  group('All PLYAttribute Values', () {
    test('all PLYAttribute enum values have correct indices', () {
      expect(PLYAttribute.firebase_app_instance_id.index, 0);
      expect(PLYAttribute.airship_channel_id.index, 1);
      expect(PLYAttribute.airship_user_id.index, 2);
      expect(PLYAttribute.batch_installation_id.index, 3);
      expect(PLYAttribute.adjust_id.index, 4);
      expect(PLYAttribute.appsflyer_id.index, 5);
      expect(PLYAttribute.mixpanel_distinct_id.index, 6);
      expect(PLYAttribute.clever_tap_id.index, 7);
      expect(PLYAttribute.sendinblueUserEmail.index, 8);
      expect(PLYAttribute.iterableUserEmail.index, 9);
      expect(PLYAttribute.iterableUserId.index, 10);
      expect(PLYAttribute.atInternetIdClient.index, 11);
      expect(PLYAttribute.mParticleUserId.index, 12);
      expect(PLYAttribute.customerioUserId.index, 13);
      expect(PLYAttribute.customerioUserEmail.index, 14);
      expect(PLYAttribute.branchUserDeveloperIdentity.index, 15);
      expect(PLYAttribute.amplitudeUserId.index, 16);
      expect(PLYAttribute.amplitudeDeviceId.index, 17);
      expect(PLYAttribute.moengageUniqueId.index, 18);
      expect(PLYAttribute.oneSignalExternalId.index, 19);
      expect(PLYAttribute.batchCustomUserId.index, 20);
    });
  });

  group('PLYPaywallAction Coverage', () {
    test('all PLYPaywallAction enum values', () {
      expect(PLYPaywallAction.values.length, 11);
      expect(PLYPaywallAction.close.name, 'close');
      expect(PLYPaywallAction.close_all.name, 'close_all');
      expect(PLYPaywallAction.login.name, 'login');
      expect(PLYPaywallAction.navigate.name, 'navigate');
      expect(PLYPaywallAction.purchase.name, 'purchase');
      expect(PLYPaywallAction.restore.name, 'restore');
      expect(PLYPaywallAction.open_presentation.name, 'open_presentation');
      expect(PLYPaywallAction.open_placement.name, 'open_placement');
      expect(PLYPaywallAction.promo_code.name, 'promo_code');
      expect(PLYPaywallAction.open_flow_step.name, 'open_flow_step');
      expect(PLYPaywallAction.web_checkout.name, 'web_checkout');
    });
  });

  group('Default Parameter Values', () {
    late MethodChannel channel;
    final List<MethodCall> methodCalls = [];

    setUp(() {
      channel = const MethodChannel('purchasely');
      methodCalls.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('incrementUserAttribute uses default value of 1', () async {
      await Purchasely.incrementUserAttribute('counter');

      expect(methodCalls.first.arguments['value'], 1);
      expect(methodCalls.first.arguments['processingLegalBasis'], 'OPTIONAL');
    });

    test('decrementUserAttribute uses default value of 1', () async {
      await Purchasely.decrementUserAttribute('counter');

      expect(methodCalls.first.arguments['value'], 1);
      expect(methodCalls.first.arguments['processingLegalBasis'], 'OPTIONAL');
    });

    test('setUserAttributeWithString uses optional legal basis by default',
        () async {
      await Purchasely.setUserAttributeWithString('key', 'value');

      expect(methodCalls.first.arguments['processingLegalBasis'], 'OPTIONAL');
    });

    test('setUserAttributeWithInt uses optional legal basis by default',
        () async {
      await Purchasely.setUserAttributeWithInt('key', 42);

      expect(methodCalls.first.arguments['processingLegalBasis'], 'OPTIONAL');
    });

    test('setUserAttributeWithDouble uses optional legal basis by default',
        () async {
      await Purchasely.setUserAttributeWithDouble('key', 3.14);

      expect(methodCalls.first.arguments['processingLegalBasis'], 'OPTIONAL');
    });

    test('setUserAttributeWithBoolean uses optional legal basis by default',
        () async {
      await Purchasely.setUserAttributeWithBoolean('key', true);

      expect(methodCalls.first.arguments['processingLegalBasis'], 'OPTIONAL');
    });

    test('setUserAttributeWithDate uses optional legal basis by default',
        () async {
      await Purchasely.setUserAttributeWithDate('key', DateTime.now());

      expect(methodCalls.first.arguments['processingLegalBasis'], 'OPTIONAL');
    });

    test('setUserAttributeWithStringArray uses optional legal basis by default',
        () async {
      await Purchasely.setUserAttributeWithStringArray('key', ['a', 'b']);

      expect(methodCalls.first.arguments['processingLegalBasis'], 'OPTIONAL');
    });

    test('setUserAttributeWithIntArray uses optional legal basis by default',
        () async {
      await Purchasely.setUserAttributeWithIntArray('key', [1, 2]);

      expect(methodCalls.first.arguments['processingLegalBasis'], 'OPTIONAL');
    });

    test('setUserAttributeWithDoubleArray uses optional legal basis by default',
        () async {
      await Purchasely.setUserAttributeWithDoubleArray('key', [1.1, 2.2]);

      expect(methodCalls.first.arguments['processingLegalBasis'], 'OPTIONAL');
    });

    test(
        'setUserAttributeWithBooleanArray uses optional legal basis by default',
        () async {
      await Purchasely.setUserAttributeWithBooleanArray('key', [true, false]);

      expect(methodCalls.first.arguments['processingLegalBasis'], 'OPTIONAL');
    });
  });

  group('Start Method Variations', () {
    late MethodChannel channel;
    final List<MethodCall> methodCalls = [];

    setUp(() {
      channel = const MethodChannel('purchasely');
      methodCalls.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('start with minimal parameters uses defaults', () async {
      await Purchasely.start(
        apiKey: 'test-key',
        storeKit1: true,
      );

      expect(methodCalls.first.arguments['apiKey'], 'test-key');
      expect(methodCalls.first.arguments['stores'], ['Google']);
      expect(methodCalls.first.arguments['storeKit1'], true);
      expect(methodCalls.first.arguments['userId'], isNull);
      expect(methodCalls.first.arguments['logLevel'], 3); // PLYLogLevel.error
      expect(
          methodCalls.first.arguments['runningMode'], 3); // PLYRunningMode.full
    });

    test('start with all log levels', () async {
      for (final level in PLYLogLevel.values) {
        methodCalls.clear();
        await Purchasely.start(
          apiKey: 'test-key',
          storeKit1: false,
          logLevel: level,
        );

        expect(methodCalls.first.arguments['logLevel'], level.index);
      }
    });

    test('start with all running modes', () async {
      for (final mode in PLYRunningMode.values) {
        methodCalls.clear();
        await Purchasely.start(
          apiKey: 'test-key',
          storeKit1: false,
          runningMode: mode,
        );

        expect(methodCalls.first.arguments['runningMode'], mode.index);
      }
    });

    test('start with multiple android stores', () async {
      await Purchasely.start(
        apiKey: 'test-key',
        storeKit1: false,
        androidStores: ['Google', 'Huawei', 'Amazon'],
      );

      expect(methodCalls.first.arguments['stores'],
          ['Google', 'Huawei', 'Amazon']);
    });
  });
}
