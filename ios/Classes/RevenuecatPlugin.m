#import "RevenuecatPlugin.h"
#import <revenuecat/revenuecat-umbrella.h>

@implementation RevenuecatPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [RevenuecatPlugin registerWithRegistrar:registrar];
}
@end
