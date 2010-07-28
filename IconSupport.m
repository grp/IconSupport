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
// 4.0 is going to need a complete rewrite anyways, so this is good enough.
#define isiPad() [UIDevice instancesRespondToSelector:@selector(isWildcat)]
#define kISiPhoneDefaultMaxIconsPerPage 16
#define kISiPhoneDefaultColumnsPerPage 4
#define kISiPhoneDefaultRowsPerPage 4
#define kISiPadDefaultMaxIconsPerPage 20
#define kISiPadDefaultColumnsPerPage 4
#define kISiPadDefaultRowsPerPage 5
#define kCFCoreFoundationVersionNumber_iPhoneOS_4_0 550.32
#define isiOS4 kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iPhoneOS_4_0

// Completely ripped out of Iconoclasm (by Sakurina).
// Completely ripped out of FCSB (by chpwn).

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

+ (id)sharedInstance
{
	return sharedSupport;
}

- (id)init
{
	if ((self = [super init])) {
		extensions = [[NSMutableSet alloc] init];
	}
	
	return self;
}

- (NSString *)extensionString
{
	if ([extensions count] == 0)
		return @"";
	
	// Ensure it is unique for a certain set of extensions
	int result = 0;
	for (NSString *extension in extensions) {
		result |= [extension hash];
	}
	
	return [@"-" stringByAppendingFormat:@"%x", result];
}

- (BOOL)addExtension:(NSString *)extension
{
	if (!extension || [extensions containsObject:extension])
		return NO;
	
	[extensions	addObject:extension];
	return YES;
}

- (BOOL)isBeingUsedByExtensions {
	return ![[self extensionString] isEqualToString:@""];
}

@end


static id representation(id iconListOrDock) 
{
	// Returns a dictionary representation of an icon list or dock,
	// as it varies depending on the OS version installed.
	if ([iconListOrDock respondsToSelector:@selector(representation)])
		return [iconListOrDock performSelector:@selector(representation)];
	else if ([iconListOrDock respondsToSelector:@selector(dictionaryRepresentation)])
		return [iconListOrDock performSelector:@selector(dictionaryRepresentation)];
	return nil;
}

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
				[springBoardPlist setObject:oldIconState forKey:[@"iconState" stringByAppendingString:[[ISIconSupport sharedInstance] extensionString]]];
				[springBoardPlist writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES]; // Write it out to the plist
				[springBoardPlist setObject:[[ISIconSupport sharedInstance] extensionString] forKey:@"ISLastUsed"];
					   
				ret = [oldIconState autorelease];
			}
		}
	}
	
	if (ret == nil) {
		// Otherwise, just send SpringBoard's and we'll copy it.
		ret = CHSuper0(SBIconModel, iconState);
	}
	
	return ret;
}

CHMethod0(void, SBIconModel, _writeIconState)
{
	if (![[ISIconSupport sharedInstance] isBeingUsedByExtensions]) {
		CHSuper0(SBIconModel, _writeIconState);
		return;
	}
	// Write the icon state to disc in a separate key from SpringBoard's 4x4 default key
	NSMutableDictionary* newState = [[NSMutableDictionary alloc] init];
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
	for (int i=0; i < totalPages; i++) {
		int firstIndex = i * maxPerPage;
		// Get an array representing all of that pages' icons
		NSArray* thisPage = [holdAllIcons subarrayWithRange:NSMakeRange(firstIndex, maxPerPage)];
		NSMutableArray* newPage = [[NSMutableArray alloc] init];
		for (int j=0; j < rows; j++) { // Number of rows
			NSArray* thisRow = [thisPage subarrayWithRange:NSMakeRange(j*columns, columns)];
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

CHMethod0(id, SBIconModel, iconStatePath) {
  if ([[ISIconSupport sharedInstance] isBeingUsedByExtensions])
    return [@"/var/mobile/Library/SpringBoard/IconSupportState" stringByAppendingFormat:@"%@.plist", [[ISIconSupport sharedInstance] extensionString]];
  return CHSuper0(SBIconModel, iconStatePath);
}

CHMethod1(id, SBIconModel, exportState, BOOL, withFolders) {
  return CHSuper1(SBIconModel, exportState, NO);
}

CHConstructor
{
	CHAutoreleasePoolForScope();
	
	// SpringBoard only!
	if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"])
		return;
	
	CHLoadLateClass(SBIconModel);
  if (isiOS4) {
    CHHook0(SBIconModel, iconStatePath);
    CHHook1(SBIconModel, exportState);
  } else {
	  CHHook0(SBIconModel, _writeIconState);
	  CHHook0(SBIconModel, iconState);
	  CHHook0(SBIconModel, exportState);
	  CHHook0(SBIconModel, relayout);
  }
	CHHook1(SBIconModel, importState);
}
