#ifndef ICONSUPPORT_HEADERS_H_
#define ICONSUPPORT_HEADERS_H_

/**
 * AppID: com.apple.SpringBoard
 */

// iOS 3.2 ~ iOS 6.x
// NOTE: Only used in "classic" version of IconSupport.
@interface UIDevice (UIDevicePrivate)
- (BOOL)isWildcat;
@end

// iOS 3.x
@class SBButtonBar;

@interface SBIconList : NSObject @end

// iOS 4.x+
@interface SBIconListModel : NSObject
+ (int)maxIcons;
//+ (unsigned)maxIcons; // iOS 4.2+
@end
@interface SBDockIconListModel : SBIconListModel @end

@interface SBFolder : NSObject
+ (int)maxListCount;
//+ (unsigned)maxListCount; // iOS 7.0+
- (Class)listModelClass;
@end
@interface SBRootFolder : SBFolder
- (id)dockModel;
@end

// iOS 6.x+
@interface SBIconModelPropertyListFileStore : NSObject
@property(retain, nonatomic) NSURL *currentIconStateURL;
@property(retain, nonatomic) NSURL *desiredIconStateURL;
@end
@interface SBDefaultIconModelStore : SBIconModelPropertyListFileStore
+ (id)sharedInstance;
@end

// iOS 7.x+
@interface SBFolderSettings : NSObject // _UISettings
// CALLED
@property(nonatomic) BOOL allowNestedFolders;
@end

@interface SBPrototypeController : NSObject
// CALLED
+ (id)sharedInstance;
- (id)rootSettings;
@end

@interface SBRootSettings : NSObject // _UISettings
// CALLED
@property(retain) SBFolderSettings *folderSettings;
@end

// iOS (All versions)
@interface SBAlertItem : NSObject <UIAlertViewDelegate>
// NOTE: In iOS 3, this property is a UIModalView.
@property(readonly, retain) UIAlertView *alertSheet;
@end

@interface SBAlertItemsController : NSObject
+ (id)sharedInstance;
- (void)activateAlertItem:(id)item;
@end

@interface SBIconController : NSObject
+ (id)sharedInstance;
@end
@interface SBIconController (Firmware_GTE_60)
- (void)noteIconStateChangedExternally;
@end

@interface SBIconModel : NSObject
- (id)iconState;
@end
@interface SBIconModel (Firmware_LT_40)
@property(readonly, retain) SBButtonBar *buttonBar;
@property(readonly, retain) NSMutableArray *iconLists;
- (void)compactIconLists;
@end
@interface SBIconModel (Firmware_GTE_40_LT_60)
- (id)iconStatePath;
@end
@interface SBIconModel (Firmware_LT_60)
+ (id)sharedInstance;
- (void)noteIconStateChangedExternally;
@end

/**
 * AppID: com.apple.Preferences
 */

@interface PSSpecifier : NSObject {
    SEL getter;
    SEL setter;
}
@property(assign, nonatomic) SEL buttonAction;
@property(assign, nonatomic) int cellType;
@property(assign, nonatomic) Class detailControllerClass;
@property(assign, nonatomic) Class editPaneClass;
@property(retain, nonatomic) NSString *identifier;
@property(retain, nonatomic) NSString *name;
@property(assign, nonatomic) id target;
+ (id)preferenceSpecifierNamed:(id)named target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(int)cell edit:(Class)edit;
- (void)setProperty:(id)property forKey:(id)key;
@end

@interface PSViewController : UIViewController @end
@interface PSListController : PSViewController
- (id)specifierForID:(id)anId;
@end
@interface ResetPrefController : PSListController
- (void)resetIconPositions:(id)positions;
@end

#endif // ICONSUPPORT_HEADERS_H_

/* vim: set filetype=objcpp sw=4 ts=4 expandtab tw=80 ff=unix: */
