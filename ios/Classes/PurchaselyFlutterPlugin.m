#import "PurchaselyFlutterPlugin.h"
#if __has_include(<purchasely_flutter/purchasely_flutter-Swift.h>)
#import <purchasely_flutter/purchasely_flutter-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "purchasely_flutter-Swift.h"
#endif

@implementation PurchaselyFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftPurchaselyFlutterPlugin registerWithRegistrar:registrar];
}
@end
