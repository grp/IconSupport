// Updated for iOS4 by Sakurina and chpwn.

#import "ISIconSupport.h"

#include <substrate.h>
#include "PreferenceConstants.h"

#define kISiPhoneDefaultMaxIconsPerPage 16
#define kISiPhoneDefaultColumnsPerPage 4
#define kISiPhoneDefaultRowsPerPage 4

#define kISiPadDefaultMaxIconsPerPage 20
#define kISiPadDefaultColumnsPerPage 4
#define kISiPadDefaultRowsPerPage 5

#ifdef DEBUG
#define ISLog NSLog
#else
#define ISLog(...) 
#endif

static BOOL hasSubfolderSupport_ = NO;

// Number of lists in a folder may exceed maxLists; gather orphaned icons for later redistribution
static NSMutableArray *orphanedIcons_ = nil;

static NSDictionary * repairFolderIconState(NSDictionary *folderState, BOOL isRootFolder, BOOL isDock) {
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
        // If this is the root folder or the dock, create global orphaned icons array
        if (isRootFolder || isDock) {
            // NOTE: Root folder and dock are processed separately.
            orphanedIcons_ = [[NSMutableArray alloc] init];
        }

        // Determine icon, list limits for the given folder
        // NOTE: Must create an instance of the folder to determine the list model class.
        // FIXME: If handling of special folders is ever added, this part will
        //        need to be updated in order to process correct folder class.
        int maxLists, maxIcons;
        Class $FolderClass = (isRootFolder || isDock) ? objc_getClass("SBRootFolder") : objc_getClass("SBFolder");
        SBFolder *folder = [[$FolderClass alloc] init];
        if (isDock) {
            maxLists = 1;
            maxIcons = [[[(SBRootFolder *)folder dockModel] class] maxIcons];
        } else {
            maxLists = [$FolderClass maxListCount];
            maxIcons = [[folder listModelClass] maxIcons];
        }
        [folder release];

        // Look for and process any subfolders
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
                    [[item objectForKey:@"listType"] isEqualToString:@"folder"]) {
                    // Update the icon state for the subfolder
                    NSDictionary *subFolderState = repairFolderIconState(item, NO, NO);

                    // Remove the old folder
                    [iconList removeObjectAtIndex:i];

                    if (isRootFolder || hasSubfolderSupport_) {
                        // Insert fixed-up folder in place of old folder
                        [iconList insertObject:subFolderState atIndex:i];
                    } else {
                        // Subfolders not supported; orphan the icons for redistribution
                        for (NSArray *subList in [subFolderState objectForKey:@"iconLists"]) {
                            [orphanedIcons_ addObjectsFromArray:subList];
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
        [iconLists addObject:[NSArray arrayWithArray:orphanedIcons_]];
        [orphanedIcons_ removeAllObjects];

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
                        [orphanedIcons_ addObjectsFromArray:surplusIcons];
                    }
                }
            }
        }

        // If this is the root folder or the dock, free the global orphaned icons array
        // NOTE: Any remaining icons will be lost in the ether
        //       (but still accessible via Spotlight).
        if (isRootFolder || isDock) {
            [orphanedIcons_ release];
            orphanedIcons_ = nil;
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
    // Update icon lists for the dock
    // NOTE: Wrap the array in a fake folder in order to pass to update function.
    // XXX: This code assumes that the dock never has more than one icon list.
    NSArray *dock = [[NSArray alloc] initWithObject:[iconState objectForKey:@"buttonBar"]];
    NSDictionary *folder = [[NSDictionary alloc] initWithObjectsAndKeys:dock, @"iconLists", nil];
    [dock release];
    dock = [repairFolderIconState(folder, NO, YES) objectForKey:@"iconLists"];
    [folder release];

    // Update icon lists for the root folder
    iconState = repairFolderIconState(iconState, YES, NO);

    // Combine fixed dock and lists
    iconState = [[iconState mutableCopy] autorelease];
    [(NSMutableDictionary *)iconState setObject:[dock lastObject] forKey:@"buttonBar"];

    return iconState;
}

