// Completely ripped out of Iconoclasm (by Sakurina).
// Completely ripped out of FCSB (by chpwn).

// Updated for iPad by Sakurina.
// Updated for iOS4 by Sakurina and chpwn.

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

   -=-=-=-= EXAMPLE USAGE =-=-=-=-

   dlopen("/Library/MobileSubstrate/DynamicLibraries/IconSupport.dylib", RTLD_NOW);
   [[objc_getClass("ISIconSupport") sharedInstance] addExtension:@"infiniboard"];

 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */


#import "ISIconSupport.h"

#include <substrate.h>

#define APP_ID "com.chpwn.iconsupport"
#define kFirstLoadAfterUpgrade @"firstLoadAfterUpgrade"

// Horrible horrible way of going about doing it but it works /for now/
#define isiPad() ([UIDevice instancesRespondToSelector:@selector(isWildcat)] && [[UIDevice currentDevice] isWildcat])

#define kISiPhoneDefaultMaxIconsPerPage 16
#define kISiPhoneDefaultColumnsPerPage 4
#define kISiPhoneDefaultRowsPerPage 4
#define kISiPadDefaultMaxIconsPerPage 20
#define kISiPadDefaultColumnsPerPage 4
#define kISiPadDefaultRowsPerPage 5
#define kCFCoreFoundationVersionNumber_iPhoneOS_4_0 550.32
#define kCFCoreFoundationVersionNumber_iPhoneOS_5_0 674.0
#define isiOS3 (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iPhoneOS_4_0)
#define isiOS4 ((kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iPhoneOS_4_0) && (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iPhoneOS_5_0))

#ifdef DEBUG
#define ISLog NSLog
#else
#define ISLog(...) 
#endif

// 4.x
static id representation(id iconListOrDock) {
    // Returns a dictionary representation of an icon list or dock,
    // as it varies depending on the OS version installed.
    if ([iconListOrDock respondsToSelector:@selector(representation)])
        return [iconListOrDock performSelector:@selector(representation)];
    else if ([iconListOrDock respondsToSelector:@selector(dictionaryRepresentation)])
        return [iconListOrDock performSelector:@selector(dictionaryRepresentation)];

    return nil;
}

static BOOL hasSubfolderSupport_ = NO;

// Number of lists in a folder may exceed maxLists; gather orphaned icons for later redistribution
static NSMutableArray *orphanedIcons_ = nil;

static NSDictionary * repairFolderIconState(NSDictionary *folderState, BOOL isRootFolder, BOOL isDock)
{
    NSMutableArray *iconLists = [NSMutableArray array];

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
    return updatedFolderState;
}

NSDictionary * repairIconState(NSDictionary *iconState) {
    // Update icon lists for the dock
    // NOTE: Wrap the array in a fake folder in order to pass to update function.
    // XXX: This code assumes that the dock never has more than one icon list.
    NSArray *dock = [NSArray arrayWithObject:[iconState objectForKey:@"buttonBar"]];
    NSDictionary *folder = [NSDictionary dictionaryWithObject:dock forKey:@"iconLists"];
    dock = [repairFolderIconState(folder, NO, YES) objectForKey:@"iconLists"];

    // Update icon lists for the root folder
    iconState = repairFolderIconState(iconState, YES, NO);

    // Combine fixed dock and lists
    iconState = [[iconState mutableCopy] autorelease];
    [(NSMutableDictionary *)iconState setObject:[dock lastObject] forKey:@"buttonBar"];

    return iconState;
}

%hook SBIconModel

// 3.x - 5.x
- (BOOL)importState:(id)state {
    // Returning NO disables iTunes sync
    return [[ISIconSupport sharedInstance] isBeingUsedByExtensions] ? NO : %orig;
}

// 4.x - 5.x
static BOOL needsConversion_ = NO;

%group GFirmware4x5x

