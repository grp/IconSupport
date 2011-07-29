/**
 * Description: Post install script for IconSupport
 * Author: Lance Fetters (aka. ashikase)
 * Last-modified: 2011-07-29 10:35:49
 */


#define kCFCoreFoundationVersionNumber_iPhoneOS_4_0 550.32
#define isiOS4 (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iPhoneOS_4_0)

int main(int argc, char *argv[], char *envp[])
{
    // NOTE: This conversion is only needed for iOS 4.x.
    if (isiOS4) {
        // NOTE: This program is run as root during install; must switch the
        //       effective user to mobile (501).
        seteuid(501);

        // Create pool
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        // Get preferences for SpringBoard
        NSDictionary *defaults = [[NSUserDefaults standardUserDefaults]
            persistentDomainForName:@"com.apple.springboard"];

        // Get the last used IconSupport hash (if it exists)
        NSString *hash = [defaults objectForKey:@"ISLastUsed"];
        if ([hash length] != 0) {
            // If a state file with this hash as part of its name exists, rename it
            NSString *basePath = @"/var/mobile/Library/SpringBoard/";
            NSString *oldPath = [basePath stringByAppendingFormat:@"IconSupportState%@.plist", hash];;

            NSFileManager *manager = [NSFileManager defaultManager];
            if ([manager fileExistsAtPath:oldPath]) {
                // Move old state file to new path
                // NOTE: Must do in two steps: copy file to new path, then remove old file.
                // NOTE: If IconSupporState.plist already exists (it should not), it will not be overwritten.
                NSString *newPath = [basePath stringByAppendingString:@"IconSupportState.plist"];
                BOOL success = [manager copyItemAtPath:oldPath toPath:newPath error:NULL];
                if (success) {
                    [manager removeItemAtPath:oldPath error:NULL];
                    printf("Moved %s to %s\n", [oldPath UTF8String], [newPath UTF8String]);
                }

            }
        }

        // Cleanup
        [pool release];
    }

    return 0;
}

/* vim: set filetype=objc sw=4 ts=4 sts=4 expandtab textwidth=80 ff=unix: */
