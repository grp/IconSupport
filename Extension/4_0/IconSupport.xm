// Updated for iOS4 by Sakurina and chpwn.

#import "ISIconSupport.h"
#import "ISLayoutRepairedAlertItem.h"
#import "ISStaleFileAlertItem.h"

#include <substrate.h>
#include "PreferenceConstants.h"

#define kFilenameState @"IconSupportState.plist"
#define kFilenameDesiredState @"DesiredIconSupportState.plist"

static NSMutableArray *queuedAlerts$ = nil;

static void queueAlert(SBAlertItem *alert) {
    if (queuedAlerts$ == nil) {
        queuedAlerts$ = [[NSMutableArray alloc] init];
    }
    [queuedAlerts$ addObject:alert];
}

//------------------------------------------------------------------------------

static BOOL hasSubfolderSupport$ = NO;

static NSDictionary * repairFolderIconState(NSDictionary *folderState, NSMutableArray *orphanedIcons, BOOL isRootFolder, BOOL isDock) {
    NSMutableArray *iconLists = [[NSMutableArray alloc] init];

    NSArray *currentIconLists = [folderState objectForKey:@"iconLists"];
    if ([currentIconLists count] == 0) {
        // Icon lists array is empty; add a single empty list
        // NOTE: This can happen for the dock when it contains no icons.
        // XXX: Can this happen for anything *besides* the dock?
        NSArray *array = [[NSArray alloc] init];
        [iconLists addObject:array];
        [array release];
    } else {
        // Determine icon, list limits for the given folder
        // NOTE: Must create an instance of the folder to determine the list model class.
        // FIXME: If handling of special folders is ever added, this part will
        //        need to be updated in order to process correct folder class.
        int maxLists, maxIcons;
        Class $FolderClass = (isRootFolder || isDock) ? objc_getClass("SBRootFolder") : objc_getClass("SBFolder");
        if (IOS_LT(7_1)) {
            SBFolder *folder = [[$FolderClass alloc] init];
            if (isDock) {
                maxLists = 1;
                maxIcons = [[[(SBRootFolder *)folder dockModel] class] maxIcons];
            } else {
                maxLists = [$FolderClass maxListCount];
                maxIcons = [[folder listModelClass] maxIcons];
            }
            [folder release];
        } else {
            SBIconController *iconCont = [objc_getClass("SBIconController") sharedInstance];
            if (isDock) {
                maxLists = 1;
                maxIcons = [iconCont maxIconCountForDock];
            } else {
                maxLists = [iconCont maxListCountForFolders];
                maxIcons = [iconCont maxIconCountForListInFolderClass:$FolderClass];
            }
        }

        // Look for and process any subfolders
        BOOL supportsListTypes = IOS_GTE(5_0);
        for (NSArray *list in currentIconLists) {
            // Make a mutable copy of the list for modification
            NSMutableArray *iconList = [list mutableCopy];

            Class $NSDictionary = [NSDictionary class];
            unsigned int numOfIcons = [iconList count];
            for (unsigned int i = 0; i < numOfIcons; i++) {
                // NOTE: iOS 5.x has special folders. such as Newsstand;
                //       only process 'normal' folders.
                // FIXME: Is it actually necessary to skip these folders?
                id item = [iconList objectAtIndex:i];
                if ([item isKindOfClass:$NSDictionary] &&
                    (!supportsListTypes || [[item objectForKey:@"listType"] isEqualToString:@"folder"])) {
                    // Update the icon state for the subfolder
                    NSDictionary *subFolderState = repairFolderIconState(item, orphanedIcons, NO, NO);

                    // Remove the old folder
                    [iconList removeObjectAtIndex:i];

                    if (isRootFolder || isDock || hasSubfolderSupport$) {
                        // Insert fixed-up folder in place of old folder
                        [iconList insertObject:subFolderState atIndex:i];
                    } else {
                        // Subfolders not supported; orphan the icons for redistribution
                        for (NSArray *subList in [subFolderState objectForKey:@"iconLists"]) {
                            [orphanedIcons addObjectsFromArray:subList];
                        }

                        // As the removed folder was not replaced, must decrement icon count and counter
                        numOfIcons--;
                        i--;
                    }
                }
            }

            // Save the updated icon list
            [iconLists addObject:iconList];
            [iconList release];
        }

        // Add any orphaned icons as a single list to end of folder
        if ([orphanedIcons count] != 0) {
            [iconLists addObject:[NSMutableArray arrayWithArray:orphanedIcons]];
            [orphanedIcons removeAllObjects];
        }

        // Compact lists down to allowed maximum number of lists for this folder
        // NOTE: Lists are mutable as they were created as such, above.
        unsigned int numOfIconLists = [iconLists count];
        for (unsigned int i = (numOfIconLists - 1); (int)i > (maxLists - 1) && i > 0; i--) {
            // Add icons from this list to end of previous list
            NSMutableArray *thisList = [iconLists objectAtIndex:i];
            NSMutableArray *prevList = [iconLists objectAtIndex:(i - 1)];
            [prevList addObjectsFromArray:thisList];

            // Remove this list
            [iconLists removeObjectAtIndex:i];
        }

        // Ensure that lists don't contain more than allowed maximum number of icons
        numOfIconLists = [iconLists count];
        for (unsigned int i = 0; i < numOfIconLists; i++) {
            NSMutableArray *thisList = [iconLists objectAtIndex:i];
            unsigned int numOfIcons = [thisList count];
            if ((int)numOfIcons > maxIcons) {
                // This list has too many icons; remove surplus icons
                NSRange range = NSMakeRange(maxIcons, numOfIcons - maxIcons);
                NSArray *surplusIcons = [thisList subarrayWithRange:range];
                [thisList removeObjectsInRange:range];

                // Decide what to do with surplus icons
                unsigned int nextListIndex = i + 1;
                if (nextListIndex < numOfIconLists) {
                    // Following list exists; move surplus icons to it
                    NSMutableArray *nextList = [iconLists objectAtIndex:nextListIndex];
                    NSMutableArray *mergedList = [NSMutableArray arrayWithArray:surplusIcons];
                    [mergedList addObjectsFromArray:nextList];
                    [iconLists replaceObjectAtIndex:nextListIndex withObject:mergedList];
                } else {
                    // No more lists; move surplus icons to new list, if allowed
                    if ((int)numOfIconLists < maxLists) {
                        // Add surplus icons as new list
                        // NOTE: List will be processed by next iteration of this loop.
                        [iconLists addObject:[NSMutableArray arrayWithArray:surplusIcons]];
                        numOfIconLists++;
                    } else {
                        // List limit reached; add surplus icons to orphaned icons list
                        [orphanedIcons addObjectsFromArray:surplusIcons];
                    }
                }
            }
        }
    }

    // Return updated folder state
    // NOTE: Must copy original state to include display name and (if root folder) the dock.
    NSMutableDictionary *updatedFolderState = [NSMutableDictionary dictionaryWithDictionary:folderState];
    [updatedFolderState setObject:iconLists forKey:@"iconLists"];
    [iconLists release];
    return updatedFolderState;
}

