#include "PreferenceConstants.h"

@interface ISStaleFileAlertItem : SBAlertItem @end

%hook ISStaleFileAlertItem

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    // Save fact that this alert has been shown and handled
    // NOTE: Must do this beforehand, in case exit() is called.
    CFPreferencesSetAppValue((CFStringRef)kHasOldStateFile, [NSNumber numberWithBool:NO], CFSTR(APP_ID));
    CFPreferencesAppSynchronize(CFSTR(APP_ID));

    if (buttonIndex == 0) {
        // Delete the file and force a restart
        [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/SpringBoard/IconSupportState.plist" error:NULL];
        exit(0);
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

static inline void showStaleFileMessage() {
    SBAlertItem *alert = [[objc_getClass("ISStaleFileAlertItem") alloc] init];
    [[objc_getClass("SBAlertItemsController") sharedInstance] activateAlertItem:alert];
    [alert release];
}

%hook SBIconController %group GFirmware_Pre_43
- (void)showInfoAlertIfNeeded { %orig; showStaleFileMessage(); }
%end %end

%hook AAAccountManager %group GFirmware_Post_43
+ (void)showMobileMeOfferIfNecessary { %orig; showStaleFileMessage(); }
%end %end

void initStaleFileAlert() {
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

/* vim: set filetype=objcpp sw=4 ts=4 expandtab tw=80 ff=unix: */
