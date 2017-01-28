#!/bin/sh

# NOTE: Must launch simulator instance manually before running this script.
# NOTE: Simulator log locations:
#       * Xcode 3.1:: /var/log/system.log 
#       * Xcode 5:    ~/Library/Logs/iOS Simulator/<sim-version>/system.log
#       * Xcode 6+:   ~/Library/Logs/CoreSimulator/<UUID>/system.log

# Exit on error.
set -e

# Determine name of dylib.
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path_to_dylib>"
    exit 1
fi
dylib_path=$1

# Clean and compile.
make -f Makefile.simulator clean all

# Inject into simulator and relaunch.
xcrun simctl spawn booted launchctl debug system/com.apple.SpringBoard --environment DYLD_INSERT_LIBRARIES=${dylib_path}
xcrun simctl spawn booted launchctl stop com.apple.SpringBoard
