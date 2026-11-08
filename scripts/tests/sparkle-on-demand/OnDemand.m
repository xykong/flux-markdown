// Fault injection ONLY for the disposable test host. Never ship this library.
// Suppress eager startup, retaining the real Mach service and all security checks.
#import <Foundation/Foundation.h>
#import <ServiceManagement/ServiceManagement.h>

static Boolean submit(CFStringRef domain, CFDictionaryRef job, AuthorizationRef auth, CFErrorRef *error) {
    NSMutableDictionary *copy = [(__bridge NSDictionary *)job mutableCopy];
    if ([copy[@"Label"] isEqualToString:@"com.xykong.Markdown-sparkle-progress"]) {
        copy[@"RunAtLoad"] = @NO;
        NSLog(@"TEST forcing progress agent on-demand");
    }
    return SMJobSubmit(domain, (__bridge CFDictionaryRef)copy, auth, error);
}
__attribute__((used)) static struct { const void *replacement; const void *original; }
interpose __attribute__((section("__DATA,__interpose"))) = { (const void *)submit, (const void *)SMJobSubmit };
