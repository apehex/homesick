#!/bin/bash

# List the installed packages
adb shell pm list packages -f -3

# Remove the target package
adb shell pm uninstall --user 0 bloated.app
