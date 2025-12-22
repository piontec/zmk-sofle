#!/bin/bash
# Script to fix linker errors in ZMK PR 2752 by creating a fork and patching it
# Run this script to automate the fork and patch process

set -e

GITHUB_USER="${GITHUB_USER:-}"
ZMK_FORK_REPO="${ZMK_FORK_REPO:-}"

if [ -z "$GITHUB_USER" ] && [ -z "$ZMK_FORK_REPO" ]; then
    echo "Usage: GITHUB_USER=yourusername ./patches/fix-linker-errors.sh"
    echo "   OR: ZMK_FORK_REPO=https://github.com/yourusername/zmk ./patches/fix-linker-errors.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCHES_DIR="$SCRIPT_DIR"

echo "=== Fixing ZMK PR 2752 Linker Errors ==="
echo ""

# Step 1: Determine fork URL
if [ -n "$ZMK_FORK_REPO" ]; then
    FORK_URL="$ZMK_FORK_REPO"
else
    FORK_URL="https://github.com/$GITHUB_USER/zmk"
fi

echo "Using fork: $FORK_URL"
echo ""

# Step 2: Clone or update the fork
WORK_DIR="/tmp/zmk-fix-$$"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

if [ -d "zmk" ]; then
    echo "Updating existing zmk repository..."
    cd zmk
    git fetch origin
else
    echo "Cloning ZMK fork..."
    git clone "$FORK_URL" zmk
    cd zmk
fi

# Step 3: Create/checkout the patched branch
BRANCH_NAME="pr2752-patched"
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    echo "Branch $BRANCH_NAME exists, checking out..."
    git checkout "$BRANCH_NAME"
    git pull origin "$BRANCH_NAME" || true
else
    echo "Fetching PR 2752..."
    git fetch origin pull/2752/head:pr2752 || {
        echo "Error: Could not fetch PR 2752. Make sure the PR exists and you have access."
        echo "You may need to manually create a branch based on PR 2752."
        exit 1
    }
    
    echo "Creating branch $BRANCH_NAME from PR 2752..."
    git checkout -b "$BRANCH_NAME" pr2752
fi

# Step 4: Add missing event files
echo ""
echo "Adding missing event files..."

# Create directories if they don't exist
mkdir -p app/include/zmk/events
mkdir -p app/src/events

# Copy split_peripheral_layer_changed.h
if [ ! -f "app/include/zmk/events/split_peripheral_layer_changed.h" ]; then
    cp "$PATCHES_DIR/split_peripheral_layer_changed.h" \
       "app/include/zmk/events/split_peripheral_layer_changed.h"
    echo "  ✓ Added split_peripheral_layer_changed.h"
else
    echo "  ⊙ split_peripheral_layer_changed.h already exists"
fi

# Copy split_peripheral_layer_changed.c
if [ ! -f "app/src/events/split_peripheral_layer_changed.c" ]; then
    cp "$PATCHES_DIR/split_peripheral_layer_changed.c" \
       "app/src/events/split_peripheral_layer_changed.c"
    echo "  ✓ Added split_peripheral_layer_changed.c"
else
    echo "  ⊙ split_peripheral_layer_changed.c already exists"
fi

# Ensure hid_indicators_changed.c exists
if [ ! -f "app/src/events/hid_indicators_changed.c" ]; then
    if [ -f "app/include/zmk/events/hid_indicators_changed.h" ]; then
        cp "$PATCHES_DIR/hid_indicators_changed.c" \
           "app/src/events/hid_indicators_changed.c"
        echo "  ✓ Added hid_indicators_changed.c"
    else
        echo "  ⊙ hid_indicators_changed.h not found, skipping .c file"
    fi
else
    echo "  ⊙ hid_indicators_changed.c already exists"
fi

# Step 5: Commit changes
echo ""
echo "Committing changes..."
git add app/include/zmk/events/split_peripheral_layer_changed.h \
        app/src/events/split_peripheral_layer_changed.c \
        app/src/events/hid_indicators_changed.c 2>/dev/null || true

if git diff --staged --quiet; then
    echo "  ⊙ No changes to commit (files may already be committed)"
else
    git commit -m "Add missing event implementations for PR 2752

- Add zmk_split_peripheral_layer_changed event
- Ensure zmk_hid_indicators_changed event is implemented  
- Fixes linker errors in behavior_underglow_indicators and activity modules"
    echo "  ✓ Changes committed"
fi

# Step 6: Push to fork
echo ""
echo "Pushing to fork..."
if git push origin "$BRANCH_NAME" 2>/dev/null; then
    echo "  ✓ Pushed to $FORK_URL (branch: $BRANCH_NAME)"
else
    echo "  ⚠ Could not push. You may need to push manually:"
    echo "     git push origin $BRANCH_NAME"
fi

# Step 7: Update west.yml
echo ""
echo "Updating west.yml..."
cd "$REPO_ROOT"

# Create backup
cp config/west.yml config/west.yml.backup

# Update west.yml to use the fork
if grep -q "url.*github.com.*zmk" config/west.yml; then
    # Replace the zmk project entry
    sed -i.tmp "s|remote: zmkfirmware|remote: zmkfirmware\n      url: $FORK_URL|" config/west.yml
    sed -i.tmp "s|revision: pull/2752/head|revision: $BRANCH_NAME|" config/west.yml
    rm -f config/west.yml.tmp
    echo "  ✓ Updated config/west.yml"
    echo ""
    echo "Backup saved to: config/west.yml.backup"
else
    echo "  ⚠ Could not automatically update west.yml"
    echo "  Please update it manually:"
    echo "    - Change revision to: $BRANCH_NAME"
    echo "    - Add url: $FORK_URL (if using a different remote)"
fi

echo ""
echo "=== Done ==="
echo ""
echo "Next steps:"
echo "1. Review the changes in config/west.yml"
echo "2. Commit and push the updated west.yml"
echo "3. The build should now work without linker errors"
echo ""
echo "To revert:"
echo "  cp config/west.yml.backup config/west.yml"

