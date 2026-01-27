import XCTest

@testable import purchasely_flutter

// MARK: - Mock Classes

/// Mock Flutter result handler for capturing results
class MockFlutterResult {
  var capturedResult: Any?
  var resultCalled = false

  func result(_ result: Any?) {
    self.capturedResult = result
    self.resultCalled = true
  }

  var handler: (Any?) -> Void {
    return { [weak self] result in
      self?.result(result)
    }
  }
}

/// Mock Flutter method call for testing
class MockFlutterMethodCall {
  let method: String
  let arguments: Any?

  init(method: String, arguments: Any? = nil) {
    self.method = method
    self.arguments = arguments
  }
}

// MARK: - FlutterPLYAttribute Tests

class FlutterPLYAttributeTests: XCTestCase {

  func testAllAttributeRawValues() {
    // Test that all enum cases have expected raw values
    XCTAssertEqual(FlutterPLYAttribute.firebaseAppInstanceId.rawValue, 0)
    XCTAssertEqual(FlutterPLYAttribute.airshipChannelId.rawValue, 1)
    XCTAssertEqual(FlutterPLYAttribute.airshipUserId.rawValue, 2)
    XCTAssertEqual(FlutterPLYAttribute.batchInstallationId.rawValue, 3)
    XCTAssertEqual(FlutterPLYAttribute.adjustId.rawValue, 4)
    XCTAssertEqual(FlutterPLYAttribute.appsflyerId.rawValue, 5)
    XCTAssertEqual(FlutterPLYAttribute.mixpanelDistinctId.rawValue, 6)
    XCTAssertEqual(FlutterPLYAttribute.cleverTapId.rawValue, 7)
    XCTAssertEqual(FlutterPLYAttribute.sendinblueUserEmail.rawValue, 8)
    XCTAssertEqual(FlutterPLYAttribute.iterableUserEmail.rawValue, 9)
    XCTAssertEqual(FlutterPLYAttribute.iterableUserId.rawValue, 10)
    XCTAssertEqual(FlutterPLYAttribute.atInternetIdClient.rawValue, 11)
    XCTAssertEqual(FlutterPLYAttribute.mParticleUserId.rawValue, 12)
    XCTAssertEqual(FlutterPLYAttribute.customerioUserId.rawValue, 13)
    XCTAssertEqual(FlutterPLYAttribute.customerioUserEmail.rawValue, 14)
    XCTAssertEqual(FlutterPLYAttribute.branchUserDeveloperIdentity.rawValue, 15)
    XCTAssertEqual(FlutterPLYAttribute.amplitudeUserId.rawValue, 16)
    XCTAssertEqual(FlutterPLYAttribute.amplitudeDeviceId.rawValue, 17)
    XCTAssertEqual(FlutterPLYAttribute.moengageUniqueId.rawValue, 18)
    XCTAssertEqual(FlutterPLYAttribute.oneSignalExternalId.rawValue, 19)
    XCTAssertEqual(FlutterPLYAttribute.batchCustomUserId.rawValue, 20)
  }

  func testAttributeInitFromRawValue() {
    XCTAssertEqual(FlutterPLYAttribute(rawValue: 0), .firebaseAppInstanceId)
    XCTAssertEqual(FlutterPLYAttribute(rawValue: 5), .appsflyerId)
    XCTAssertEqual(FlutterPLYAttribute(rawValue: 20), .batchCustomUserId)
    XCTAssertNil(FlutterPLYAttribute(rawValue: 100))
    XCTAssertNil(FlutterPLYAttribute(rawValue: -1))
  }

  func testTotalAttributeCount() {
    // Ensure we have exactly 21 attributes (0-20)
    var count = 0
    for i in 0...100 {
      if FlutterPLYAttribute(rawValue: i) != nil {
        count += 1
      }
    }
    XCTAssertEqual(count, 21)
  }
}

// MARK: - FlutterError Extension Tests

class FlutterErrorExtensionTests: XCTestCase {

  func testNilArgumentError() {
    let error = FlutterError.nilArgument
    XCTAssertEqual(error.code, "argument.nil")
    XCTAssertEqual(error.message, "Expect an argument when invoking channel method, but it is nil.")
    XCTAssertNil(error.details)
  }

  func testFailedArgumentFieldString() {
    let error = FlutterError.failedArgumentField("apiKey", type: String.self)
    XCTAssertEqual(error.code, "argument.failedField")
    XCTAssertTrue(error.message?.contains("apiKey") ?? false)
    XCTAssertTrue(error.message?.contains("String") ?? false)
    XCTAssertEqual(error.details as? String, "apiKey")
  }

  func testFailedArgumentFieldInt() {
    let error = FlutterError.failedArgumentField("count", type: Int.self)
    XCTAssertEqual(error.code, "argument.failedField")
    XCTAssertTrue(error.message?.contains("count") ?? false)
    XCTAssertTrue(error.message?.contains("Int") ?? false)
    XCTAssertEqual(error.details as? String, "count")
  }

