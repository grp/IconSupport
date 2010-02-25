
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 
                                    -=-=-=-= EXAMPLE USAGE =-=-=-=-
                         
 dlopen("/Library/MobileSubstrate/DynamicLibraries/IconSupport.dylib");
 [[objc_getClass("ISIconSupport") sharedInstance] addExtension:@"theNameOfMyExtension"];
 
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */



#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>
#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>

// Completely ripped out of Iconoclasm (by Sakurina).
// Completely ripped out of FCSB (by chpwn).

CHDeclareClass(SBIconModel);

@interface ISIconSupport : NSObject {
	NSMutableSet *extensions;
}

+ (id)sharedInstance;
- (NSString *)extensionString;
- (BOOL)addExtension:(NSString *)extension;

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
	NSDictionary *previousIconState= CHIvar(self, _previousIconState, NSDictionary *);
	if (previousIconState == nil) {
		NSDictionary *springBoardPlist = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"];
		id newIconState = [[springBoardPlist objectForKey:[@"iconState" stringByAppendingString:[[ISIconSupport sharedInstance] extensionString]]] mutableCopy];
		if (newIconState)   // If we has a layout saved already, go ahead and return that.
			return [newIconState autorelease];
	}
	return CHSuper0(SBIconModel, iconState);  // Otherwise, just send SpringBoard's and we'll copy it.
}

CHMethod0(void, SBIconModel, _writeIconState)
{
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
	[newState release];
	[springBoardPlist writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
	[springBoardPlist release];
}

CHMethod1(BOOL, SBIconModel, importState, id, state)
{
	return NO; //disable itunes sync
}

CHConstructor
{
	CHAutoreleasePoolForScope();
	
	// SpringBoard only!
	if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"])
		return;
	
	CHLoadLateClass(SBIconModel);
	CHHook0(SBIconModel, _writeIconState);
	CHHook0(SBIconModel, iconState);
	CHHook1(SBIconModel, importState);
}
