#!/bin/bash
#
# Reset Fork to Upstream
# 
# This script performs a hard reset of the current fork to match the upstream
# repository exactly. WARNING: This will permanently delete all local changes!
#
# The script automatically:
# - Finds the git repository root (works from any subdirectory)
# - Loads upstream URL from .ralph/upstream.json if available
# - Detects if the repository is a fork
# - Shows what will happen and asks for confirmation
#
# Usage:
#   ./reset-to-upstream.sh              # Interactive mode
#   ./reset-to-upstream.sh -f           # Force (skip confirmation)
#   ./reset-to-upstream.sh -b develop   # Specify branch
#   ./reset-to-upstream.sh -u <url>     # Override upstream URL
#

set -euo pipefail

# Defaults
BRANCH="main"
UPSTREAM_URL=""
FORCE=false

# Parse arguments
while getopts "b:u:fh" opt; do
    case $opt in
        b) BRANCH="$OPTARG" ;;
        u) UPSTREAM_URL="$OPTARG" ;;
        f) FORCE=true ;;
        h)
            echo "Usage: $0 [-b branch] [-u upstream_url] [-f]"
            echo "  -b  Branch to reset (default: main)"
            echo "  -u  Upstream URL (auto-detected from .ralph/upstream.json)"
            echo "  -f  Force (skip confirmation)"
            exit 0
            ;;
        *) exit 1 ;;
    esac
done

echo "=== Fork Reset Script ==="
echo ""

# Find git repository root (works from any subdirectory)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo -e "\033[31mERROR: Not in a git repository!\033[0m" >&2
    echo "Please run this script from within a git repository."
    exit 1
}