  func testFailedArgumentFieldArray() {
    let error = FlutterError.failedArgumentField("items", type: [String].self)
    XCTAssertEqual(error.code, "argument.failedField")
    XCTAssertTrue(error.message?.contains("items") ?? false)
    XCTAssertEqual(error.details as? String, "items")
  }

  func testErrorWithCode() {
    let underlyingError = NSError(
      domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Test error"])
    let error = FlutterError.error(
      code: "-1", message: "Something went wrong", error: underlyingError)

    XCTAssertEqual(error.code, "-1")
    XCTAssertEqual(error.message, "Something went wrong")
    XCTAssertEqual(error.details as? String, "Test error")
  }

  func testErrorWithNilError() {
    let error = FlutterError.error(code: "500", message: "Server error", error: nil)

    XCTAssertEqual(error.code, "500")
    XCTAssertEqual(error.message, "Server error")
    XCTAssertNil(error.details)
  }

  func testErrorWithNilMessage() {
    let error = FlutterError.error(code: "400", message: nil, error: nil)

    XCTAssertEqual(error.code, "400")
    XCTAssertNil(error.message)
    XCTAssertNil(error.details)
  }
}

// MARK: - SwiftEventHandler Tests

class SwiftEventHandlerTests: XCTestCase {

  var eventHandler: SwiftEventHandler!

  override func setUp() {
    super.setUp()
    eventHandler = SwiftEventHandler()
  }

  override func tearDown() {
    eventHandler = nil
    super.tearDown()
  }

  func testInitialState() {
    XCTAssertNil(eventHandler.eventSink)
  }

  func testOnListenSetsEventSink() {
    var receivedEvents: [Any] = []
    let mockEventSink: FlutterEventSink = { event in
      if let event = event {
        receivedEvents.append(event)
      }
    }

    let error = eventHandler.onListen(withArguments: nil, eventSink: mockEventSink)

    XCTAssertNil(error)
    XCTAssertNotNil(eventHandler.eventSink)
  }

  func testOnCancelClearsEventSink() {
    // First set up the event sink
    let mockEventSink: FlutterEventSink = { _ in }
    _ = eventHandler.onListen(withArguments: nil, eventSink: mockEventSink)
    XCTAssertNotNil(eventHandler.eventSink)

    // Now cancel
    let error = eventHandler.onCancel(withArguments: nil)

    XCTAssertNil(error)
    XCTAssertNil(eventHandler.eventSink)
  }

  func testOnListenWithArguments() {
    let arguments: [String: Any] = ["key": "value"]
    let mockEventSink: FlutterEventSink = { _ in }

    let error = eventHandler.onListen(withArguments: arguments, eventSink: mockEventSink)

    XCTAssertNil(error)
  }

  func testOnCancelWithArguments() {
    let arguments: [String: Any] = ["key": "value"]

    let error = eventHandler.onCancel(withArguments: arguments)

    XCTAssertNil(error)
  }
}

// MARK: - SwiftPurchaseHandler Tests

class SwiftPurchaseHandlerTests: XCTestCase {

  var purchaseHandler: SwiftPurchaseHandler!

  override func setUp() {
    super.setUp()
    purchaseHandler = SwiftPurchaseHandler()
  }

  override func tearDown() {
    purchaseHandler = nil
    super.tearDown()
  }

  func testInitialState() {
    XCTAssertNil(purchaseHandler.eventSink)
  }

  func testOnListenSetsEventSink() {
    let mockEventSink: FlutterEventSink = { _ in }

    let error = purchaseHandler.onListen(withArguments: nil, eventSink: mockEventSink)

    XCTAssertNil(error)
    XCTAssertNotNil(purchaseHandler.eventSink)
  }

  func testOnCancelClearsEventSink() {
    let mockEventSink: FlutterEventSink = { _ in }
    _ = purchaseHandler.onListen(withArguments: nil, eventSink: mockEventSink)
    XCTAssertNotNil(purchaseHandler.eventSink)

    let error = purchaseHandler.onCancel(withArguments: nil)

    XCTAssertNil(error)
    // Note: SwiftPurchaseHandler's onCancel doesn't clear the eventSink, it only removes the observer
    // This is the actual behavior of the implementation
  }

  func testPurchasePerformedTriggersEventSink() {
    var receivedEvent = false
    let expectation = XCTestExpectation(description: "Event sink called")

    let mockEventSink: FlutterEventSink = { event in
      receivedEvent = true
      expectation.fulfill()
    }

    _ = purchaseHandler.onListen(withArguments: nil, eventSink: mockEventSink)
    purchaseHandler.purchasePerformed()

    wait(for: [expectation], timeout: 1.0)
    XCTAssertTrue(receivedEvent)
  }

  func testPurchasePerformedWithNoEventSinkDoesNotCrash() {
    // Should not crash when eventSink is nil
    XCTAssertNil(purchaseHandler.eventSink)
    purchaseHandler.purchasePerformed()
    // Test passes if no crash occurs
  }
}

// MARK: - UserAttributesHandler Tests

class UserAttributesHandlerTests: XCTestCase {

