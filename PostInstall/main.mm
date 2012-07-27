/**
 * Description: Post install script for IconSupport
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2012-07-27 19:42:29
 */

#include "PreferenceConstants.h"

int main(int argc, char *argv[]) {
    // NOTE: This conversion is only needed for iOS 4.x+, as the 3.x code for
    //       IconSupport still uses hash-postfixed plist files.
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_4_0) {
        // NOTE: This program is run as root during install; must switch the
        //       effective user to mobile (501).
        seteuid(501);

        // Create pool
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        // File path for IconSupport icon state file
        NSString *basePath = @"/var/mobile/Library/SpringBoard/";
        NSString *stateFilePath = [basePath stringByAppendingString:@"IconSupportState.plist"];

        // Rename any existing old-name-formatted icon state files
        // NOTE: Versions prior to 1.7.2 used state file names of the format
        //       "IconSupportState-*****.plist". Starting from 1.7.2, the state
        //       file is simply named "IconSupportState.plist".
        // NOTE: Do not overwrite IconSupportState.plist if it already exists.
        NSFileManager *manager = [NSFileManager defaultManager];
        if (![manager fileExistsAtPath:stateFilePath]) {
            // Get the last used IconSupport hash (if it exists)
            NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.springboard"];
            NSString *hash = [defaults objectForKey:@"ISLastUsed"];
            if ([hash length] != 0) {
                // If a state file with this hash as part of its name exists, rename it
                NSString *oldPath = [basePath stringByAppendingFormat:@"IconSupportState%@.plist", hash];
                if ([manager fileExistsAtPath:oldPath]) {
                    // Move old state file to new path
                    // NOTE: Must do in two steps: copy file to new path, then remove old file.
                    // NOTE: If IconSupporState.plist already exists (it should not), it will not be overwritten.
                    BOOL success = [manager copyItemAtPath:oldPath toPath:stateFilePath error:NULL];
                    if (success) {
                        [manager removeItemAtPath:oldPath error:NULL];
                        printf("Moved %s to %s\n", [oldPath UTF8String], [stateFilePath UTF8String]);
                    }
                }
            }
        }

        // Check whether this is an install or an upgrade
        if (argc > 1) {
            if (strcmp(argv[1], "install") == 0) {
                // This is a fresh install; note if an old state file exists
                if ([manager fileExistsAtPath:stateFilePath]) {
                    CFPreferencesSetAppValue((CFStringRef)kHasOldStateFile, [NSNumber numberWithBool:YES], CFSTR(APP_ID));
                    CFPreferencesAppSynchronize(CFSTR(APP_ID));
                }
            } else if (strcmp(argv[1], "upgrade") == 0) {
                // Mark that an upgrade has occurred
                CFPreferencesSetAppValue((CFStringRef)kFirstLoadAfterUpgrade, [NSNumber numberWithBool:YES], CFSTR(APP_ID));
                CFPreferencesAppSynchronize(CFSTR(APP_ID));
            }
        }

        // Cleanup
        [pool release];
    }

    return 0;
}

/* vim: set filetype=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
