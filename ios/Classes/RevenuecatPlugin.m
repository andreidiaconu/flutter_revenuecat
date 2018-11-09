#import "RevenuecatPlugin.h"
#import <revenuecat/revenuecat-Swift.h>

@implementation RevenuecatPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftRevenuecatPlugin registerWithRegistrar:registrar];
}
@end