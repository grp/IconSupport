#import "ISAlertItem.h"

%hook ISAlertItem

- (BOOL)shouldShowInLockScreen { return NO; }

%end

//------------------------------------------------------------------------------

%hook ISAlertItem %group GFirmware_GTE_40_LT_50

- (void)didDeactivateForReason:(int)reason {
    %orig();

    if (reason == 0) {
        // Was deactivated due to lock, not user interaction
        // FIXME: Is there no better way to get the alert to reappear?
        [[objc_getClass("SBAlertItemsController") sharedInstance] activateAlertItem:self];
    }
}

%end %end

//------------------------------------------------------------------------------

%hook ISAlertItem %group GFirmware_GTE_50_LT_60

- (BOOL)reappearsAfterLock { return YES; }

%end %end

//------------------------------------------------------------------------------

%hook ISAlertItem %group GFirmware_GTE_60

// FIXME: Is this the correct way to do this?
//        And even though reappearsAfterLock returns NO by default,
//        the alert still reappears... why?
- (BOOL)behavesSuperModally { return YES; }

%end %end

//==============================================================================

void initISAlertItem() {
    // Make sure class has not already been initialized
    if (objc_getClass("ISAlertItem") != Nil) return;

    // Register new subclass
    Class $SuperClass = objc_getClass("SBAlertItem");
    if ($SuperClass != Nil) {
        Class $ISAlertItem = objc_allocateClassPair($SuperClass, "ISAlertItem", 0);
        if ($ISAlertItem != Nil) {
            objc_registerClassPair($ISAlertItem);

            %init();

            if (IOS_LT(5_0)) {
                %init(GFirmware_GTE_40_LT_50);
            } else if (IOS_LT(6_0)) {
                %init(GFirmware_GTE_50_LT_60);
            } else {
                %init(GFirmware_GTE_60);
            }
        }
    }
}

/* vim: set ft=logos ff=unix tw=80 sw=4 ts=4 expandtab: */
