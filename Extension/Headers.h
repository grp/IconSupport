#ifndef ICONSUPPORT_HEADERS_H_
#define ICONSUPPORT_HEADERS_H_

@interface UIDevice (UIDevicePrivate)
- (BOOL)isWildcat;
@end

@interface SBAlertItem : NSObject <UIAlertViewDelegate>
// NOTE: In iOS 3, this property is a UIModalView.
@property(readonly, retain) UIAlertView *alertSheet;
@end

@interface SBAlertItemsController : NSObject
+ (id)sharedInstance;
- (void)activateAlertItem:(id)item;
@end

 // iOS 3.x
@class SBButtonBar;

@interface SBIconModel : NSObject
+ (id)sharedInstance;
- (id)iconState;
- (void)noteIconStateChangedExternally;
@end
@interface SBIconModel (Firmware_LT_40)
@property(readonly, retain) SBButtonBar *buttonBar;
@property(readonly, retain) NSMutableArray *iconLists;
- (void)compactIconLists;
@end
@interface SBIconModel (Firmware_GTE_40)
- (id)iconStatePath;
@end

 // iOS 3.x
@interface SBIconList : NSObject @end

// iOS 4.x+
@interface SBFolder : NSObject
+ (int)maxListCount;
- (Class)listModelClass;
@end
@interface SBRootFolder : SBFolder
- (id)dockModel;
@end

// iOS 4.x+
@interface SBIconListModel : NSObject
+ (int)maxIcons;
@end
@interface SBDockIconListModel : SBIconListModel @end

// iOS 4.x+
@class SBFolderIcon;

#endif // ICONSUPPORT_HEADERS_H_

/* vim: set filetype=objcpp sw=4 ts=4 expandtab tw=80 ff=unix: */
