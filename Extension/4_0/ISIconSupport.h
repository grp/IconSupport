#import <Foundation/Foundation.h>

@interface ISIconSupport : NSObject {
    NSMutableSet *extensions;
}

+ (id)sharedInstance;
- (NSString *)extensionString;
- (BOOL)addExtension:(NSString *)extension;
- (BOOL)isBeingUsedByExtensions;
- (void)repairAndReloadIconState;
- (void)repairAndReloadIconState:(NSDictionary *)iconState;
- (void)repairIconStateUponNextRespring;
@end

/* vim: set filetype=objcpp sw=4 ts=4 expandtab tw=80 ff=unix: */
