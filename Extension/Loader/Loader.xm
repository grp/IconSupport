#include <dlfcn.h>

%ctor {
    @autoreleasepool {
        const char *path = NULL;
        if (IOS_LT(4_0)) {
            path = "/Library/Application Support/IconSupport/Versions/3.0/libIconSupport.dylib";
        } else {
            path = "/Library/Application Support/IconSupport/Versions/4.0/libIconSupport.dylib";
        }
        dlopen(path, RTLD_LAZY | RTLD_GLOBAL);
    }
}

/* vim: set ft=logos ff=unix sw=4 ts=4 tw=80 expandtab: */
