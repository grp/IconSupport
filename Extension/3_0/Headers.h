#ifndef ICONSUPPORT_HEADERS_H_
#define ICONSUPPORT_HEADERS_H_

/**
 * Bundle: com.apple.UIKit
 */

@interface UIDevice (UIDevicePrivate)
- (BOOL)isWildcat;
@end

/**
 * Bundle: com.apple.SpringBoard
 */

@interface SBIconList : NSObject @end
@interface SBIconList (Firmware_LT_32)
// CALLED
- (id)dictionaryRepresentation;
@end
@interface SBIconList (Firmware_GTE_32)
// CALLED
- (id)representation;
@end

@class SBButtonBar;
@interface SBIconModel : NSObject {
    NSDictionary *_previousIconState;
}
// CALLED
@property(readonly, retain) SBButtonBar *buttonBar;
@property(readonly, retain) NSMutableArray *iconLists;
- (void)compactIconLists;

// HOOKED
- (BOOL)importState:(id)state;
- (id)iconState;
- (void)_writeIconState;
- (id)exportState;
- (void)relayout;
@end

#endif // ICONSUPPORT_HEADERS_H_

/* vim: set filetype=objcpp sw=4 ts=4 expandtab tw=80 ff=unix: */
