#!/bin/bash

# Navigate to the directory containing Info.plist if needed
# Xcode runs this from project root, so ZenBeat/Info.plist logic applies if that's where it is.
# Check TARGET_BUILD_DIR for built plist or PROJECT_DIR for source.

# Get current date components
YEAR=$(date +%Y)
DAY_OF_YEAR=$(date +%j | sed 's/^0*//') # Strip leading zeros

# Format: 1.YYYY.DayOfYear
NEW_VERSION="1.$YEAR.$DAY_OF_YEAR"

# Minutes since epoch (Build Number)
# Epoch is Jan 1 1970.
BUILD_NUMBER=$(( $(date +%s) / 60 ))

echo "Marketing Version: $NEW_VERSION"
echo "Build Number: $BUILD_NUMBER"

# Path to the source Info.plist (Updates the project file)
if [ -z "$PROJECT_DIR" ]; then
    echo "Error: PROJECT_DIR is not set."
    exit 1
else
    # Xcode Build Environment
    PLIST_PATH="${PROJECT_DIR}/ZenBeat/Info.plist"
fi

if [ -f "$PLIST_PATH" ]; then
    # Function to set or add key
    set_plist_key() {
        local key="$1"
        local value="$2"
        local path="$3"
        
        # Try to Set
        /usr/libexec/PlistBuddy -c "Set :$key $value" "$path" 2>/dev/null
        if [ $? -ne 0 ]; then
            # If Set failed (likely doesn't exist), try Add
            /usr/libexec/PlistBuddy -c "Add :$key string $value" "$path"
        fi
    }

    # Post-build update: Also update the processed Info.plist in the app bundle if it exists
    # This is critical because Xcode overlays build settings onto the plist during build
    if [ -n "$TARGET_BUILD_DIR" ] && [ -n "$INFOPLIST_PATH" ]; then
        BUILT_PLIST="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
        if [ -f "$BUILT_PLIST" ]; then
            set_plist_key "CFBundleShortVersionString" "$NEW_VERSION" "$BUILT_PLIST"
            set_plist_key "CFBundleVersion" "$BUILD_NUMBER" "$BUILT_PLIST"
            echo "Updated BUILT Info.plist at $BUILT_PLIST"
        fi
    fi
else
    echo "Error: Info.plist not found at $PLIST_PATH"
    exit 1
fi
