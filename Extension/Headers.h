#ifndef ICONSUPPORT_HEADERS_H_
#define ICONSUPPORT_HEADERS_H_

// iOS 3.x
@class SBButtonBar;
@interface SBIconModel : NSObject
@property(readonly, retain) NSMutableArray *iconLists;
@property(readonly, retain) SBButtonBar *buttonBar;
+ (id)sharedInstance;
- (void)compactIconLists;
- (id)iconState;
- (void)noteIconStateChangedExternally;
@end
@interface SBIconModel (Firmware_GTE_40)
- (id)iconStatePath;
@end

// iOS 4.x
@interface UIDevice (UIDevicePrivate)
- (BOOL)isWildcat;
@end

@interface SBFolder : NSObject
+ (int)maxListCount;
- (Class)listModelClass;
@end
@interface SBRootFolder : SBFolder
- (id)dockModel;
@end

@interface SBIconList : NSObject @end

@interface SBIconListModel : NSObject
+ (int)maxIcons;
@end
@interface SBDockIconListModel : SBIconListModel @end

@class SBFolderIcon;

#endif // ICONSUPPORT_HEADERS_H_

/* vim: set filetype=objcpp sw=4 ts=4 expandtab tw=80 ff=unix: */
