#import "ISStaleFileAlertItem.h"

#import "ISIconSupport.h"
#include "PreferenceConstants.h"

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
    UIAlertView *view = [[UIAlertView alloc] initWithTitle:@"IconSupport" message:message delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
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

%end

//==============================================================================

void initISStaleFileAlertItem() {
    // Register new subclass
    initISAlertItem();
    Class $SuperClass = objc_getClass("ISAlertItem");
    if ($SuperClass != Nil) {
        Class $ISStaleFileAlertItem = objc_allocateClassPair($SuperClass, "ISStaleFileAlertItem", 0);
        if ($ISStaleFileAlertItem != Nil) {
            objc_registerClassPair($ISStaleFileAlertItem);
            %init;
        }
    }
}

/* vim: set filetype=objcpp sw=4 ts=4 expandtab tw=80 ff=unix: */