static BOOL needsConversion_ = NO;

%hook SBIconModel

- (BOOL)importState:(id)state {
    // Returning NO disables iTunes sync
    return [[ISIconSupport sharedInstance] isBeingUsedByExtensions] ? NO : %orig;
}

- (id)init {
    // Upon upgrading IconSupport, if a user has an IconSupportState.plist
    // file but no IconSupport-enabled extensions, must rename plist file to
    // IconState.plist.
    // NOTE: Prior to version 1.7.5, IconSupport always used IconSupportState.plist,
    // even when no IconSupport-enabled extensions were in use. Since 1.7.5,
    // IconSupport will now use IconState.plist in that situation.
    BOOL firstLoadAfterUpgrade = NO;
    CFPropertyListRef propList = CFPreferencesCopyAppValue((CFStringRef)kFirstLoadAfterUpgrade, CFSTR(APP_ID));
    if (propList != NULL) {
        if (CFGetTypeID(propList) == CFBooleanGetTypeID()) {
            firstLoadAfterUpgrade = CFBooleanGetValue(reinterpret_cast<CFBooleanRef>(propList));
        }
        CFRelease(propList);
    }

    if (firstLoadAfterUpgrade) {
        // IconSupport has just been upgraded
        if (![[ISIconSupport sharedInstance] isBeingUsedByExtensions]) {
            // No IconSupport-enabled extensions are loaded
            // FIXME: Avoid hard-coding paths, as they may change in future firmware.
            NSFileManager *manager = [NSFileManager defaultManager];
            NSString *basePath = @"/var/mobile/Library/SpringBoard";
            NSString *path = [basePath stringByAppendingString:@"/IconSupportState.plist"];
            if ([manager fileExistsAtPath:path]) {
                // Move IconSupport state file to default state file
                NSString *defPath = [basePath stringByAppendingString:@"/IconState.plist"];
                BOOL success = [manager removeItemAtPath:defPath error:NULL];
                if (success) {
                    success = [manager copyItemAtPath:path toPath:defPath error:NULL];
                    if (success) {
                        [manager removeItemAtPath:path error:NULL];
                    }
                }
            }
        }

        // Save fact that first load has completed
        CFPreferencesSetAppValue((CFStringRef)kFirstLoadAfterUpgrade, NULL, CFSTR(APP_ID));
        CFPreferencesAppSynchronize(CFSTR(APP_ID));
    }

    return %orig;
}

- (id)iconStatePath {
    NSString *defPath = %orig;

    NSString *basePath = [defPath stringByDeletingLastPathComponent];
    NSString *path = [basePath stringByAppendingString:@"/IconSupportState.plist"];

    // Compare the previous and new hash
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *oldHash = [defaults stringForKey:@"ISLastUsed"];
    NSString *newHash = [[ISIconSupport sharedInstance] extensionString];
    ISLog(@"Old hash is: %@, new hash is: %@", oldHash, newHash);

    // NOTE: This should only be possible once (at respring).
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![newHash isEqualToString:oldHash]) {
        // If no IconSupport-using extensions are loaded, rename the state file
        if ([newHash isEqualToString:@""] && [manager fileExistsAtPath:path]) {
            BOOL success = [manager removeItemAtPath:defPath error:NULL];
            if (success) {
                success = [manager copyItemAtPath:path toPath:defPath error:NULL];
                if (success) {
                    [manager removeItemAtPath:path error:NULL];
                }
            }
        }

        // Mark that the icon state may require fixing-up
        needsConversion_ = YES;

        // Save new hash to settings
        [defaults setObject:newHash forKey:@"ISLastUsed"];
        ISLog(@"Saved current hash (%@) to ISLastUsed key.", newHash);
    }

    if ([newHash isEqualToString:@""]) {
        // No IconSupport-enabled extensions are in use; use default path
        path = defPath;
    } else if (![manager fileExistsAtPath:path]) {
        // IconSupport state file does not exist; use default (Safe Mode) file
        [manager copyItemAtPath:defPath toPath:path error:NULL];
        ISLog(@"IconSupport state file does not exist; using default.");
    }

    return path;
}

