// Completely ripped out of Iconoclasm (by Sakurina).
// Completely ripped out of FCSB (by chpwn).

// Updated for iPad by Sakurina.

#import "ISIconSupport.h"

// Horrible horrible way of going about doing it but it works /for now/
#define isiPad() ([UIDevice instancesRespondToSelector:@selector(isWildcat)] && [[UIDevice currentDevice] isWildcat])

#define kISiPhoneDefaultMaxIconsPerPage 16
#define kISiPhoneDefaultColumnsPerPage 4
#define kISiPhoneDefaultRowsPerPage 4

#define kISiPadDefaultMaxIconsPerPage 20
#define kISiPadDefaultColumnsPerPage 4
#define kISiPadDefaultRowsPerPage 5

static id representation(id iconListOrDock) {
    // Returns a dictionary representation of an icon list or dock,
    // as it varies depending on the OS version installed.
    if ([iconListOrDock respondsToSelector:@selector(representation)])
        return [iconListOrDock performSelector:@selector(representation)];
    else if ([iconListOrDock respondsToSelector:@selector(dictionaryRepresentation)])
        return [iconListOrDock performSelector:@selector(dictionaryRepresentation)];

    return nil;
}

%hook SBIconModel

- (BOOL)importState:(id)state {
    // Returning NO disables iTunes sync
    return [[ISIconSupport sharedInstance] isBeingUsedByExtensions] ? NO : %orig;
}

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

%end // SBIconModel

__attribute__((constructor)) static void init()
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // NOTE: This library should only be loaded for SpringBoard
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleId isEqualToString:@"com.apple.springboard"]) {
        if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_4_0) {
            // Firmware is iOS 3 or older
            // NOTE: IconSupport does not support firmware older than iOS 3.
            %init;
        }
    }

    [pool release];
}