# Check if this is a local copy (has source.json instead of upstream.json)
SOURCE_CONFIG_PATH="$REPO_ROOT/.ralph/source.json"
if [[ -f "$SOURCE_CONFIG_PATH" ]]; then
    SOURCE_TYPE=""
    SOURCE_URL=""
    if command -v jq &>/dev/null; then
        SOURCE_TYPE=$(jq -r '.type // empty' "$SOURCE_CONFIG_PATH" 2>/dev/null || true)
        SOURCE_URL=$(jq -r '.url // empty' "$SOURCE_CONFIG_PATH" 2>/dev/null || true)
    else
        SOURCE_TYPE=$(grep -o '"type"[[:space:]]*:[[:space:]]*"[^"]*"' "$SOURCE_CONFIG_PATH" 2>/dev/null | sed 's/.*"type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)
        SOURCE_URL=$(grep -o '"url"[[:space:]]*:[[:space:]]*"[^"]*"' "$SOURCE_CONFIG_PATH" 2>/dev/null | sed 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)
    fi
    
    if [[ "$SOURCE_TYPE" == "local-copy" ]]; then
        echo -e "\033[31mERROR: This is a local copy, not a fork!\033[0m"
        echo ""
        echo -e "\033[33mLocal copies have their own independent git repository and\033[0m"
        echo -e "\033[33mcannot be reset to upstream. They are not connected to the\033[0m"
        echo -e "\033[33moriginal repository.\033[0m"
        echo ""
        echo -e "\033[90mSource was: $SOURCE_URL\033[0m"
        echo ""
        echo -e "\033[37mOptions:\033[0m"
        echo -e "  \033[36m1. Use 'git reset --hard HEAD' to undo local changes\033[0m"
        echo -e "  \033[36m2. Create a new fork if you need upstream sync capability\033[0m"
        exit 1
    fi
fi

# Try to load upstream configuration if not provided
if [[ -z "$UPSTREAM_URL" ]]; then
    CONFIG_PATH="$REPO_ROOT/.ralph/upstream.json"
    if [[ -f "$CONFIG_PATH" ]]; then
        if command -v jq &>/dev/null; then
            # Handle both old format (url) and new format (upstream)
            UPSTREAM_URL=$(jq -r '.upstream // .url // empty' "$CONFIG_PATH" 2>/dev/null || true)
            if [[ -n "$UPSTREAM_URL" ]]; then
                echo -e "\033[90mLoaded upstream from config: $UPSTREAM_URL\033[0m"
            fi
        else
            # Fallback parsing without jq - try upstream first, then url
            UPSTREAM_URL=$(grep -o '"upstream"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_PATH" 2>/dev/null | sed 's/.*"upstream"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)
            if [[ -z "$UPSTREAM_URL" ]]; then
                UPSTREAM_URL=$(grep -o '"url"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_PATH" 2>/dev/null | sed 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)
            fi
            if [[ -n "$UPSTREAM_URL" ]]; then
                echo -e "\033[90mLoaded upstream from config: $UPSTREAM_URL\033[0m"
            fi
        fi
    fi
    
    # Fallback to default if still not set
    if [[ -z "$UPSTREAM_URL" ]]; then
        UPSTREAM_URL="https://github.com/Promptly-AI-Agents/Copilot-Ralph.git"
        echo -e "\033[33mUsing default upstream: $UPSTREAM_URL\033[0m"
    fi
fi

# Save original location and change to repo root
ORIGINAL_DIR=$(pwd)
cd "$REPO_ROOT"
echo -e "\033[90mRepository root: $REPO_ROOT\033[0m"
echo ""

# Get current origin URL
ORIGIN_URL=$(git config --get remote.origin.url 2>/dev/null) || {
    echo -e "\033[31mERROR: No 'origin' remote found!\033[0m" >&2
    cd "$ORIGINAL_DIR"
    exit 1
}

# Detect if this looks like a fork
echo -e "\033[90mCurrent origin:  $ORIGIN_URL\033[0m"
echo -e "\033[90mUpstream target: $UPSTREAM_URL\033[0m"
echo ""

if [ "$ORIGIN_URL" != "$UPSTREAM_URL" ]; then
    echo -e "\033[36mFORK DETECTED\033[0m"
    echo -e "\033[90mThis repository appears to be a fork of the upstream repository.\033[0m"
else
    echo -e "\033[33mNOTE: Origin URL matches upstream URL.\033[0m"
    echo -e "\033[33mThis may be the original repository, not a fork.\033[0m"
fi
echo ""

# Check for local changes
STATUS=$(git status --porcelain 2>/dev/null)
if [ -n "$STATUS" ]; then
    echo -e "\033[33mUNCOMMITTED CHANGES DETECTED:\033[0m"
    git status --short
    echo ""
fi

# Explain what will happen
echo -e "\033[33m========================================\033[0m"
echo -e "\033[33mWHAT WILL HAPPEN:\033[0m"
echo -e "\033[33m========================================\033[0m"
echo ""
echo "1. Add/update 'upstream' remote pointing to:"
echo -e "   \033[90m$UPSTREAM_URL\033[0m"
echo ""
echo "2. Fetch latest code from upstream"
echo ""
echo "3. HARD RESET '$BRANCH' branch to match upstream/$BRANCH"
echo -e "   \033[31m- ALL uncommitted changes will be DELETED\033[0m"
echo -e "   \033[31m- ALL commits not in upstream will be DELETED\033[0m"
echo -e "   \033[31m- Your local branch will be IDENTICAL to upstream\033[0m"
echo ""
echo "4. FORCE PUSH to origin (GitHub)"
echo -e "   \033[31m- Your fork's history will be OVERWRITTEN\033[0m"
echo -e "   \033[31m- This cannot be undone!\033[0m"
echo ""
echo -e "\033[33m========================================\033[0m"
echo ""

if [ "$FORCE" = false ]; then
    echo "Type 'yes' to confirm you understand and want to proceed."
    read -p "Reset fork to upstream? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted. No changes made."
        cd "$ORIGINAL_DIR"
        exit 0
    fi
fi

echo ""
echo -e "\033[36mProceeding with reset...\033[0m"
echo ""

# Step 1: Add upstream if not exists
echo -e "\033[36m[1/5] Checking upstream remote...\033[0m"
if ! git remote | grep -q "^upstream$"; then
    echo "      Adding upstream: $UPSTREAM_URL"
    git remote add upstream "$UPSTREAM_URL"
else
    echo "      Upstream already exists, updating URL..."
    git remote set-url upstream "$UPSTREAM_URL"
fi

# Step 2: Fetch upstream
echo -e "\033[36m[2/5] Fetching upstream...\033[0m"
git fetch upstream

# Step 3: Checkout branch
echo -e "\033[36m[3/5] Checking out $BRANCH...\033[0m"
git checkout "$BRANCH"

# Step 4: Hard reset to upstream
echo -e "\033[36m[4/5] Resetting to upstream/$BRANCH...\033[0m"
git reset --hard "upstream/$BRANCH"

# Step 5: Force push
echo -e "\033[36m[5/5] Force pushing to origin...\033[0m"
git push --force

echo ""
echo -e "\033[32m=== SUCCESS ===\033[0m"
echo -e "\033[32mFork has been reset to match upstream!\033[0m"
echo ""
echo -e "\033[90mYour repository is now identical to:\033[0m"
echo -e "\033[36m$UPSTREAM_URL\033[0m"

# Return to original location
cd "$ORIGINAL_DIR"
