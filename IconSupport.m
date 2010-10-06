/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 
                                    -=-=-=-= EXAMPLE USAGE =-=-=-=-
                         
 dlopen("/Library/MobileSubstrate/DynamicLibraries/IconSupport.dylib", RTLD_NOW);
 [[objc_getClass("ISIconSupport") sharedInstance] addExtension:@"infiniboard"];
 
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */



#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>
#import "Headers/CaptainHook.h"

// Horrible horrible way of going about doing it but it works /for now/
#define isiPad() ([UIDevice instancesRespondToSelector:@selector(isWildcat)] && [[UIDevice currentDevice] isWildcat])
#define kISiPhoneDefaultMaxIconsPerPage 16
#define kISiPhoneDefaultColumnsPerPage 4
#define kISiPhoneDefaultRowsPerPage 4
#define kISiPadDefaultMaxIconsPerPage 20
#define kISiPadDefaultColumnsPerPage 4
#define kISiPadDefaultRowsPerPage 5
#define kCFCoreFoundationVersionNumber_iPhoneOS_4_0 550.32
#define isiOS4 (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iPhoneOS_4_0)


// Completely ripped out of Iconoclasm (by Sakurina).
// Completely ripped out of FCSB (by chpwn).

// Updated for iPad by Sakurina.
// Updated for iOS4 by Sakurina and chpwn.


CHDeclareClass(SBIconList);
CHDeclareClass(SBIconListView);
CHDeclareClass(SBIconModel);

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

