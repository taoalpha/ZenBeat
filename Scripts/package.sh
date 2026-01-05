#!/bin/bash

# ZenBeat DMG Packaging Script
# This script automates the creation of a DMG for ZenBeat.app

set -e

# 0. Navigation
# Change directory to the root of the project (parent of this script's directory)
cd "$(dirname "$0")/.."

APP_NAME="ZenBeat"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
ICON_SVG="app-icon.svg"
ICON_PNG="app-icon.png"

# 1. Check for required tools
if ! command -v create-dmg &> /dev/null; then
    echo "Error: create-dmg is not installed. Install it with: brew install create-dmg"
    exit 1
fi

# 2. Generate icon if needed
if [ -f "$ICON_SVG" ]; then
    if [ ! -f "$ICON_PNG" ] || [ "$ICON_SVG" -nt "$ICON_PNG" ]; then
        echo "Generating ${ICON_PNG} from ${ICON_SVG}..."
        swift generate_icon.swift "$ICON_SVG" "$ICON_PNG"
    fi
fi

# 3. Clean up previous DMG
if [ -f "$DMG_NAME" ]; then
    echo "Removing existing ${DMG_NAME}..."
    rm "$DMG_NAME"
fi

# 4. Create DMG
echo "Creating ${DMG_NAME}..."
create-dmg \
  --volname "${APP_NAME}" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "${APP_BUNDLE}" 200 190 \
  --hide-extension "${APP_BUNDLE}" \
  --app-drop-link 600 185 \
  "${DMG_NAME}" \
  "${APP_BUNDLE}"

echo "Successfully created ${DMG_NAME}"