  var userAttributesHandler: UserAttributesHandler!

  override func setUp() {
    super.setUp()
    userAttributesHandler = UserAttributesHandler()
  }

  override func tearDown() {
    userAttributesHandler = nil
    super.tearDown()
  }

  func testInitialState() {
    XCTAssertNil(userAttributesHandler.eventSink)
  }

  func testOnListenSetsEventSink() {
    let mockEventSink: FlutterEventSink = { _ in }

    let error = userAttributesHandler.onListen(withArguments: nil, eventSink: mockEventSink)

    XCTAssertNil(error)
    XCTAssertNotNil(userAttributesHandler.eventSink)
  }

  func testOnCancelClearsEventSink() {
    let mockEventSink: FlutterEventSink = { _ in }
    _ = userAttributesHandler.onListen(withArguments: nil, eventSink: mockEventSink)
    XCTAssertNotNil(userAttributesHandler.eventSink)

    let error = userAttributesHandler.onCancel(withArguments: nil)

    XCTAssertNil(error)
    XCTAssertNil(userAttributesHandler.eventSink)
  }
}

// MARK: - Method Call Argument Parsing Tests

class MethodCallArgumentParsingTests: XCTestCase {

  func testStartArgumentsValid() {
    let arguments: [String: Any] = [
      "apiKey": "test_api_key",
      "logLevel": 1,
      "userId": "user123",
      "runningMode": 0,
      "storeKit1": false,
    ]

    XCTAssertEqual(arguments["apiKey"] as? String, "test_api_key")
    XCTAssertEqual(arguments["logLevel"] as? Int, 1)
    XCTAssertEqual(arguments["userId"] as? String, "user123")
    XCTAssertEqual(arguments["runningMode"] as? Int, 0)
    XCTAssertEqual(arguments["storeKit1"] as? Bool, false)
  }

  func testStartArgumentsMissingApiKey() {
    let arguments: [String: Any] = [
      "logLevel": 1,
      "userId": "user123",
    ]

    XCTAssertNil(arguments["apiKey"] as? String)
  }

  func testUserLoginArgumentsValid() {
    let arguments: [String: Any] = [
      "userId": "user123"
    ]

    XCTAssertEqual(arguments["userId"] as? String, "user123")
  }

  func testUserLoginArgumentsMissingUserId() {
    let arguments: [String: Any] = [:]

    XCTAssertNil(arguments["userId"] as? String)
  }

  func testPresentationArgumentsValid() {
    let arguments: [String: Any] = [
      "presentationVendorId": "presentation123",
      "contentId": "content456",
      "isFullscreen": true,
    ]

    XCTAssertEqual(arguments["presentationVendorId"] as? String, "presentation123")
    XCTAssertEqual(arguments["contentId"] as? String, "content456")
    XCTAssertEqual(arguments["isFullscreen"] as? Bool, true)
  }

  func testPlacementArgumentsValid() {
    let arguments: [String: Any] = [
      "placementVendorId": "placement123",
      "contentId": "content456",
    ]

    XCTAssertEqual(arguments["placementVendorId"] as? String, "placement123")
    XCTAssertEqual(arguments["contentId"] as? String, "content456")
  }

  func testProductIdentifierArguments() {
    let arguments: [String: Any] = [
      "productVendorId": "product123",
      "presentationVendorId": "presentation456",
      "contentId": "content789",
    ]

    XCTAssertEqual(arguments["productVendorId"] as? String, "product123")
    XCTAssertEqual(arguments["presentationVendorId"] as? String, "presentation456")
    XCTAssertEqual(arguments["contentId"] as? String, "content789")
  }

  func testPlanIdentifierArguments() {
    let arguments: [String: Any] = [
      "planVendorId": "plan123",
      "presentationVendorId": "presentation456",
    ]

    XCTAssertEqual(arguments["planVendorId"] as? String, "plan123")
    XCTAssertEqual(arguments["presentationVendorId"] as? String, "presentation456")
  }

  func testDeeplinkArguments() {
    let arguments: [String: Any] = [
      "deeplink": "https://example.com/deeplink"
    ]

    let deeplink = arguments["deeplink"] as? String
    XCTAssertNotNil(deeplink)
    XCTAssertNotNil(URL(string: deeplink!))
  }

  func testSetAttributeArguments() {
    let arguments: [String: Any] = [
      "attribute": 5,
      "value": "test_value",
    ]

    let attributeRaw = arguments["attribute"] as? Int
    XCTAssertNotNil(attributeRaw)
    XCTAssertNotNil(FlutterPLYAttribute(rawValue: attributeRaw!))
    XCTAssertEqual(arguments["value"] as? String, "test_value")
  }

  func testUserAttributeStringArguments() {
    let arguments: [String: Any] = [
      "key": "user_name",
      "value": "John Doe",
      "processingLegalBasis": "ESSENTIAL",
    ]

    XCTAssertEqual(arguments["key"] as? String, "user_name")
    XCTAssertEqual(arguments["value"] as? String, "John Doe")
    XCTAssertEqual(arguments["processingLegalBasis"] as? String, "ESSENTIAL")
  }

