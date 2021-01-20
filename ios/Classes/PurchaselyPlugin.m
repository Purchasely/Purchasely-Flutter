#import "PurchaselyPlugin.h"
#if __has_include(<purchasely/purchasely-Swift.h>)
#import <purchasely/purchasely-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "purchasely-Swift.h"
#endif

@implementation PurchaselyPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftPurchaselyPlugin registerWithRegistrar:registrar];
}
@end
