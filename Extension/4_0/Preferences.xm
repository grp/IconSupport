#import "ISIconSupport.h"

#include <notify.h>
#include <substrate.h>

static char kIconLayoutActionSheet;

%hook ResetPrefController

- (id)loadSpecifiersFromPlistName:(id)plistName target:(id)target {
    NSMutableArray *specifiers = [NSMutableArray array];
    for (id specifier in %orig) {
        // Search for the "Reset Home Screen Layout" specifier
        if ([[specifier identifier] isEqualToString:@"RESET_ICONS_LABEL"]) {
            // Replace specifier with one that will call our method
            // NOTE: The original is of class PSConfirmationSpecifier, which
            //       will cause a plist-defined action sheet to be shown before
            //       the method is called. Thus the specifier must be replaced
            //       instead of simply modified.
            PSSpecifier *replacement = [objc_getClass("PSSpecifier")
                preferenceSpecifierNamed:[specifier name]
                target:MSHookIvar<id>(specifier, "target")
                set:MSHookIvar<SEL>(specifier, "setter")
                get:MSHookIvar<SEL>(specifier, "getter")
                detail:MSHookIvar<Class>(specifier, "detailControllerClass")
                cell:MSHookIvar<int>(specifier, "cellType")
                edit:MSHookIvar<Class>(specifier, "editPaneClass")
                ];
            [replacement setProperty:[specifier identifier] forKey:@"id"];
            if (IOS_LT(6_0)) {
                SEL &action = MSHookIvar<SEL>(replacement, "action");
                action = @selector(showLayoutPicker:);
            } else {
                [replacement setButtonAction:@selector(showLayoutPicker:)];
            }
            [specifiers addObject:replacement];
        } else {
            [specifiers addObject:specifier];
        }
    }

    return specifiers;
}

%new
- (void)showLayoutPicker:(id)sender
{
    UIActionSheet *sheet = [[UIActionSheet alloc]
        initWithTitle:@"Select the home screen layout to apply.\n\nThis will overwrite your current layout and cannot be undone."
        delegate:(id)self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil
        otherButtonTitles:@"Factory Defaults", @"Safe Mode", nil];
    [sheet showInView:[self view]];

    // Store the action sheet for later comparison
    objc_setAssociatedObject(self, &kIconLayoutActionSheet, sheet, OBJC_ASSOCIATION_RETAIN);
    [sheet release];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    UIActionSheet *sheet = objc_getAssociatedObject(self, &kIconLayoutActionSheet);
    if (sheet == actionSheet) {
        if (buttonIndex == 0) {
            // Factory Defaults
            [self resetIconPositions:[self specifierForID:@"RESET_ICONS_LABEL"]];
        } else if (buttonIndex == 1) {
            // Safe Mode
            notify_post(APP_ID".layout.safemode");
        }

        // Release the sheet
        objc_setAssociatedObject(self, &kIconLayoutActionSheet, nil, OBJC_ASSOCIATION_RETAIN);
    } else {
        %orig;
    }
}

- (void)resetIconPositions:(id)sender {
    NSString *userPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *iconSupportPath = [userPath stringByAppendingPathComponent:@"SpringBoard/IconSupportState.plist"];
    [[NSFileManager defaultManager] removeItemAtPath:iconSupportPath error:NULL];
    %orig;
}

%end

//==============================================================================

static void importLayoutSafeMode(CFNotificationCenterRef center, void *observer,
    CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    NSDictionary *iconState = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/SpringBoard/IconState.plist"];
    [[ISIconSupport sharedInstance] repairAndReloadIconState:iconState];
}

//==============================================================================

__attribute__((constructor)) static void init() {
    @autoreleasepool {
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundleId isEqualToString:@"com.apple.Preferences"]) {
            // NOTE: These hooks should only be loaded for Preferences.app (Settings)
            CFPropertyListRef propList = CFPreferencesCopyAppValue(CFSTR("ISLastUsed"), CFSTR("com.apple.springboard"));
            if (propList != NULL) {
                if (CFGetTypeID(propList) == CFStringGetTypeID()) {
                    if (![(NSString *)propList isEqualToString:@""]) {
                        // IconSupport is in use; initialize hooks
                        %init;
                    }
                }
                CFRelease(propList);
            }
        } else if ([bundleId isEqualToString:@"com.apple.springboard"]) {
            // Add observer for notifications from Preferences.app
            CFNotificationCenterAddObserver(
                    CFNotificationCenterGetDarwinNotifyCenter(),
                    NULL, importLayoutSafeMode, CFSTR(APP_ID".layout.safemode"),
                    NULL, 0);
        }
    }
}

/* vim: set filetype=objcpp sw=4 ts=4 expandtab tw=80 ff=unix: */