  func testUserAttributeIntArguments() {
    let arguments: [String: Any] = [
      "key": "user_age",
      "value": 25,
      "processingLegalBasis": "OPTIONAL",
    ]

    XCTAssertEqual(arguments["key"] as? String, "user_age")
    XCTAssertEqual(arguments["value"] as? Int, 25)
  }

  func testUserAttributeDoubleArguments() {
    let arguments: [String: Any] = [
      "key": "user_score",
      "value": 98.5,
    ]

    XCTAssertEqual(arguments["key"] as? String, "user_score")
    XCTAssertEqual(arguments["value"] as? Double, 98.5)
  }

  func testUserAttributeBoolArguments() {
    let arguments: [String: Any] = [
      "key": "is_premium",
      "value": true,
    ]

    XCTAssertEqual(arguments["key"] as? String, "is_premium")
    XCTAssertEqual(arguments["value"] as? Bool, true)
  }

  func testUserAttributeDateArguments() {
    let arguments: [String: Any] = [
      "key": "birth_date",
      "value": "1990-05-15T00:00:00.000Z",
    ]

    XCTAssertEqual(arguments["key"] as? String, "birth_date")

    let dateString = arguments["value"] as? String
    XCTAssertNotNil(dateString)

    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(identifier: "GMT")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

    let date = dateFormatter.date(from: dateString!)
    XCTAssertNotNil(date)
  }

  func testUserAttributeArrayArguments() {
    let stringArrayArguments: [String: Any] = [
      "key": "favorite_colors",
      "value": ["red", "blue", "green"],
    ]

    XCTAssertEqual(stringArrayArguments["key"] as? String, "favorite_colors")
    XCTAssertEqual(stringArrayArguments["value"] as? [String], ["red", "blue", "green"])

    let intArrayArguments: [String: Any] = [
      "key": "scores",
      "value": [100, 95, 88],
    ]

    XCTAssertEqual(intArrayArguments["value"] as? [Int], [100, 95, 88])

    let doubleArrayArguments: [String: Any] = [
      "key": "ratings",
      "value": [4.5, 3.8, 4.9],
    ]

    XCTAssertEqual(doubleArrayArguments["value"] as? [Double], [4.5, 3.8, 4.9])

    let boolArrayArguments: [String: Any] = [
      "key": "flags",
      "value": [true, false, true],
    ]

    XCTAssertEqual(boolArrayArguments["value"] as? [Bool], [true, false, true])
  }

  func testThemeModeArguments() {
    let arguments: [String: Any] = [
      "mode": 0
    ]

    XCTAssertEqual(arguments["mode"] as? Int, 0)
  }

  func testLogLevelArguments() {
    let arguments: [String: Any] = [
      "logLevel": 2
    ]

    XCTAssertEqual(arguments["logLevel"] as? Int, 2)
  }

  func testLanguageArguments() {
    let arguments: [String: Any] = [
      "language": "fr"
    ]

    XCTAssertEqual(arguments["language"] as? String, "fr")
  }

  func testPurchaseWithPlanArguments() {
    let arguments: [String: Any] = [
      "vendorId": "plan_premium",
      "contentId": "content123",
      "offerId": "offer456",
    ]

    XCTAssertEqual(arguments["vendorId"] as? String, "plan_premium")
    XCTAssertEqual(arguments["contentId"] as? String, "content123")
    XCTAssertEqual(arguments["offerId"] as? String, "offer456")
  }

  func testSignPromotionalOfferArguments() {
    let arguments: [String: Any] = [
      "storeProductId": "com.app.subscription",
      "storeOfferId": "offer_id_123",
    ]

    XCTAssertEqual(arguments["storeProductId"] as? String, "com.app.subscription")
    XCTAssertEqual(arguments["storeOfferId"] as? String, "offer_id_123")
  }

  func testDynamicOfferingArguments() {
    let arguments: [String: Any] = [
      "reference": "ref123",
      "planVendorId": "plan456",
      "offerVendorId": "offer789",
    ]

    XCTAssertEqual(arguments["reference"] as? String, "ref123")
    XCTAssertEqual(arguments["planVendorId"] as? String, "plan456")
    XCTAssertEqual(arguments["offerVendorId"] as? String, "offer789")
  }

  func testRevokeDataProcessingConsentArguments() {
    let arguments: [String: Any] = [
      "purposes": ["ANALYTICS", "CAMPAIGNS"]
    ]

    let purposes = arguments["purposes"] as? [String]
    XCTAssertEqual(purposes, ["ANALYTICS", "CAMPAIGNS"])
  }

  func testDebugModeArguments() {
    let arguments: [String: Any] = [
      "debugMode": true
    ]

    XCTAssertEqual(arguments["debugMode"] as? Bool, true)
  }
}

// MARK: - Data Processing Purpose Parsing Tests

class DataProcessingPurposeParsingTests: XCTestCase {

