#!/bin/bash

# Script to update snapshot test references
# This script will run the snapshot tests in record mode to regenerate the reference images

set -e

echo "🔄 Starting snapshot update process..."

# Function to run tests with snapshot recording
run_snapshot_tests() {
    local scheme=$1
    local destination=$2
    
    echo "📸 Recording snapshots for scheme: $scheme"
    
    # Clean first
    xcodebuild clean \
        -project EssentialFeed/EssentialFeed.xcodeproj \
        -scheme "$scheme" \
        > /dev/null 2>&1
    
    # Run tests with recording enabled
    env RECORD_SNAPSHOTS=1 xcodebuild test \
        -project EssentialFeed/EssentialFeed.xcodeproj \
        -scheme "$scheme" \
        -destination "$destination" \
        -quiet \
        || true  # Continue even if tests "fail" due to recording
}

# Configuration
DESTINATION='platform=iOS Simulator,name=iPhone 15,OS=latest'
SCHEME="EssentialFeediOS"

echo "🎯 Target: $DESTINATION"
echo "📦 Scheme: $SCHEME"

# Run the snapshot tests in recording mode
run_snapshot_tests "$SCHEME" "$DESTINATION"

echo ""
echo "✅ Snapshot recording completed!"
echo ""
echo "📋 Next steps:"
echo "   1. Check the recorded snapshots look correct"
echo "   2. Run tests normally to verify they pass: ./run_tests.sh"
echo "   3. Commit the updated snapshot images to git"
echo ""
echo "🔍 To see what snapshots were updated:"
echo "   git status"
echo "   git diff --name-only"