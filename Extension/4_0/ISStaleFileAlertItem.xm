#import "ISStaleFileAlertItem.h"

#import "ISIconSupport.h"
#include "PreferenceConstants.h"

%hook ISStaleFileAlertItem

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSString *userPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *staleStateFilePath = [userPath stringByAppendingPathComponent:@"SpringBoard/IconSupportState.plist.stale"];

    NSString *message = nil;
    if (buttonIndex == 0) {
        // Apply the old state file
        NSDictionary *iconState = [NSDictionary dictionaryWithContentsOfFile:staleStateFilePath];
        [[ISIconSupport sharedInstance] repairAndReloadIconState:iconState];

        message = @"The layout has been restored.";
    } else {
        message = @"The layout has been deleted.";
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
        "The layout may be up to a week old.\n\n"
        "Do you wish to restore or delete it?";

    UIAlertView *alertView = [self alertSheet];
    [alertView setDelegate:self];
    [alertView setTitle:title];
    [alertView setMessage:body];
    [alertView addButtonWithTitle:@"Restore"];
    [alertView addButtonWithTitle:@"Delete"];
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

/* vim: set ft=logos ff=unix tw=80 sw=4 ts=4 expandtab: */