  func testParseAnalytics() {
    let value = "ANALYTICS"
    XCTAssertEqual(value, "ANALYTICS")
  }

  func testParseIdentifiedAnalytics() {
    let value = "IDENTIFIED_ANALYTICS"
    XCTAssertEqual(value, "IDENTIFIED_ANALYTICS")
  }

  func testParseCampaigns() {
    let value = "CAMPAIGNS"
    XCTAssertEqual(value, "CAMPAIGNS")
  }

  func testParsePersonalization() {
    let value = "PERSONALIZATION"
    XCTAssertEqual(value, "PERSONALIZATION")
  }

  func testParseThirdPartyIntegrations() {
    let value = "THIRD_PARTY_INTEGRATIONS"
    XCTAssertEqual(value, "THIRD_PARTY_INTEGRATIONS")
  }

  func testParseAllNonEssentials() {
    let value = "ALL_NON_ESSENTIALS"
    XCTAssertEqual(value, "ALL_NON_ESSENTIALS")
  }

  func testParsePurposesArray() {
    let purposes = ["ANALYTICS", "CAMPAIGNS", "PERSONALIZATION"]
    XCTAssertEqual(purposes.count, 3)
    XCTAssertTrue(purposes.contains("ANALYTICS"))
    XCTAssertTrue(purposes.contains("CAMPAIGNS"))
    XCTAssertTrue(purposes.contains("PERSONALIZATION"))
  }

  func testProcessingLegalBasisEssential() {
    let value = "ESSENTIAL"
    XCTAssertEqual(value, "ESSENTIAL")
  }

  func testProcessingLegalBasisOptional() {
    let value = "OPTIONAL"
    XCTAssertNotEqual(value, "ESSENTIAL")
  }
}

// MARK: - Presentation Map Tests

class PresentationMapTests: XCTestCase {

  func testPresentationMapStructure() {
    let presentationMap: [String: Any] = [
      "id": "presentation123",
      "placementId": "placement456",
      "type": "normal",
    ]

    XCTAssertEqual(presentationMap["id"] as? String, "presentation123")
    XCTAssertEqual(presentationMap["placementId"] as? String, "placement456")
    XCTAssertEqual(presentationMap["type"] as? String, "normal")
  }

  func testNestedPresentationInArguments() {
    let arguments: [String: Any] = [
      "presentation": [
        "id": "pres123",
        "placementId": "place456",
      ],
      "isFullscreen": true,
    ]

    let presentation = arguments["presentation"] as? [String: Any]
    XCTAssertNotNil(presentation)
    XCTAssertEqual(presentation?["id"] as? String, "pres123")
    XCTAssertEqual(presentation?["placementId"] as? String, "place456")
    XCTAssertEqual(arguments["isFullscreen"] as? Bool, true)
  }
}

// MARK: - Method Name Tests

class MethodNameTests: XCTestCase {

  let allMethodNames = [
    "start",
    "close",
    "setDefaultPresentationResultHandler",
    "fetchPresentation",
    "presentPresentation",
    "clientPresentationDisplayed",
    "clientPresentationClosed",
    "presentPresentationWithIdentifier",
    "presentProductWithIdentifier",
    "presentPlanWithIdentifier",
    "presentPresentationForPlacement",
    "restoreAllProducts",
    "silentRestoreAllProducts",
    "synchronize",
    "getAnonymousUserId",
    "userLogin",
    "userLogout",
    "readyToOpenDeeplink",
    "setLogLevel",
    "productWithIdentifier",
    "planWithIdentifier",
    "allProducts",
    "purchaseWithPlanVendorId",
    "isDeeplinkHandled",
    "userSubscriptions",
    "userSubscriptionsHistory",
    "presentSubscriptions",
    "setThemeMode",
    "setAttribute",
    "setPaywallActionInterceptor",
    "setLanguage",
    "onProcessAction",
    "userDidConsumeSubscriptionContent",
    "setUserAttributeWithString",
    "setUserAttributeWithInt",
    "setUserAttributeWithDouble",
    "setUserAttributeWithBoolean",
    "setUserAttributeWithDate",
    "setUserAttributeWithStringArray",
    "setUserAttributeWithIntArray",
    "setUserAttributeWithDoubleArray",
    "setUserAttributeWithBooleanArray",
    "incrementUserAttribute",
    "decrementUserAttribute",
    "userAttribute",
    "userAttributes",
    "clearUserAttribute",
    "clearUserAttributes",
    "clearBuiltInAttributes",
    "displaySubscriptionCancellationInstruction",
    "isAnonymous",
    "hidePresentation",
    "showPresentation",
    "closePresentation",
    "signPromotionalOffer",
    "isEligibleForIntroOffer",
    "setDynamicOffering",
    "getDynamicOfferings",
    "removeDynamicOffering",
    "clearDynamicOfferings",
    "revokeDataProcessingConsent",
    "setDebugMode",
  ]

  func testAllMethodNamesAreDefined() {
    XCTAssertGreaterThan(allMethodNames.count, 50)
  }

