#!/bin/bash

# ZenBeat Release Script
# Usage: ./Scripts/release.sh <tag_name>
# Example: ./Scripts/release.sh v1.2026.4

set -e

# 0. Navigation
# Change directory to the root of the project
cd "$(dirname "$0")/.."

TAG_NAME=$1

if [ -z "$TAG_NAME" ]; then
    echo "Error: No tag name provided."
    echo "Usage: ./Scripts/release.sh <tag_name>"
    exit 1
fi

# 1. Package the app
echo "Step 1: Packaging the application..."
./Scripts/package.sh

# 2. Tag the repository
echo "Step 2: Tagging the repository with ${TAG_NAME}..."
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo "Warning: Tag ${TAG_NAME} already exists locally."
else
    git tag "$TAG_NAME"
fi

# 3. Push the tag
echo "Step 3: Pushing tag ${TAG_NAME} to origin..."
git push origin "$TAG_NAME"

# 4. Create GitHub release
echo "Step 4: Creating GitHub release and uploading DMG..."
gh release create "$TAG_NAME" ZenBeat.dmg \
    --title "Release ${TAG_NAME}" \
    --notes "Automated release for version ${TAG_NAME}"

echo "Successfully released ${TAG_NAME} to GitHub!"