CHConstructor {
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


static id representation(id iconListOrDock) {
	// Returns a dictionary representation of an icon list or dock,
	// as it varies depending on the OS version installed.
	if ([iconListOrDock respondsToSelector:@selector(representation)])
		return [iconListOrDock performSelector:@selector(representation)];
	else if ([iconListOrDock respondsToSelector:@selector(dictionaryRepresentation)])
		return [iconListOrDock performSelector:@selector(dictionaryRepresentation)];

	return nil;
}

static NSDictionary * fixupFolderState(NSDictionary *folderState, BOOL isRootFolder, BOOL isDock)
{
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
            id icon = [oldList objectAtIndex:i];
            if ([icon isKindOfClass:$NSDictionary]) {
                // Fixup the folder; use result to replace old folder
                NSDictionary *newIcon = fixupFolderState(icon, NO, NO);
                [oldList replaceObjectAtIndex:i withObject:newIcon];
            }
        }

        // If list is too large (icons > maxIcons), split into smaller lists
        while (iconCount > maxIcons) {
            // NOTE: Must make sure list limit has not been reached.
            if (newListCount >= maxLists)
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
            if (newListCount < maxLists) {
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
            if (iconCount < maxIcons) {
                // This list has room for more icons
                int length = maxIcons - iconCount;
                if (length > orphanCount)
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

    // Store the updated icon lists
    [newState setObject:newIconLists forKey:@"iconLists"];

    return newState;
}

static BOOL needsConversion_ = NO;

// 4.x
CHMethod0(id, SBIconModel, _iconState) {
	NSDictionary *modernIconState = CHSuper0(SBIconModel, _iconState);

    // If necessary, fix icon state to make sure there are no lost icons
    if (needsConversion_) {
        // Fix dock
        // NOTE: Wrap the array in a fake folder in order to pass to fixup function.
        // XXX: This code assumes that the dock never has more than one icon list.
        NSArray *dockLists = [NSArray arrayWithObject:[modernIconState objectForKey:@"buttonBar"]];
        NSDictionary *dockFolder = [NSDictionary dictionaryWithObject:dockLists forKey:@"iconLists"];
        dockFolder = fixupFolderState(dockFolder, NO, YES);
        dockLists = [dockFolder objectForKey:@"iconLists"];

        // Fix icon lists
        modernIconState = fixupFolderState(modernIconState, YES, NO);
        needsConversion_ = NO;

        // Combine fixed dock and lists
        modernIconState = [[modernIconState mutableCopy] autorelease];
        [modernIconState setObject:[dockLists lastObject] forKey:@"buttonBar"];

        ISLog(@"Converted icon state for new combination of extensions.");
    }

    return modernIconState;
}

CHMethod0(id, SBIconModel, iconStatePath) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSFileManager *manager = [NSFileManager defaultManager];

    // Compare the previous and new hash
    NSString *oldHash = [defaults stringForKey:@"ISLastUsed"];
    NSString *newHash = [[ISIconSupport sharedInstance] extensionString];
    ISLog(@"Old hash is: %@, new hash is: %@", oldHash, newHash);

    if (![newHash isEqualToString:oldHash])
        // NOTE: This should only be possible once (at respring).
        needsConversion_ = YES;

    NSString *basePath = @"/var/mobile/Library/SpringBoard/";
    NSString *defPath = [basePath stringByAppendingString:@"IconState.plist"];
    NSString *oldPath = ([oldHash length] == 0) ? defPath : 
        [basePath stringByAppendingFormat:@"IconSupportState%@.plist", oldHash];;

    NSString *newPath = nil;
    if (needsConversion_) {
        // Determine path for new state file
        // NOTE: The new file may already exist, due to methods used in older
        //       versions of IconSupport; delete it.
        newPath = ([newHash length] == 0) ? defPath : 
            [basePath stringByAppendingFormat:@"IconSupportState%@.plist", newHash];
        [manager removeItemAtPath:newPath error:NULL];

        // Copy old state file to new path
        BOOL success = [manager copyItemAtPath:oldPath toPath:newPath error:NULL];
        if (success) {
            // Remove old file so that it does not get reused in the future
            [manager removeItemAtPath:oldPath error:NULL];
            ISLog(@"Moved old icon state to new path %@.", newPath);
        }

        // Save current key for next time
        [defaults setObject:newHash forKey:@"ISLastUsed"];
        ISLog(@"Saved current hash (%@) to ISLastUsed key.", newHash);
    } else {
        // Hash has not changed; use old path
        newPath = oldPath;
    }

    if (![manager fileExistsAtPath:newPath]) {
        // IconSupport state file does not exist; use default (Safe Mode) file
        [manager copyItemAtPath:defPath toPath:newPath error:NULL];
        ISLog(@"IconSupport state file does not exist; using default.");
    }

    return newPath;	
}

CHMethod1(id, SBIconModel, exportState, BOOL, withFolders) {
	if (![[ISIconSupport sharedInstance] isBeingUsedByExtensions])
		return CHSuper1(SBIconModel, exportState, withFolders);
  NSArray* origState = CHSuper1(SBIconModel, exportState, withFolders);

  // Extract dock, keep it identical
  NSArray* dock = [origState objectAtIndex:0];

  // Hold all icons' dict representations
  NSMutableArray* holder = [NSMutableArray array];
  NSArray* iconLists = [origState subarrayWithRange:NSMakeRange(1, [origState count]-1)];
  for (NSArray* iL in iconLists)
    for (NSDictionary* icon in iL)
      if ([icon objectForKey:@"iconLists"])
        // Flatten folders, this is to avoid issues with Infinifolders
        for (NSArray* whatTheFuckIsThisShit in [icon objectForKey:@"iconLists"])
          for (NSDictionary* realIcon in whatTheFuckIsThisShit)
            [holder addObject:realIcon];
      else
        [holder addObject:icon];

  // Split into pages of 16
  NSMutableArray* newState = [NSMutableArray array];
  [newState addObject:dock];
  while ([holder count] > kISiPhoneDefaultMaxIconsPerPage) {
    NSRange range = NSMakeRange(0, kISiPhoneDefaultMaxIconsPerPage);
    NSArray* page = [holder subarrayWithRange:range];
    [newState addObject:page];
    [holder removeObjectsInRange:range];
  }
  if ([holder count] > 0)
    [newState addObject:holder];
  return newState;
}


// 3.x
CHMethod0(id, SBIconModel, iconState) 
{
	if (![[ISIconSupport sharedInstance] isBeingUsedByExtensions]) {
		return CHSuper0(SBIconModel, iconState);
	}
	
	NSDictionary *previousIconState = CHIvar(self, _previousIconState, NSDictionary *);
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
	ret = ret ?: CHSuper0(SBIconModel, iconState);

	return ret;
}

CHMethod0(void, SBIconModel, _writeIconState)
{
	if (![[ISIconSupport sharedInstance] isBeingUsedByExtensions]) {
		CHSuper0(SBIconModel, _writeIconState);
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

CHMethod1(BOOL, SBIconModel, importState, id, state)
{
	if ([[ISIconSupport sharedInstance] isBeingUsedByExtensions])
		return NO; //disable itunes sync
	else
		return CHSuper1(SBIconModel, importState, state);
}

CHMethod0(id, SBIconModel, exportState)
{
	if (![[ISIconSupport sharedInstance] isBeingUsedByExtensions])
		return CHSuper0(SBIconModel, exportState);
 
	NSArray* originalState = CHSuper0(SBIconModel, exportState);

	// Extract the dock and keep it identical
	NSArray* dock = [originalState objectAtIndex:0];

	// Prepare an array to hold all icons' dictionary representations
	NSMutableArray* holdAllIcons = [[NSMutableArray alloc] init];
	NSArray* iconLists = [originalState subarrayWithRange:NSMakeRange(1, [originalState count] - 1)];
	for (NSArray* page in iconLists) {
		for (NSArray* row in page) {
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
	NSMutableArray* allPages = [[NSMutableArray alloc] init];
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

CHMethod0(void, SBIconModel, relayout)
{
	CHSuper0(SBIconModel, relayout);
	
	// Fix for things like LockInfo, that need us to compact the icons lists at this point.
	[CHSharedInstance(SBIconModel) compactIconLists];
}

CHConstructor
{
	CHAutoreleasePoolForScope();
	
	// SpringBoard only!
	if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"])
		return;
	
	CHLoadLateClass(SBIconModel);
	CHLoadLateClass(SBIconList);
	CHLoadLateClass(SBIconListView);

	if (isiOS4) {
		CHHook0(SBIconModel, _iconState);
		CHHook1(SBIconModel, exportState);
		CHHook0(SBIconModel, iconStatePath);
	} else {
		CHHook0(SBIconModel, _writeIconState);
		CHHook0(SBIconModel, iconState);
		CHHook0(SBIconModel, exportState);
		CHHook0(SBIconModel, relayout);
	}

	CHHook1(SBIconModel, importState);
}
