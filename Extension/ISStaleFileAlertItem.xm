#import "ISStaleFileAlertItem.h"

#import "ISIconSupport.h"
#include "PreferenceConstants.h"

@interface ISStaleFileAlertItem : SBAlertItem @end

%hook ISStaleFileAlertItem

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSString *staleStateFilePath = @"/var/mobile/Library/SpringBoard/IconSupportState.plist.stale";

    NSString *message = nil;
    if (buttonIndex == 0) {
        message = @"The layout has been deleted.";
    } else {
        // Apply the old state file
        NSDictionary *iconState = [NSDictionary dictionaryWithContentsOfFile:staleStateFilePath];
        [[ISIconSupport sharedInstance] repairAndReloadIconState:iconState];

        message = @"The layout has been restored.";
    }

    // Delete the old state file
    [[NSFileManager defaultManager] removeItemAtPath:staleStateFilePath error:NULL];

    // Inform the user of the result
    UIAlertView *view = [[UIAlertView alloc] initWithTitle:@"IconSupport" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [view show];
    [view release];

    // Call original implementation to dismiss the alert item
    %orig;
}

- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)require {
    NSString *title = @"IconSupport Warning";
    NSString *body = @"An icon layout from a previous installation of IconSupport has been detected.\n\n"
        "The layout may be quite old.\n\n"
        "Do you wish to restore it?";

    UIAlertView *alertView = [self alertSheet];
    [alertView setDelegate:self];
    [alertView setTitle:title];
    [alertView setMessage:body];
    [alertView addButtonWithTitle:@"Delete"];
    [alertView addButtonWithTitle:@"Restore"];
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

void initISStaleFileAlertItem() {
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
