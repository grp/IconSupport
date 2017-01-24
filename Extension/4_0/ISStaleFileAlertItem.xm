#import "ISStaleFileAlertItem.h"

#import "ISIconSupport.h"
#include "PreferenceConstants.h"

static NSString *staleStateFilePath() {
    NSString *userPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [userPath stringByAppendingPathComponent:@"SpringBoard/IconSupportState.plist.stale"];
}

static void restoreLayout() {
    NSString *path = staleStateFilePath();
    NSDictionary *iconState = [NSDictionary dictionaryWithContentsOfFile:path];
    [[ISIconSupport sharedInstance] repairAndReloadIconState:iconState];
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}

static void deleteLayout() {
    NSString *path = staleStateFilePath();
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}

static void didRestoreLayout() {
    NSString *title = @"IconSupport";
    NSString *message = @"The layout has been restored.";
    NSString *buttonTitle = @"Dismiss";
    UIAlertView *view = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:buttonTitle otherButtonTitles:nil];
    [view show];
    [view release];
}

static void didDeleteLayout() {
    NSString *title = @"IconSupport";
    NSString *message = @"The layout has been deleted.";
    NSString *buttonTitle = @"Dismiss";
    UIAlertView *view = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:buttonTitle otherButtonTitles:nil];
    [view show];
    [view release];
}

%hook ISStaleFileAlertItem

- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)require {
    NSString *title = @"IconSupport Warning";
    NSString *body = @"An icon layout from a previous installation of IconSupport has been detected.\n\n"
        "The layout may be up to a week old.\n\n"
        "Do you wish to restore or delete it?";
    NSString *restoreButtonTitle = @"Restore";
    NSString *deleteButtonTitle = @"Delete";

    if (IOS_LT(10_0)) {
        UIAlertView *alertView = [self alertSheet];
        [alertView setDelegate:self];
        [alertView setTitle:title];
        [alertView setMessage:body];
        [alertView addButtonWithTitle:restoreButtonTitle];
        [alertView addButtonWithTitle:deleteButtonTitle];
    } else {
        UIAlertController *alertController = [self alertController];
        [alertController setTitle:title];
        [alertController setMessage:body];
        [alertController addAction:[UIAlertAction actionWithTitle:restoreButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self deactivateForButton];
            restoreLayout();
            didRestoreLayout();
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:deleteButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self deactivateForButton];
            deleteLayout();
            didDeleteLayout();
        }]];
    }
}

%end

%hook ISStaleFileAlertItem %group GFirmware_LT_10

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        restoreLayout();
        didRestoreLayout();
    } else {
        deleteLayout();
        didDeleteLayout();
    }

    // Call original implementation to dismiss the alert item.
    %orig;
}

%end %end

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

            if (IOS_LT(10_0)) {
                %init(GFirmware_LT_10);
            }
        }
    }
}

/* vim: set ft=logos ff=unix tw=80 sw=4 ts=4 expandtab: */
