// Completely ripped out of Iconoclasm (by Sakurina).
// Completely ripped out of FCSB (by chpwn).

// Updated for iPad by Sakurina.
// Updated for iOS4 by Sakurina and chpwn.

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

   -=-=-=-= EXAMPLE USAGE =-=-=-=-

   dlopen("/Library/MobileSubstrate/DynamicLibraries/IconSupport.dylib", RTLD_NOW);
   [[objc_getClass("ISIconSupport") sharedInstance] addExtension:@"infiniboard"];

 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */


#include <substrate.h>

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

// iOS 3.x
@class SBButtonBar;
@interface SBIconModel : NSObject
@property(readonly, retain) NSMutableArray *iconLists;
@property(readonly, retain) SBButtonBar *buttonBar;
- (void)compactIconLists;
@end

// iOS 4.x
@interface UIDevice (UIDevicePrivate)
- (BOOL)isWildcat;
@end

@interface SBFolder : NSObject
+ (int)maxListCount;
- (Class)listModelClass;
@end

@interface SBIconList : NSObject @end

@interface SBIconListModel : NSObject
+ (int)maxIcons;
@end
@interface SBDockIconListModel : SBIconListModel @end

@class SBFolder;
@class SBFolderIcon;

@interface ISIconSupport : NSObject {
    NSMutableSet *extensions;
}

+ (id)sharedInstance;
- (NSString *)extensionString;
- (BOOL)addExtension:(NSString *)extension;
- (BOOL)isBeingUsedByExtensions;

@end

#ifdef DEBUG
#define ISLog NSLog
#else
#define ISLog(...) 
#endif


static ISIconSupport *sharedSupport;

__attribute__((constructor)) static void initISIconSupport() {
    sharedSupport = [[ISIconSupport alloc] init];
}

@implementation ISIconSupport

+ (id)sharedInstance {
    return sharedSupport;
}

- (id)init {
    if ((self = [super init])) {
        extensions = [[NSMutableSet alloc] init];
    }

    return self;
}

- (NSString *)extensionString {
    if ([extensions count] == 0)
        return @"";

    // Ensure it is unique for a certain set of extensions
    int result = 0;
    for (NSString *extension in extensions) {
        result |= [extension hash];
    }

    return [@"-" stringByAppendingFormat:@"%x", result];
}

- (BOOL)addExtension:(NSString *)extension {
    if (!extension || [extensions containsObject:extension])
        return NO;

    [extensions addObject:extension];
    return YES;
}

- (BOOL)isBeingUsedByExtensions {
    return ![[self extensionString] isEqualToString:@""];
}

@end


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