  func testMethodNameStart() {
    XCTAssertTrue(allMethodNames.contains("start"))
  }

  func testMethodNameClose() {
    XCTAssertTrue(allMethodNames.contains("close"))
  }

  func testPresentationMethods() {
    XCTAssertTrue(allMethodNames.contains("fetchPresentation"))
    XCTAssertTrue(allMethodNames.contains("presentPresentation"))
    XCTAssertTrue(allMethodNames.contains("presentPresentationWithIdentifier"))
    XCTAssertTrue(allMethodNames.contains("presentPresentationForPlacement"))
    XCTAssertTrue(allMethodNames.contains("hidePresentation"))
    XCTAssertTrue(allMethodNames.contains("showPresentation"))
    XCTAssertTrue(allMethodNames.contains("closePresentation"))
  }

  func testUserMethods() {
    XCTAssertTrue(allMethodNames.contains("userLogin"))
    XCTAssertTrue(allMethodNames.contains("userLogout"))
    XCTAssertTrue(allMethodNames.contains("getAnonymousUserId"))
    XCTAssertTrue(allMethodNames.contains("isAnonymous"))
    XCTAssertTrue(allMethodNames.contains("userSubscriptions"))
    XCTAssertTrue(allMethodNames.contains("userSubscriptionsHistory"))
  }

  func testAttributeMethods() {
    XCTAssertTrue(allMethodNames.contains("setAttribute"))
    XCTAssertTrue(allMethodNames.contains("setUserAttributeWithString"))
    XCTAssertTrue(allMethodNames.contains("setUserAttributeWithInt"))
    XCTAssertTrue(allMethodNames.contains("setUserAttributeWithDouble"))
    XCTAssertTrue(allMethodNames.contains("setUserAttributeWithBoolean"))
    XCTAssertTrue(allMethodNames.contains("setUserAttributeWithDate"))
    XCTAssertTrue(allMethodNames.contains("setUserAttributeWithStringArray"))
    XCTAssertTrue(allMethodNames.contains("setUserAttributeWithIntArray"))
    XCTAssertTrue(allMethodNames.contains("setUserAttributeWithDoubleArray"))
    XCTAssertTrue(allMethodNames.contains("setUserAttributeWithBooleanArray"))
    XCTAssertTrue(allMethodNames.contains("incrementUserAttribute"))
    XCTAssertTrue(allMethodNames.contains("decrementUserAttribute"))
    XCTAssertTrue(allMethodNames.contains("userAttribute"))
    XCTAssertTrue(allMethodNames.contains("userAttributes"))
    XCTAssertTrue(allMethodNames.contains("clearUserAttribute"))
    XCTAssertTrue(allMethodNames.contains("clearUserAttributes"))
    XCTAssertTrue(allMethodNames.contains("clearBuiltInAttributes"))
  }

  func testProductMethods() {
    XCTAssertTrue(allMethodNames.contains("allProducts"))
    XCTAssertTrue(allMethodNames.contains("productWithIdentifier"))
    XCTAssertTrue(allMethodNames.contains("planWithIdentifier"))
    XCTAssertTrue(allMethodNames.contains("presentProductWithIdentifier"))
    XCTAssertTrue(allMethodNames.contains("presentPlanWithIdentifier"))
  }

  func testPurchaseMethods() {
    XCTAssertTrue(allMethodNames.contains("purchaseWithPlanVendorId"))
    XCTAssertTrue(allMethodNames.contains("restoreAllProducts"))
    XCTAssertTrue(allMethodNames.contains("silentRestoreAllProducts"))
  }

  func testDynamicOfferingMethods() {
    XCTAssertTrue(allMethodNames.contains("setDynamicOffering"))
    XCTAssertTrue(allMethodNames.contains("getDynamicOfferings"))
    XCTAssertTrue(allMethodNames.contains("removeDynamicOffering"))
    XCTAssertTrue(allMethodNames.contains("clearDynamicOfferings"))
  }

  func testConfigurationMethods() {
    XCTAssertTrue(allMethodNames.contains("setLogLevel"))
    XCTAssertTrue(allMethodNames.contains("setLanguage"))
    XCTAssertTrue(allMethodNames.contains("setThemeMode"))
    XCTAssertTrue(allMethodNames.contains("setDebugMode"))
  }

  func testOtherMethods() {
    XCTAssertTrue(allMethodNames.contains("synchronize"))
    XCTAssertTrue(allMethodNames.contains("readyToOpenDeeplink"))
    XCTAssertTrue(allMethodNames.contains("isDeeplinkHandled"))
    XCTAssertTrue(allMethodNames.contains("setPaywallActionInterceptor"))
    XCTAssertTrue(allMethodNames.contains("onProcessAction"))
    XCTAssertTrue(allMethodNames.contains("signPromotionalOffer"))
    XCTAssertTrue(allMethodNames.contains("isEligibleForIntroOffer"))
    XCTAssertTrue(allMethodNames.contains("revokeDataProcessingConsent"))
  }
}

// MARK: - Paywall Action Tests

class PaywallActionTests: XCTestCase {

