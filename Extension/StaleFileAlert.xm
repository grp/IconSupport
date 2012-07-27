#define STALE_FILE_KEY "hasOldStateFile"

@interface SBAlertItem : NSObject <UIAlertViewDelegate>
@property(readonly, retain) UIAlertView *alertSheet;
@end

@interface ISStaleFileAlertItem : SBAlertItem @end


@interface SBAlertItemsController : NSObject
+ (id)sharedInstance;
- (void)activateAlertItem:(id)item;
@end

%hook ISStaleFileAlertItem

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    // Save fact that this alert has been shown and handled
    // NOTE: Must do this beforehand, in case exit() is called.
    CFPreferencesSetAppValue(CFSTR(STALE_FILE_KEY), [NSNumber numberWithBool:NO], CFSTR(APP_ID));
    CFPreferencesAppSynchronize(CFSTR(APP_ID));

    switch (buttonIndex) {
        case 0:
            // Delete the file and force a restart
            [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/SpringBoard/IconSupportState.plist" error:NULL];
            exit(0);
            break;

        default:
            break;
    }
}

- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)require {
    NSString *title = @"IconSupport Warning";
    NSString *body = @"An icon layout file from a previous installation of IconSupport has been detected.\n\n"
        "Using this file will restore the icon layout from the last time that IconSupport was installed, which may have been long ago.";

    UIAlertView *alertView = [self alertSheet];
    [alertView setDelegate:self];
    [alertView setTitle:title];
    [alertView setMessage:body];
    [alertView addButtonWithTitle:@"Delete"];
    [alertView addButtonWithTitle:@"Use"];
}

%end

static void showStaleFileMessageIfNecessary() {
    BOOL hasOldStateFile = NO;
    CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR(STALE_FILE_KEY), CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFBooleanGetTypeID()) {
            hasOldStateFile = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
        }
        CFRelease(propList);
    }

    if (hasOldStateFile) {
        SBAlertItem *alert = [[[objc_getClass("ISStaleFileAlertItem") alloc] init] autorelease];
        [[objc_getClass("SBAlertItemsController") sharedInstance] activateAlertItem:alert];
    }
}

%hook SBIconController %group GFirmware_Pre_43
- (void)showInfoAlertIfNeeded { %orig; showStaleFileMessageIfNecessary(); }
%end %end

%hook AAAccountManager %group GFirmware_Post_43
+ (void)showMobileMeOfferIfNecessary { %orig; showStaleFileMessageIfNecessary(); }
%end %end

__attribute__((constructor)) static void init() {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_4_0) {
        // NOTE: This library should only be loaded for SpringBoard
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundleId isEqualToString:@"com.apple.springboard"]) {
            // Register new subclass
            Class $SuperClass = objc_getClass("SBAlertItem");
            if ($SuperClass != Nil) {
                Class $ISStaleFileAlertItem = objc_allocateClassPair($SuperClass, "ISStaleFileAlertItem", 0);
                if ($ISStaleFileAlertItem != Nil) {
                    objc_registerClassPair($ISStaleFileAlertItem);

                    %init;

                    if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_4_3) {
                        %init(GFirmware_Pre_43);
                    } else {
                        %init(GFirmware_Post_43);
                    }
                }
            }
        }
    }

    [pool release];
}