static NSDictionary * fixupFolderState(NSDictionary *folderState, BOOL isRootFolder, BOOL isDock) {
    // NOTE: Copy the original state to include display name, dock (if root folder).
    NSMutableDictionary *newState = [NSMutableDictionary dictionaryWithDictionary:folderState];

    // Determine limits
    // NOTE: Must create an instance of the given folder to determine the list model class.
    int maxLists, maxIcons;
    if (isDock) {
        maxLists = 1;
        maxIcons = [objc_getClass("SBDockIconListModel") maxIcons];
    } else {
        Class $FolderClass = isRootFolder ? objc_getClass("SBRootFolder") : objc_getClass("SBFolder");
        SBFolder *folder = [[$FolderClass alloc] init];
        maxLists = [$FolderClass maxListCount];
        maxIcons = [[folder listModelClass] maxIcons];
        [folder release];
    }

    // Process icon lists
    NSMutableArray *newIconLists = [NSMutableArray array];

    // Number of lists may exceed maxLists; gather orphaned icons for later redistribution.
    NSMutableArray *orphanedIcons = [NSMutableArray array];

    NSArray *iconLists = [newState objectForKey:@"iconLists"];
    unsigned int newListCount = 0;
    for (NSArray *list in iconLists) {
        // Make a mutable copy of the list for modification
        NSMutableArray *oldList = [list mutableCopy];

        // First, check if this list contains any folders; if so, recurse
        Class $NSDictionary = [NSDictionary class];
        unsigned int iconCount = [oldList count];
        for (unsigned int i = 0; i < iconCount; i++) {
            id item = [oldList objectAtIndex:i];
            if ([item isKindOfClass:$NSDictionary]) {
                // Make sure this is a normal folder
                // NOTE: iOS 5.x has special folders. such as the book shelf
                // FIXME: Is it actually necessary to skip these folders?
                NSString *listType = [item objectForKey:@"listType"];
                if (listType != nil && ![listType isEqualToString:@"folder"])
                    // Not a normal folder
                    continue;

                // Fixup the folder
                NSDictionary *newItem = fixupFolderState(item, NO, NO);

                // Remove the old folder
                [oldList removeObjectAtIndex:i];

                if (isRootFolder || hasSubfolderSupport_) {
                    // Insert fixed-up folder in place of old folder
                    [oldList insertObject:newItem atIndex:i];
                } else {
                    // Subfolders not supported; orphan the icons for redistribution
                    for (NSArray *subList in [newItem objectForKey:@"iconLists"]) {
                        [orphanedIcons addObjectsFromArray:subList];
                    }

                    // As we did not replace the removed folder, must decrement icon count and counter
                    iconCount--;
                    i--;
                }
            }
        }

        // If list is too large (icons > maxIcons), split into smaller lists
        while ((int)iconCount > maxIcons) {
            // NOTE: Must make sure list limit has not been reached.
            if ((int)newListCount >= maxLists)
                break;

            // Create a new icon list containing the allowed number of icons
            // NOTE: Make new list mutable so icons can be added later (if necessary).
            NSRange range = NSMakeRange(0, maxIcons);
            NSArray *newList = [[oldList subarrayWithRange:range] mutableCopy];
            [newIconLists addObject:newList];
            [newList release];
            newListCount++;

            // Remove from old list the icons used in new list
            [oldList removeObjectsInRange:range];
            iconCount -= maxIcons;
        }

        if (iconCount > 0) {
            // Leftover icons exist
            if ((int)newListCount < maxLists) {
                // List limit not reached; add leftovers as final list
                [newIconLists addObject:oldList];
                newListCount++;
            } else {
                // List limit reached; add leftovers to orphaned list
                [orphanedIcons addObjectsFromArray:oldList];
            }
        }

        [oldList release];
    }

    // Redistribute orphaned icons
    unsigned int orphanCount = [orphanedIcons count];
    if (orphanCount > 0) {
        // Iterate backwards through lists, adding icons as space permits
        for (NSMutableArray *list in [newIconLists reverseObjectEnumerator]) {
            unsigned int iconCount = [list count];
            if ((int)iconCount < maxIcons) {
                // This list has room for more icons
                int length = maxIcons - iconCount;
                if (length > (int)orphanCount)
                    length = orphanCount;
                NSRange range = NSMakeRange(0, length);
                [list addObjectsFromArray:[orphanedIcons subarrayWithRange:range]];

                // Remove now no-longer-orphaned icons from orphan list
                [orphanedIcons removeObjectsInRange:range];
                orphanCount -= range.length;
            }

            if (orphanCount == 0)
                // No more orphans
                break;
        }
    }

    // If icon lists array is empty, add a single empty list
    // NOTE: This can happen for the dock when it contains no icons.
    // XXX: Can this happen for anything *besides* the dock?
    if ([newIconLists count] == 0) {
        [newIconLists addObject:[NSArray array]];
    }

    // Store the updated icon lists
    [newState setObject:newIconLists forKey:@"iconLists"];

    return newState;
}

static BOOL needsConversion_ = NO;

static NSDictionary * fixupIconState(NSDictionary *iconState) {
    // If necessary, fix icon state to make sure there are no lost icons
    if (needsConversion_) {
        // Fix dock
        // NOTE: Wrap the array in a fake folder in order to pass to fixup function.
        // XXX: This code assumes that the dock never has more than one icon list.
        NSArray *dock = [NSArray arrayWithObject:[iconState objectForKey:@"buttonBar"]];
        NSDictionary *folder = [NSDictionary dictionaryWithObject:dock forKey:@"iconLists"];
        dock = [fixupFolderState(folder, NO, YES) objectForKey:@"iconLists"];

        // Fix icon lists
        iconState = fixupFolderState(iconState, YES, NO);
        needsConversion_ = NO;

        // Combine fixed dock and lists
        iconState = [[iconState mutableCopy] autorelease];
        [(NSMutableDictionary *)iconState setObject:[dock lastObject] forKey:@"buttonBar"];

        ISLog(@"Converted icon state for new combination of extensions.");
    }

    return iconState;
}

%hook SBIconModel

// 3.x - 5.x
- (BOOL)importState:(id)state {
    // Returning NO disables iTunes sync
    return [[ISIconSupport sharedInstance] isBeingUsedByExtensions] ? NO : %orig;
}

// 4.x - 5.x
%group GFirmware4x5x

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
    return @"/var/mobile/Library/SpringBoard/DesiredIconSupportState.plist";
}

- (id)_iconState:(BOOL)ignoreDesiredIconStateFile {
    return fixupIconState(%orig);
}

%end // GFirmware5x

// 4.x
%group GFirmware4x

- (id)_iconState {
    return fixupIconState(%orig);
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