- (id)exportState:(BOOL)withFolders {
    NSArray *origState = %orig;

    if (![[ISIconSupport sharedInstance] isBeingUsedByExtensions]) {
        return origState;
    }

    // Add dock, unmodified,  to exported state
    NSMutableArray *newState = [NSMutableArray array];
    [newState addObject:[origState objectAtIndex:0]];

    // Collect icons from root folder and all subfolders
    NSMutableArray *rootFolderIcons = [[NSMutableArray alloc] init];
    NSArray *iconLists = [origState subarrayWithRange:NSMakeRange(1, [origState count] - 1)];
    for (NSArray *iconList in iconLists) {
        for (NSDictionary *icon in iconList) {
            NSArray *folderIconLists = [icon objectForKey:@"iconLists"];
            if (folderIconLists != nil) {
                // Is a folder
                // NOTE: Must flatten to avoid issues with extensions that
                //       modify the number of icons/lists that folders can hold.
                for (NSArray *folderIconList in folderIconLists) {
                    [rootFolderIcons addObjectsFromArray:folderIconList];
                }
            } else {
                // Is not a folder
                [rootFolderIcons addObject:icon];
            }
        }
    }

    // Split into pages of 16
    // FIXME: Need to update for iPad?
    while ([rootFolderIcons count] > kISiPhoneDefaultMaxIconsPerPage) {
        NSRange range = NSMakeRange(0, kISiPhoneDefaultMaxIconsPerPage);
        NSArray *page = [rootFolderIcons subarrayWithRange:range];
        [newState addObject:page];
        [rootFolderIcons removeObjectsInRange:range];
    }

    // If root folder is not empty, add to exported icon state
    if ([rootFolderIcons count] > 0) {
        [newState addObject:rootFolderIcons];
    }
    [rootFolderIcons release];

    return newState;
}

// 5.x
%group GFirmware5x

- (id)_cachedIconStatePath {
    // NOTE: Failing to override this could cause Safe Mode's cached layout to
    //       be used (if it exists) and thus overwrite IconSupport's layout.
    NSString *path = %orig;

    if ([[ISIconSupport sharedInstance] isBeingUsedByExtensions]) {
        path = [[path stringByDeletingLastPathComponent] stringByAppendingString:@"/DesiredIconSupportState.plist"];
    }

    return path;
}

- (id)_iconState:(BOOL)ignoreDesiredIconStateFile {
    id result = %orig;
    if (needsConversion_) {
        result = repairIconState(result);
        needsConversion_ = NO;
    }
    return result;
}

%end // GFirmware5x

// 4.x
%group GFirmware4x

- (id)_iconState {
    id result = %orig;
    if (needsConversion_) {
        result = repairIconState(result);
        needsConversion_ = NO;
    }
    return result;
}

%end // GFirmware4x

%end // SBIconModel

__attribute__((constructor)) static void init() {
    // Only hook for iOS 4 or newer
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_4_0) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        // NOTE: This library should only be loaded for SpringBoard
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundleId isEqualToString:@"com.apple.springboard"]) {
            %init;

            // Initialize firmware-dependent hooks
            if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_5_0) {
                // iOS 4
                %init(GFirmware4x);
            } else {
                // iOS 5
                %init(GFirmware5x);
            }

            // FIXME: Find a better way to detect if subfolders are supported.
            NSFileManager *manager = [NSFileManager defaultManager];
            hasSubfolderSupport_ =
                [manager fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/FolderEnhancer.dylib"] ||
                [manager fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/FoldersInFolders.dylib"];
        }

        [pool release];
    }
}

/* vim: set filetype=objcpp sw=4 ts=4 expandtab tw=80 ff=unix: */