- (id)init {
    // If IconSupport is installed but not in use and a user upgrades to 1.7.5,
    // their old IconSupport layout file may overwrite their current icon layout
    // without warning. The below code prevents this from occurring.
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
        NSString *hash = [[ISIconSupport sharedInstance] extensionString];
        if ([hash isEqualToString:@""]) {
            // IconSupport is installed but not in use
            // NOTE: If all IconSupport-enabled extensions were uninstalled
            //       at the *same time* that IconSupport was upgraded,
            //       *do not* delete the IconSupport layout file.
            NSString *oldHash = [[NSUserDefaults standardUserDefaults] stringForKey:@"ISLastUsed"];
            if ([oldHash isEqualToString:hash]) {
                // IconSupport-enabled extensions were not just uninstalled; delete layout file
                [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/SpringBoard/IconSupportState.plist" error:NULL];
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
    NSFileManager *manager = [NSFileManager defaultManager];

    // Compare the previous and new hash
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *oldHash = [defaults stringForKey:@"ISLastUsed"];
    NSString *newHash = [[ISIconSupport sharedInstance] extensionString];
    ISLog(@"Old hash is: %@, new hash is: %@", oldHash, newHash);

    // NOTE: This should only be possible once (at respring).
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

    if (![[ISIconSupport sharedInstance] isBeingUsedByExtensions])
        return origState;

    // Extract dock, keep it identical
    NSArray *dock = [origState objectAtIndex:0];

    // Hold all icons' dict representations
    NSMutableArray *holder = [NSMutableArray array];
    NSArray *iconLists = [origState subarrayWithRange:NSMakeRange(1, [origState count]-1)];
    for (NSArray *iL in iconLists)
        for (NSDictionary *icon in iL)
            if ([icon objectForKey:@"iconLists"])
                // Flatten folders, this is to avoid issues with Infinifolders
                for (NSArray *whatTheFuckIsThisShit in [icon objectForKey:@"iconLists"])
                    for (NSDictionary *realIcon in whatTheFuckIsThisShit)
                        [holder addObject:realIcon];
            else
                [holder addObject:icon];

    // Split into pages of 16
    NSMutableArray *newState = [NSMutableArray array];
    [newState addObject:dock];
    while ([holder count] > kISiPhoneDefaultMaxIconsPerPage) {
        NSRange range = NSMakeRange(0, kISiPhoneDefaultMaxIconsPerPage);
        NSArray *page = [holder subarrayWithRange:range];
        [newState addObject:page];
        [holder removeObjectsInRange:range];
    }
    if ([holder count] > 0)
        [newState addObject:holder];
    return newState;
}

%end // GFirmware4x5x

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

// 3.x
%group GFirmware3x

- (id)iconState {
    if (![[ISIconSupport sharedInstance] isBeingUsedByExtensions]) {
        return %orig;
    }

    NSDictionary *previousIconState = MSHookIvar<NSDictionary *>(self, "_previousIconState");
    id ret = nil;

    if (previousIconState == nil) {
        NSMutableDictionary *springBoardPlist = [[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"] mutableCopy];
        id newIconState = [[springBoardPlist objectForKey:[@"iconState" stringByAppendingString:[[ISIconSupport sharedInstance] extensionString]]] mutableCopy];

        // If we has a layout saved already, go ahead and return that.
        if (newIconState) {   
            ret = [newIconState autorelease];
        } else if ([springBoardPlist objectForKey:@"ISLastUsed"]) { // We have a last used icon state, lets use it
            NSString *oldKeySuffix = [springBoardPlist objectForKey:@"ISLastUsed"];

            // Lets go on a serach for icon states...
            id oldIconState = [springBoardPlist objectForKey:[@"iconState" stringByAppendingString:oldKeySuffix]];
            if (!oldIconState) oldIconState = [springBoardPlist objectForKey:@"iconState-iconoclasm"];
            if (!oldIconState) oldIconState = [springBoardPlist objectForKey:@"iconState-fcsb"];
            if (!oldIconState) oldIconState = [springBoardPlist objectForKey:@"iconState"];

            // Oh, we found one? Great, lets set as the current one and return it.
            if (oldIconState) {
                [springBoardPlist setObject:[[ISIconSupport sharedInstance] extensionString] forKey:@"ISLastUsed"];
                // Save to the current key for next time.
                [springBoardPlist writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
                ret = [oldIconState autorelease];
            }
        }
    }

    // If ret is still nil, just get whatever SpringBoard wants
    return ret ?: %orig;
}

- (void)_writeIconState {
    if (![[ISIconSupport sharedInstance] isBeingUsedByExtensions]) {
        %orig;
        return;
    }

    // Write the icon state to disc in a separate key from SpringBoard's 4x4 default key
    NSMutableDictionary *newState = [[NSMutableDictionary alloc] init];
    [newState setObject:representation([self buttonBar]) forKey:@"buttonBar"];

    NSMutableArray *lists = [[NSMutableArray alloc] init];
    for (SBIconList *iconList in [self iconLists]) {
        [lists addObject:representation(iconList)];
    }
    [newState setObject:lists forKey:@"iconLists"];
    [lists release];

    NSMutableDictionary *springBoardPlist = [[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"] mutableCopy];
    [springBoardPlist setObject:newState forKey:[@"iconState" stringByAppendingString:[[ISIconSupport sharedInstance] extensionString]]];
    [springBoardPlist setObject:[[ISIconSupport sharedInstance] extensionString] forKey:@"ISLastUsed"];
    [newState release];

    [springBoardPlist writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
    [springBoardPlist release];
}

- (id)exportState {
    NSArray *originalState = %orig;

    if (![[ISIconSupport sharedInstance] isBeingUsedByExtensions])
        return originalState;

    // Extract the dock and keep it identical
    NSArray *dock = [originalState objectAtIndex:0];

    // Prepare an array to hold all icons' dictionary representations
    NSMutableArray *holdAllIcons = [[NSMutableArray alloc] init];
    NSArray *iconLists = [originalState subarrayWithRange:NSMakeRange(1, [originalState count] - 1)];
    for (NSArray *page in iconLists) {
        for (NSArray *row in page) {
            for (id iconDict in row) {
                if ([iconDict isKindOfClass:[NSDictionary class]])
                    [holdAllIcons addObject:iconDict];
            }
        }
    }

    int maxPerPage, rows, columns;

    if (isiPad()) {
        maxPerPage = kISiPadDefaultMaxIconsPerPage;
        rows = kISiPadDefaultRowsPerPage;
        columns = kISiPadDefaultColumnsPerPage;
    } else {
        maxPerPage = kISiPhoneDefaultMaxIconsPerPage;
        rows = kISiPhoneDefaultRowsPerPage;
        columns = kISiPhoneDefaultColumnsPerPage;
    }

    // Add the padding to the end of the array
    while (([holdAllIcons count] % maxPerPage) != 0) {
        [holdAllIcons addObject:[NSNumber numberWithInt:0]];
    }

    // Split this huge array into 4x4 pages/rows
    NSMutableArray *allPages = [[NSMutableArray alloc] init];
    [allPages addObject:dock];
    int totalPages = ceil([holdAllIcons count] / maxPerPage);

    for (int i = 0; i < totalPages; i++) {
        int firstIndex = i * maxPerPage;
        // Get an array representing all of that pages' icons
        NSArray *thisPage = [holdAllIcons subarrayWithRange:NSMakeRange(firstIndex, maxPerPage)];
        NSMutableArray *newPage = [[NSMutableArray alloc] init];

        for (int j = 0; j < rows; j++) { // Number of rows
            NSArray *thisRow = [thisPage subarrayWithRange:NSMakeRange(j*columns, columns)];
            [newPage addObject:thisRow];
        }

        [allPages addObject:newPage];
        [newPage release];
    }

    [holdAllIcons release];
    return [allPages autorelease];
}

- (void)relayout {
    %orig;

    // Fix for things like LockInfo, that need us to compact the icons lists at this point.
    [self compactIconLists];
}

%end // GFirmware3x

%end // SBIconModel

__attribute__((constructor)) static void init()
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // NOTE: This library should only be loaded for SpringBoard
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleId isEqualToString:@"com.apple.springboard"]) {
        if (isiOS3) {
            %init(GFirmware3x);
        } else {
            %init(GFirmware4x5x);

            if (isiOS4)
                %init(GFirmware4x);
            else
                %init(GFirmware5x);

            // FIXME: Find a better way to detect if subfolders are supported.
            NSFileManager *manager = [NSFileManager defaultManager];
            hasSubfolderSupport_ =
                [manager fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/FolderEnhancer.dylib"] ||
                [manager fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/FoldersInFolders.dylib"];
        }

        %init;
    }

    [pool release];
}
