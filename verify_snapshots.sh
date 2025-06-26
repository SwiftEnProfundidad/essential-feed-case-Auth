#!/bin/bash

# Script to verify that snapshot tests pass after updating

set -e

echo "🧪 Verifying snapshot tests..."

DESTINATION='platform=iOS Simulator,name=iPhone 15,OS=latest'
SCHEME="EssentialFeediOS"

echo "🎯 Running snapshot tests for: $SCHEME"

xcodebuild test \
    -project EssentialFeed/EssentialFeed.xcodeproj \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -only-testing:EssentialFeediOSTests/FeedSnapshotTests \
    -only-testing:EssentialFeediOSTests/ImageCommentsSnapshotTests \
    -only-testing:EssentialFeediOSTests/ListSnapshotTests

echo ""
echo "✅ All snapshot tests passed!"
echo "🎉 Snapshots are now consistent and up to date."