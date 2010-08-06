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
CHDeclareClass(SBIconModel);
CHDeclareClass(SBUIController);

@interface ISIconSupport : NSObject {
	NSMutableSet *extensions;
}

+ (id)sharedInstance;
- (NSString *)extensionString;
- (BOOL)addExtension:(NSString *)extension;
- (BOOL)isBeingUsedByExtensions;

@end

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

// 4.x
CHMethod0(id, SBIconModel, _iconState) {
	if (![[ISIconSupport sharedInstance] isBeingUsedByExtensions])
		return CHSuper0(SBIconModel, _iconState);

	NSString *curIconStatePath = [@"/var/mobile/Library/SpringBoard/IconSupportState" stringByAppendingFormat:@"%@.plist", [[ISIconSupport sharedInstance] extensionString]];

	NSString *oldIconStatePath, *oldKeySuffix = [[NSUserDefaults standardUserDefaults] stringForKey:@"ISLastUsed"];
	if (oldKeySuffix == nil) {
		oldIconStatePath = [@"~/Library/SpringBoard/IconState.plist" stringByExpandingTildeInPath]; // Yes, this is how Apple does it.
	} else {
		oldIconStatePath = [@"/var/mobile/Library/SpringBoard/IconSupportState" stringByAppendingFormat:@"%@.plist", oldKeySuffix];
	}

	NSDictionary *iconState = nil;
	if (iconState == nil) iconState = [NSDictionary dictionaryWithContentsOfFile:curIconStatePath];			// Try the current state.
	if (iconState == nil) iconState = [NSDictionary dictionaryWithContentsOfFile:oldIconStatePath];			// Try the old state.
	if (iconState == nil) iconState = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"iconState2"];	// Legacy support.
	if (iconState == nil) iconState = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"iconState"];	// More legacy support.
	if (iconState == nil) iconState = [[objc_getClass("SBPlatformController") sharedInstance] iconState];		// Nothing at all!?
	if (iconState == nil) [self fuck]; /* I'm not bothering with your lame exception shit, SpringBoard. */		// FUCK!
			
	// Save current key for next time.
	[[NSUserDefaults standardUserDefaults] setObject:[[ISIconSupport sharedInstance] extensionString] forKey:@"ISLastUsed"];
	
	// Modernize icon state, in case it's in a legacy format...
	NSDictionary *modernIconState = [CHClass(SBIconModel) modernIconStateForState:iconState];

	return modernIconState;
}

CHMethod0(void, SBUIController, finishLaunching) {
	CHSuper0(SBUIController, finishLaunching);

	[CHSharedInstance(SBIconModel) _writeIconState];
}

CHMethod0(id, SBIconModel, iconStatePath) {
	if (![[ISIconSupport sharedInstance] isBeingUsedByExtensions])
		return CHSuper0(SBIconModel, iconStatePath);
	
	// Save current key for next time.
	[[NSUserDefaults standardUserDefaults] setObject:[[ISIconSupport sharedInstance] extensionString] forKey:@"ISLastUsed"];

	// This is for sure an IconSupport state: this is only used for writing, so it doesn't matter if it exists or not.
	return [@"/var/mobile/Library/SpringBoard/IconSupportState" stringByAppendingFormat:@"%@.plist", [[ISIconSupport sharedInstance] extensionString]];	
}

CHMethod1(id, SBIconModel, exportState, BOOL, withFolders) {
	return CHSuper1(SBIconModel, exportState, NO);
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
	NSArray* iconLists = [originalState subarrayWithRange:NSMakeRange(1,[originalState count]-1)];
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
	CHLoadLateClass(SBUIController);

	if (isiOS4) {
		CHHook0(SBIconModel, _iconState);
		CHHook1(SBIconModel, exportState);
		CHHook0(SBIconModel, iconStatePath);
		CHHook0(SBUIController, finishLaunching);
	} else {
		CHHook0(SBIconModel, _writeIconState);
		CHHook0(SBIconModel, iconState);
		CHHook0(SBIconModel, exportState);
		CHHook0(SBIconModel, relayout);
	}

	CHHook1(SBIconModel, importState);
}
