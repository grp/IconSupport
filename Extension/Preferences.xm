%hook ResetPrefController

- (void)resetIconPositions:(id)sender {
    NSString *path = @"/var/mobile/Library/SpringBoard/IconSupportState.plist";
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    %orig;
}

%end

__attribute__((constructor)) static void init()
{
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_4_0) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        // NOTE: This library should only be loaded for Preferences.app (Settings)
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundleId isEqualToString:@"com.apple.Preferences"]) {
            %init;
        }

        [pool release];
    }
}
