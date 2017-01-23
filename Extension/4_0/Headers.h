#ifndef ICONSUPPORT_HEADERS_H_
#define ICONSUPPORT_HEADERS_H_

/**
 * Bundle: com.apple.SpringBoardUIFramework
 */

@interface SBAlertItem : NSObject <UIAlertViewDelegate>
// CALLED
- (UIAlertView *)alertSheet;
// HOOKED
- (BOOL)shouldShowInLockScreen;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)require;
@end
@interface SBAlertItem (Firmware_GTE_40_LT_50)
// HOOKED
- (void)didDeactivateForReason:(int)reason;
@end
@interface SBAlertItem (Firmware_GTE_50_LT_60)
// HOOKED
- (BOOL)reappearsAfterLock;
@end
@interface SBAlertItem (Firmware_GTE_60)
// HOOKED
- (BOOL)behavesSuperModally;
@end

/**
 * Bundle: com.apple.SpringBoard
 */

@interface SBAlertItemsController : NSObject
// CALLED
+ (id)sharedInstance;
- (void)activateAlertItem:(id)item;
@end

@interface SBFolder : NSObject
// CALLED
- (Class)listModelClass;
@end
@interface SBFolder (Firmware_LT_71)
// CALLED
+ (int)maxListCount;
//+ (unsigned)maxListCount; // Firmware_GTE_70
@end
@interface SBRootFolder : SBFolder @end
@interface SBRootFolder (Firmware_GTE_40_LT_71)
// CALLED
- (id)dockModel;
@end

@interface SBIconController : NSObject
// CALLED
+ (id)sharedInstance;
// HOOKED
- (id)init;
@end
@interface SBIconController (Firmware_GTE_60)
// CALLED
- (id)model;
- (void)noteIconStateChangedExternally;
@end
@interface SBIconController (Firmware_GTE_71)
// CALLED
- (NSUInteger)maxIconCountForDock;
- (NSUInteger)maxIconCountForListInFolderClass:(Class)klass;
- (NSUInteger)maxListCountForFolders;
@end

@interface SBIconListModel : NSObject @end
@interface SBIconListModel (Firmware_LT_71)
// CALLED
+ (int)maxIcons;
//+ (unsigned)maxIcons; // Firmware_GTE_42
@end
@interface SBDockIconListModel : SBIconListModel @end // Firmware_GTE_40_LT_70

@interface SBIconModel : NSObject
// CALLED
- (id)iconState;
// HOOKED
- (BOOL)importState:(id)state;
- (id)exportState:(BOOL)withFolders;
@end
@interface SBIconModel (Firmware_GTE_50_LT_60)
// HOOKED
- (id)_cachedIconStatePath;
@end
@interface SBIconModel (Firmware_LT_60)
// CALLED
+ (id)sharedInstance;
- (id)model;
- (void)noteIconStateChangedExternally;

// HOOKED
- (id)iconStatePath;
@end

@interface SpringBoard : UIApplication
// HOOKED
- (void)applicationDidFinishLaunching:(UIApplication *)application;
@end

// Firmware_GTE_60
@interface SBIconModelPropertyListFileStore : NSObject
// CALLED
@property(retain, nonatomic) NSURL *currentIconStateURL;
@property(retain, nonatomic) NSURL *desiredIconStateURL;
@end

@interface SBDefaultIconModelStore : SBIconModelPropertyListFileStore
// HOOKED
- (id)init;
@end

// Firmware_GTE_70
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

/**
 * Bundle: com.apple.Preferences
 */

@interface PSSpecifier : NSObject {
    SEL getter;
    SEL setter;
}
@property(assign, nonatomic) int cellType;
@property(assign, nonatomic) Class detailControllerClass;
@property(assign, nonatomic) Class editPaneClass;
@property(assign, nonatomic) id target;

// CALLED
@property(assign, nonatomic) SEL buttonAction;
@property(retain, nonatomic) NSString *identifier;
@property(retain, nonatomic) NSString *name;
+ (id)preferenceSpecifierNamed:(id)named target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(int)cell edit:(Class)edit;
- (void)setProperty:(id)property forKey:(id)key;
@end

@interface PSViewController : UIViewController @end
@interface PSListController : PSViewController
// CALLED
- (id)specifierForID:(id)anId;
@end
@interface ResetPrefController : PSListController
// HOOKED
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;
- (id)loadSpecifiersFromPlistName:(id)plistName target:(id)target;

// HOOKED AND CALLED
- (void)resetIconPositions:(id)positions;
@end

#endif // ICONSUPPORT_HEADERS_H_

/* vim: set ft=objc ff=unix tw=80 sw=4 ts=4 expandtab: */