// NOTE: This function cannot be static as it is accessed by other source files.
//       It is constrained to this dylib by using the fvisibility=hidden flag.
NSDictionary * repairIconState(NSDictionary *iconState) {
    // NOTE: Wrap the dock array in a fake folder in order to pass to repair function.
    // XXX: This code assumes that the dock never has more than one icon list.
    NSArray *dock = [[NSArray alloc] initWithObjects:[iconState objectForKey:@"buttonBar"], nil];
    NSDictionary *dockIconState = [NSDictionary dictionaryWithObject:dock forKey:@"iconLists"];
    [dock release];

    // Create an array to hold orphaned icons
    // NOTE: The number of lists in a folder may exceed the allowed maximum;
    //       orphaned icons will be gathered for later redistribution.
    NSMutableArray *orphanedIcons = [[NSMutableArray alloc] init];

    if (IOS_GTE(7_0)) {
        // NOTE: Check this value every time, as it could be changed mid-process
        //       (via, for example, the hidden settings panel).
        hasSubfolderSupport$ = [[[[objc_getClass("SBPrototypeController") sharedInstance] rootSettings] folderSettings] allowNestedFolders];
    }

    // Repair icon list for the dock
    dockIconState = repairFolderIconState(dockIconState, orphanedIcons, NO, YES);

    // Repair icon lists for the root folder
    iconState = repairFolderIconState(iconState, orphanedIcons, YES, NO);

    // Free the orphaned icons array
    // NOTE: Any remaining icons will be lost in the ether
    //       (but still accessible via Spotlight).
    [orphanedIcons release];

    // Combine fixed dock and lists
    iconState = [[iconState mutableCopy] autorelease];
    [(NSMutableDictionary *)iconState setObject:[[dockIconState objectForKey:@"iconLists"] lastObject] forKey:@"buttonBar"];

    return iconState;
}

