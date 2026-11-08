// Diagnostic host only: automatically accepts a real signed update to an isolated copy.
#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>

@interface Driver : SPUStandardUserDriver
@end
@implementation Driver
- (void)showUpdateFoundWithAppcastItem:(SUAppcastItem *)item state:(SPUUserUpdateState *)state reply:(void (^)(SPUUserUpdateChoice))reply {
    NSLog(@"TEST found %@", item.displayVersionString);
    reply(SPUUserUpdateChoiceInstall);
}
- (void)showReadyToInstallAndRelaunch:(void (^)(SPUUserUpdateChoice))reply {
    NSLog(@"TEST ready to install");
    reply(SPUUserUpdateChoiceInstall);
}
- (void)showUpdaterError:(NSError *)error acknowledgement:(void (^)(void))acknowledgement {
    NSLog(@"TEST failed %@", error);
    acknowledgement();
    exit(10);
}
@end

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        Driver *driver = [[Driver alloc] initWithHostBundle:NSBundle.mainBundle delegate:nil];
        SPUUpdater *updater = [[SPUUpdater alloc] initWithHostBundle:NSBundle.mainBundle applicationBundle:NSBundle.mainBundle userDriver:driver delegate:nil];
        NSError *error = nil;
        if (![updater startUpdater:&error]) { NSLog(@"TEST startup %@", error); return 2; }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [updater checkForUpdates]; });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 120 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ NSLog(@"TEST deadline"); exit(3); });
        [NSApp run];
    }
}