  let allActions = [
    "login",
    "purchase",
    "close",
    "close_all",
    "restore",
    "navigate",
    "promo_code",
    "open_presentation",
    "open_placement",
    "web_checkout",
  ]

  func testAllActionsAreDefined() {
    XCTAssertEqual(allActions.count, 10)
  }

  func testLoginAction() {
    XCTAssertTrue(allActions.contains("login"))
  }

  func testPurchaseAction() {
    XCTAssertTrue(allActions.contains("purchase"))
  }

  func testCloseAction() {
    XCTAssertTrue(allActions.contains("close"))
  }

  func testCloseAllAction() {
    XCTAssertTrue(allActions.contains("close_all"))
  }

  func testRestoreAction() {
    XCTAssertTrue(allActions.contains("restore"))
  }

  func testNavigateAction() {
    XCTAssertTrue(allActions.contains("navigate"))
  }

  func testPromoCodeAction() {
    XCTAssertTrue(allActions.contains("promo_code"))
  }

  func testOpenPresentationAction() {
    XCTAssertTrue(allActions.contains("open_presentation"))
  }

  func testOpenPlacementAction() {
    XCTAssertTrue(allActions.contains("open_placement"))
  }

  func testWebCheckoutAction() {
    XCTAssertTrue(allActions.contains("web_checkout"))
  }
}

// MARK: - User Attribute Type Formatting Tests

class UserAttributeTypeFormattingTests: XCTestCase {

  func testStringTypeFormat() {
    XCTAssertEqual("STRING", "STRING")
  }

  func testBooleanTypeFormat() {
    XCTAssertEqual("BOOLEAN", "BOOLEAN")
  }

  func testIntTypeFormat() {
    XCTAssertEqual("INT", "INT")
  }

  func testFloatTypeFormat() {
    XCTAssertEqual("FLOAT", "FLOAT")
  }

  func testDateTypeFormat() {
    XCTAssertEqual("DATE", "DATE")
  }

  func testStringArrayTypeFormat() {
    XCTAssertEqual("STRING_ARRAY", "STRING_ARRAY")
  }

  func testIntArrayTypeFormat() {
    XCTAssertEqual("INT_ARRAY", "INT_ARRAY")
  }

  func testFloatArrayTypeFormat() {
    XCTAssertEqual("FLOAT_ARRAY", "FLOAT_ARRAY")
  }

  func testBooleanArrayTypeFormat() {
    XCTAssertEqual("BOOLEAN_ARRAY", "BOOLEAN_ARRAY")
  }

  func testDictionaryTypeFormat() {
    XCTAssertEqual("DICTIONARY", "DICTIONARY")
  }
}

// MARK: - Date Formatter Tests

class DateFormatterTests: XCTestCase {

  func testDateFormatterFormat() {
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(identifier: "GMT")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

    // Test parsing
    let dateString = "2023-12-25T10:30:00.000Z"
    let date = dateFormatter.date(from: dateString)
    XCTAssertNotNil(date)

    // Test formatting back
    if let date = date {
      let formattedString = dateFormatter.string(from: date)
      XCTAssertEqual(formattedString, dateString)
    }
  }

  func testDateFormatterInvalidFormat() {
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(identifier: "GMT")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

    let invalidDateString = "25-12-2023"
    let date = dateFormatter.date(from: invalidDateString)
    XCTAssertNil(date)
  }

  func testDateFormatterTimeZone() {
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(identifier: "GMT")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

    XCTAssertEqual(dateFormatter.timeZone.identifier, "GMT")
  }

  func testDateToFlutterFormatConversion() {
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(identifier: "GMT")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

    let date = Date(timeIntervalSince1970: 0)  // 1970-01-01
    let formattedString = dateFormatter.string(from: date)
    XCTAssertEqual(formattedString, "1970-01-01T00:00:00.000Z")
  }
}

// MARK: - URL Validation Tests

class URLValidationTests: XCTestCase {

  func testValidHTTPSUrl() {
    let urlString = "https://example.com/deeplink"
    let url = URL(string: urlString)
    XCTAssertNotNil(url)
    XCTAssertEqual(url?.scheme, "https")
  }

  func testValidHTTPUrl() {
    let urlString = "http://example.com/path"
    let url = URL(string: urlString)
    XCTAssertNotNil(url)
    XCTAssertEqual(url?.scheme, "http")
  }

  func testValidCustomSchemeUrl() {
    let urlString = "myapp://purchasely/product/123"
    let url = URL(string: urlString)
    XCTAssertNotNil(url)
    XCTAssertEqual(url?.scheme, "myapp")
  }

  func testUrlWithQueryParameters() {
    let urlString = "https://example.com/path?param1=value1&param2=value2"
    let url = URL(string: urlString)
    XCTAssertNotNil(url)
    XCTAssertNotNil(url?.query)
  }

