#import "ISIconSupport.h"

#import "PreferenceConstants.h"
#include <substrate.h>

NSDictionary * repairIconState(NSDictionary *iconState);

static ISIconSupport *sharedSupport = nil;

@implementation ISIconSupport

+ (id)sharedInstance {
    return sharedSupport;
}

- (id)init {
    self = [super init];
    if (self != nil) {
        extensions = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)dealloc {
    [extensions release];
    [super dealloc];
}

- (NSString *)extensionString {
    if ([extensions count] == 0) {
        return @"";
    }

    // Every combination of extensions must produce a unique extension string
    int result = 0;
    for (NSString *extension in extensions) {
        result |= [extension hash];
    }

    return [@"-" stringByAppendingFormat:@"%x", result];
}

- (BOOL)addExtension:(NSString *)extension {
    if (extension == nil || [extensions containsObject:extension]) {
        return NO;
    }

    [extensions addObject:extension];
    return YES;
}

- (BOOL)isBeingUsedByExtensions {
    return ![[self extensionString] isEqualToString:@""];
}

- (void)repairAndReloadIconState {
    SBIconModel *iconModel = IOS_LT(6_0) ?
        [objc_getClass("SBIconModel") sharedInstance] : [[objc_getClass("SBIconController") sharedInstance] model];
    [self repairAndReloadIconState:[iconModel iconState]];
}

- (void)repairAndReloadIconState:(NSDictionary *)iconState {
    if (iconState == nil) {
        return;
    }

    iconState = repairIconState(iconState);
    if (IOS_LT(6_0)) {
        SBIconModel *iconModel = [objc_getClass("SBIconModel") sharedInstance];
        [iconState writeToFile:[iconModel iconStatePath] atomically:YES];
        [iconModel noteIconStateChangedExternally];
    } else {
        [iconState writeToFile:[[[objc_getClass("SBDefaultIconModelStore") sharedInstance] currentIconStateURL] path] atomically:YES];
        [[objc_getClass("SBIconController") sharedInstance] noteIconStateChangedExternally];
    }
}

- (void)repairIconStateUponNextRespring {
    CFPreferencesSetAppValue((CFStringRef)kMarkedForRepair, [NSNumber numberWithBool:YES], CFSTR(APP_ID));
    CFPreferencesAppSynchronize(CFSTR(APP_ID));
}

@end

%ctor {
    @autoreleasepool {
        // NOTE: This library should only be loaded for SpringBoard
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundleId isEqualToString:@"com.apple.springboard"]) {
            sharedSupport = [[ISIconSupport alloc] init];
        }
    }
}

/* vim: set ft=logos ff=unix tw=80 sw=4 ts=4 expandtab: */
