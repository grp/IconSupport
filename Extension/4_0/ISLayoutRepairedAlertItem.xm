#import "ISLayoutRepairedAlertItem.h"

%hook ISLayoutRepairedAlertItem

- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)require {
    NSString *title = @"IconSupport Notice";
    NSString *body = @"You have added or removed software that affects your icon layout.\n\nYour layout has been adjusted to prevent errors.";
    NSString *dismissButtonTitle = @"Dismiss";

    if (IOS_LT(10_0)) {
        UIAlertView *alertView = [self alertSheet];
        [alertView setDelegate:self];
        [alertView setTitle:title];
        [alertView setMessage:body];
        [alertView addButtonWithTitle:dismissButtonTitle];
    } else {
        UIAlertController *alertController = [self alertController];
        [alertController setTitle:title];
        [alertController setMessage:body];
        [alertController addAction:[UIAlertAction actionWithTitle:dismissButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self deactivateForButton];
        }]];
    }
}

%end

//==============================================================================

void initISLayoutRepairedAlertItem() {
    // Register new subclass
    initISAlertItem();
    Class $SuperClass = objc_getClass("ISAlertItem");
    if ($SuperClass != Nil) {
        Class $ISLayoutRepairedAlertItem = objc_allocateClassPair($SuperClass, "ISLayoutRepairedAlertItem", 0);
        if ($ISLayoutRepairedAlertItem != Nil) {
            objc_registerClassPair($ISLayoutRepairedAlertItem);
            %init();
        }
    }
}

/* vim: set ft=logos ff=unix tw=80 sw=4 ts=4 expandtab: */