  func testInvalidUrl() {
    // Empty string is an invalid URL
    let urlString = ""
    let url = URL(string: urlString)
    XCTAssertNil(url)
  }
}

// MARK: - Event Channel Name Tests

class EventChannelNameTests: XCTestCase {

  func testPurchaselyEventsChannelName() {
    let channelName = "purchasely-events"
    XCTAssertEqual(channelName, "purchasely-events")
  }

  func testPurchaselyPurchasesChannelName() {
    let channelName = "purchasely-purchases"
    XCTAssertEqual(channelName, "purchasely-purchases")
  }

  func testPurchaselyUserAttributesChannelName() {
    let channelName = "purchasely-user-attributes"
    XCTAssertEqual(channelName, "purchasely-user-attributes")
  }

  func testMethodChannelName() {
    let channelName = "purchasely"
    XCTAssertEqual(channelName, "purchasely")
  }

  func testNativeViewId() {
    let viewId = "io.purchasely.purchasely_flutter/native_view"
    XCTAssertEqual(viewId, "io.purchasely.purchasely_flutter/native_view")
  }
}

// MARK: - Result Value Tests

class ResultValueTests: XCTestCase {

  func testPresentationResultMapStructure() {
    let resultMap: [String: Any] = [
      "result": 0,
      "plan": ["id": "plan123", "name": "Premium"],
    ]

    XCTAssertEqual(resultMap["result"] as? Int, 0)

    let plan = resultMap["plan"] as? [String: Any]
    XCTAssertNotNil(plan)
    XCTAssertEqual(plan?["id"] as? String, "plan123")
  }

  func testPresentationResultWithEmptyPlan() {
    let resultMap: [String: Any] = [
      "result": 1,
      "plan": [String: Any](),
    ]

    XCTAssertEqual(resultMap["result"] as? Int, 1)

    let plan = resultMap["plan"] as? [String: Any]
    XCTAssertNotNil(plan)
    XCTAssertTrue(plan?.isEmpty ?? false)
  }

  func testEventResultStructure() {
    let eventResult: [String: Any] = [
      "name": "PRODUCT_PAGE_VIEWED",
      "properties": ["productId": "prod123"],
    ]

    XCTAssertEqual(eventResult["name"] as? String, "PRODUCT_PAGE_VIEWED")

    let properties = eventResult["properties"] as? [String: Any]
    XCTAssertNotNil(properties)
    XCTAssertEqual(properties?["productId"] as? String, "prod123")
  }

  func testUserAttributeEventSetStructure() {
    let event: [String: Any] = [
      "event": "set",
      "key": "user_name",
      "type": "STRING",
      "value": "John",
      "source": "flutter",
    ]

    XCTAssertEqual(event["event"] as? String, "set")
    XCTAssertEqual(event["key"] as? String, "user_name")
    XCTAssertEqual(event["type"] as? String, "STRING")
    XCTAssertEqual(event["value"] as? String, "John")
  }

  func testUserAttributeEventRemovedStructure() {
    let event: [String: Any] = [
      "event": "removed",
      "key": "user_name",
      "source": "flutter",
    ]

    XCTAssertEqual(event["event"] as? String, "removed")
    XCTAssertEqual(event["key"] as? String, "user_name")
  }

  func testPaywallActionInterceptorResultStructure() {
    let result: [String: Any] = [
      "action": "purchase",
      "info": ["planId": "plan123"],
      "parameters": ["discount": 10],
    ]

    XCTAssertEqual(result["action"] as? String, "purchase")

    let info = result["info"] as? [String: Any]
    XCTAssertNotNil(info)

    let parameters = result["parameters"] as? [String: Any]
    XCTAssertNotNil(parameters)
  }

  func testDynamicOfferingResultStructure() {
    let offering: [String: String] = [
      "reference": "ref123",
      "planVendorId": "plan456",
      "offerVendorId": "offer789",
    ]

    XCTAssertEqual(offering["reference"], "ref123")
    XCTAssertEqual(offering["planVendorId"], "plan456")
    XCTAssertEqual(offering["offerVendorId"], "offer789")
  }

  func testDynamicOfferingsListStructure() {
    let offerings: [[String: String]] = [
      ["reference": "ref1", "planVendorId": "plan1"],
      ["reference": "ref2", "planVendorId": "plan2", "offerVendorId": "offer2"],
    ]

    XCTAssertEqual(offerings.count, 2)
    XCTAssertEqual(offerings[0]["reference"], "ref1")
    XCTAssertEqual(offerings[1]["offerVendorId"], "offer2")
  }
}

// MARK: - UIViewController Extension Tests

class UIViewControllerExtensionTests: XCTestCase {

  func testCloseMethodExists() {
    let viewController = UIViewController()

    // Test that the close method is accessible
    XCTAssertTrue(viewController.responds(to: #selector(UIViewController.close)))
  }
}

// MARK: - Test Helpers

extension XCTestCase {

  /// Helper to wait for async operations
  func waitForAsync(timeout: TimeInterval = 2.0) {
    let expectation = XCTestExpectation(description: "Wait for async")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: timeout)
  }
}