//------------------------------------------------------------------------------

static void moveFile(NSString *srcPath, NSString *dstPath) {
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:srcPath]) {
        // Remove any existing file at destination
        if ([manager fileExistsAtPath:dstPath]) {
            if (![manager removeItemAtPath:dstPath error:NULL]) {
                return;
            }
        }

        // Move source file to destination
        [manager moveItemAtPath:srcPath toPath:dstPath error:NULL];
    }
}

//==============================================================================

static inline BOOL boolForKey(NSString *key, BOOL defaultValue) {
    BOOL result = defaultValue;
    CFPropertyListRef propList = CFPreferencesCopyAppValue((CFStringRef)key, CFSTR(APP_ID));
    if (propList) {
        if (CFGetTypeID(propList) == CFBooleanGetTypeID()) {
            result = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
        }
        CFRelease(propList);
    }
    return result;
}

%hook SBIconController

- (id)init {
    // FIXME: Avoid hard-coding paths, as they may change in future firmware.
    NSString *userPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *basePath = [userPath stringByAppendingPathComponent:@"SpringBoard"];
    NSString *iconSupportPath = [basePath stringByAppendingPathComponent:kFilenameState];
    NSString *staleStateFilePath = [iconSupportPath stringByAppendingString:@".stale"];

    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:staleStateFilePath]) {
        // An old state file exists; ask user whether to use or delete it.
        // NOTE: This should only happen after an install, not an upgrade.
        initISStaleFileAlertItem();

        SBAlertItem *alert = [[objc_getClass("ISStaleFileAlertItem") alloc] init];
        if (alert != nil) {
            queueAlert(alert);
            [alert release];
        }
    }

    NSString *defaultPath = [basePath stringByAppendingPathComponent:@"IconState.plist"];

    ISIconSupport *iconSupport = [ISIconSupport sharedInstance];
    BOOL isBeingUsed = [iconSupport isBeingUsedByExtensions];
    if (boolForKey(kFirstLoadAfterUpgrade, NO)) {
        // Upon upgrading IconSupport, if a user has an IconSupportState.plist
        // file but no IconSupport-enabled extensions, must rename plist file to
        // IconState.plist.
        // NOTE: Prior to version 1.7.5, IconSupport always used IconSupportState.plist,
        // even when no IconSupport-enabled extensions were in use. Since 1.7.5,
        // IconSupport will now use IconState.plist in that situation.
        if (!isBeingUsed) {
            // No IconSupport-enabled extensions are loaded;
            // move IconSupport state file to default state file
            moveFile(iconSupportPath, defaultPath);
        }

        // Save fact that first load has completed
        CFPreferencesSetAppValue((CFStringRef)kFirstLoadAfterUpgrade, NULL, CFSTR(APP_ID));
        CFPreferencesAppSynchronize(CFSTR(APP_ID));
    }

    // If number of extensions has changed, state will require repair
    // NOTE: Also repair if a previous request has been scheduled.
    BOOL needsRepair = boolForKey(kMarkedForRepair, NO);

    if (needsRepair) {
        // Was marked for repair; request has been received, remove it.
        CFPreferencesSetAppValue((CFStringRef)kMarkedForRepair, NULL, CFSTR(APP_ID));
        CFPreferencesAppSynchronize(CFSTR(APP_ID));
    }

    // Compare the previous and new hash
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *oldHash = [defaults stringForKey:@"ISLastUsed"];
    NSString *newHash = [iconSupport extensionString];
    if (![newHash isEqualToString:oldHash]) {
        // If no IconSupport-using extensions are loaded, rename the state file
        if (!isBeingUsed) {
            moveFile(iconSupportPath, defaultPath);
        }

        // Mark that the icon state should be repaired
        needsRepair = YES;

        // Save new hash to settings
        [defaults setObject:newHash forKey:@"ISLastUsed"];
    }

    // NOTE: Must set which path is in use, for possible repair below.
    NSString *path;
    if (!isBeingUsed) {
        // No IconSupport-enabled extensions are in use; use default path
        path = defaultPath;
    } else {
        if (![manager fileExistsAtPath:iconSupportPath]) {
            // IconSupport state file does not exist; use default (Safe Mode) file
            [manager copyItemAtPath:defaultPath toPath:iconSupportPath error:NULL];
        }
        path = iconSupportPath;
    }

    // Repair, if necessary
    if (needsRepair) {
        id iconState = [NSDictionary dictionaryWithContentsOfFile:path];
        id repairedState = repairIconState(iconState);
        if (![repairedState isEqual:iconState]) {
            // Store the repaired state
            [repairedState writeToFile:path atomically:YES];

            // Inform user that layout has been modified
            initISLayoutRepairedAlertItem();

            SBAlertItem *alert = [[objc_getClass("ISLayoutRepairedAlertItem") alloc] init];
            if (alert != nil) {
                queueAlert(alert);
                [alert release];
            }
        }
    }

    return %orig();
}

