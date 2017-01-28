// Completely ripped out of Iconoclasm (by Sakurina).
// Completely ripped out of FCSB (by chpwn).

// Updated for iPad by Sakurina.

#import "ISIconSupport.h"

#include <substrate.h>

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
    if ([iconListOrDock respondsToSelector:@selector(representation)]) {
        return [iconListOrDock performSelector:@selector(representation)];
    } else if ([iconListOrDock respondsToSelector:@selector(dictionaryRepresentation)]) {
        return [iconListOrDock performSelector:@selector(dictionaryRepresentation)];
    }

    return nil;
}

%hook SBIconModel

- (BOOL)importState:(id)state {
    // Returning NO disables iTunes sync
    return [[ISIconSupport sharedInstance] isBeingUsedByExtensions] ? NO : %orig();
}

- (id)iconState {
    ISIconSupport *iconSupport = [ISIconSupport sharedInstance];
    if (![iconSupport isBeingUsedByExtensions]) {
        return %orig();
    }

    id ret = nil;

    NSDictionary *_previousIconState = MSHookIvar<NSDictionary *>(self, "_previousIconState");
    if (_previousIconState == nil) {
        NSMutableDictionary *springBoardPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"];
        NSString *extensionString = [iconSupport extensionString];
        id newIconState = [springBoardPlist objectForKey:[@"iconState" stringByAppendingString:extensionString]];
        if (newIconState) {
            // We have a layout saved already, go ahead and return that.
            // FIXME: Must it be mutable?
            ret = [[newIconState mutableCopy] autorelease];
        } else if ([springBoardPlist objectForKey:@"ISLastUsed"]) {
            // We have a last used icon state, lets use it
            NSString *oldKeySuffix = [springBoardPlist objectForKey:@"ISLastUsed"];

            // Lets go on a serach for icon states...
            id oldIconState = [springBoardPlist objectForKey:[@"iconState" stringByAppendingString:oldKeySuffix]];
            if (!oldIconState) oldIconState = [springBoardPlist objectForKey:@"iconState-iconoclasm"];
            if (!oldIconState) oldIconState = [springBoardPlist objectForKey:@"iconState-fcsb"];
            if (!oldIconState) oldIconState = [springBoardPlist objectForKey:@"iconState"];

            if (oldIconState) {
                // Oh, we found one? Great, lets set as the current one and return it.
                [springBoardPlist setObject:extensionString forKey:@"ISLastUsed"];

                // Save to the current key for next time.
                [springBoardPlist writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
                ret = oldIconState;
            }
        }
        [springBoardPlist release];
    }

    // If ret is still nil, just get whatever SpringBoard wants
    return ret ?: %orig();
}

- (void)_writeIconState {
    ISIconSupport *iconSupport = [ISIconSupport sharedInstance];
    if (![iconSupport isBeingUsedByExtensions]) {
        %orig();
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
    NSString *extensionString = [iconSupport extensionString];
    [springBoardPlist setObject:newState forKey:[@"iconState" stringByAppendingString:extensionString]];
    [newState release];

    [springBoardPlist setObject:extensionString forKey:@"ISLastUsed"];
    [springBoardPlist writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
    [springBoardPlist release];
}

- (id)exportState {
    NSArray *originalState = %orig();

    if (![[ISIconSupport sharedInstance] isBeingUsedByExtensions]) {
        return originalState;
    }

    // Extract the dock and keep it identical
    NSArray *dock = [originalState objectAtIndex:0];

    // Prepare an array to hold all icons' dictionary representations
    NSMutableArray *holdAllIcons = [[NSMutableArray alloc] init];
    NSArray *iconLists = [originalState subarrayWithRange:NSMakeRange(1, [originalState count] - 1)];
    for (NSArray *page in iconLists) {
        for (NSArray *row in page) {
            for (id iconDict in row) {
                if ([iconDict isKindOfClass:[NSDictionary class]]) {
                    [holdAllIcons addObject:iconDict];
                }
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
        [holdAllIcons addObject:@0];
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
    %orig();

    // Fix for things like LockInfo, that need us to compact the icons lists at this point.
    [self compactIconLists];
}

%end // SBIconModel

%ctor {
    @autoreleasepool {
        // NOTE: This library should only be loaded for SpringBoard
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundleId isEqualToString:@"com.apple.springboard"]) {
            // NOTE: IconSupport does not support firmware older than iOS 3.
            %init();
        }
    }
}

/* vim: set ft=logos ff=unix tw=80 sw=4 ts=4 expandtab: */
