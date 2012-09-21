#include "PreferenceConstants.h"

@interface ISStaleFileAlertItem : SBAlertItem @end

%hook ISStaleFileAlertItem

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView == [self alertSheet]) {
        NSString *message = nil;
        if (buttonIndex == 0) {
            // Delete the old state file
            [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/SpringBoard/IconSupportState.plist" error:NULL];
            message = @"The icon layout file has been deleted.\n\nSpringBoard will now restart.";
        } else {
            message = @"The icon layout file will be used.\n\nSpringBoard will now restart.";
        }

        // Show an alert stating that the device will respring
        UIAlertView *view = [[UIAlertView alloc] initWithTitle:@"IconSupport Warning" message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [view show];
        [view release];
    } else {
        // Record that the old state file has been handled
        CFPreferencesSetAppValue((CFStringRef)kHasOldStateFile, [NSNumber numberWithBool:NO], CFSTR(APP_ID));
        CFPreferencesAppSynchronize(CFSTR(APP_ID));

        // Force a respring
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

- (BOOL)shouldShowInLockScreen { return NO; }

%end

//------------------------------------------------------------------------------

%hook ISStaleAlertItem %group GFirmware_GTE_40_LT_50

- (void)didDeactivateForReason:(int)reason {
    %orig;

    if (reason == 0) {
        // Was deactivated due to lock, not user interaction
        // FIXME: Is there no better way to get the alert to reappear?
        [[objc_getClass("SBAlertItemsController") sharedInstance] activateAlertItem:self];
    }
}

%end %end

//------------------------------------------------------------------------------

%hook ISStaleAlertItem %group GFirmware_GTE_50_LT_60

- (BOOL)reappearsAfterLock { return YES; }

%end %end

//------------------------------------------------------------------------------

%hook ISStaleAlertItem %group GFirmware_GTE_60

// FIXME: Is this the correct way to do this?
//        And even though reappearsAfterLock returns NO by default,
//        the alert still reappears... why?
- (BOOL)behavesSuperModally { return YES; }

%end %end

//==============================================================================

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;

    SBAlertItem *alert = [[objc_getClass("ISStaleFileAlertItem") alloc] init];
    [[objc_getClass("SBAlertItemsController") sharedInstance] activateAlertItem:alert];
    [alert release];
}

%end

//==============================================================================

void initStaleFileAlert() {
    // Register new subclass
    Class $SuperClass = objc_getClass("SBAlertItem");
    if ($SuperClass != Nil) {
        Class $ISStaleFileAlertItem = objc_allocateClassPair($SuperClass, "ISStaleFileAlertItem", 0);
        if ($ISStaleFileAlertItem != Nil) {
            objc_registerClassPair($ISStaleFileAlertItem);

            %init;

            if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_5_0) {
                %init(GFirmware_GTE_40_LT_50);
            } else if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_6_0) {
                %init(GFirmware_GTE_50_LT_60);
            } else {
                %init(GFirmware_GTE_60);
            }
        }
    }
}

/* vim: set filetype=objcpp sw=4 ts=4 expandtab tw=80 ff=unix: */