%end

//==============================================================================

%hook SBIconModel

- (BOOL)importState:(id)state {
    // Returning NO disables iTunes sync
    return [[ISIconSupport sharedInstance] isBeingUsedByExtensions] ? NO : %orig();
}

- (id)exportState:(BOOL)withFolders {
    if ([[ISIconSupport sharedInstance] isBeingUsedByExtensions]) {
        // Return a list containing a single "disabled by IconSupport" icon.
        return @[
            @[
                @{
                    @"displayIdentifier" : @"com.chpwn.iconsupport",
                    @"displayName" : @"IconSupport"
                }
            ], 
            @[]
        ];
    } else {
        return %orig();
    }
}

%end

//------------------------------------------------------------------------------

%hook SBIconModel %group GFirmware_LT_60

- (id)iconStatePath {
    NSString *path = %orig();
    if ([[ISIconSupport sharedInstance] isBeingUsedByExtensions]) {
        path = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:kFilenameState];
    }
    return path;
}

%end %end

//------------------------------------------------------------------------------

%hook SBIconModel %group GFirmware_GTE_50_LT_60

- (id)_cachedIconStatePath {
    // NOTE: Failing to override this could cause Safe Mode's cached layout to
    //       be used (if it exists) and thus overwrite IconSupport's layout.
    NSString *path = %orig();
    if ([[ISIconSupport sharedInstance] isBeingUsedByExtensions]) {
        path = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:kFilenameDesiredState];
    }
    return path;
}

%end %end

//==============================================================================

%hook SBDefaultIconModelStore %group GFirmware_GTE_60

- (id)init {
    self = %orig();
    if (self != nil) {
        if ([[ISIconSupport sharedInstance] isBeingUsedByExtensions]) {
            // Override icon state
            NSURL *url = [self currentIconStateURL];
            url = [[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:kFilenameState];
            [self setCurrentIconStateURL:url];

            // Override desired icon state
            url = [self desiredIconStateURL];
            url = [[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:kFilenameDesiredState];
            [self setDesiredIconStateURL:url];
        }
    }
    return self;
}

%end %end

//==============================================================================

%hook SpringBoard

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    %orig();

    // Display any queued alerts
    // NOTE: Perform here to prevent issues with more recent iOS versions
    //       (apparently due to the call to +[SBAlertItemsController sharedInstance]).
    if (queuedAlerts$ != nil) {
        SBAlertItemsController *controller = [objc_getClass("SBAlertItemsController") sharedInstance];
        for (SBAlertItem *alert in queuedAlerts$) {
            [controller activateAlertItem:alert];
        }
        [queuedAlerts$ release];
        queuedAlerts$ = nil;
    }
}

%end

//==============================================================================

%ctor {
    @autoreleasepool {
        // NOTE: This library should only be loaded for SpringBoard
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundleId isEqualToString:@"com.apple.springboard"]) {
            %init();

            // Initialize firmware-dependent hooks
            if (IOS_GTE(6_0)) {
                %init(GFirmware_GTE_60);
            } else {
                %init(GFirmware_LT_60);

                if (IOS_GTE(5_0)) {
                    %init(GFirmware_GTE_50_LT_60);
                }
            }

            if (IOS_LT(7_0)) {
                // FIXME: Find a better way to detect if subfolders are supported.
                NSFileManager *manager = [NSFileManager defaultManager];
                hasSubfolderSupport$ =
                    [manager fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/FolderEnhancer.dylib"] ||
                    [manager fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/FoldersInFolders.dylib"];
            }
        }
    }
}

/* vim: set ft=logos ff=unix tw=80 sw=4 ts=4 expandtab: */
