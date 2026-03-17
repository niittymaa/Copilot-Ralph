#!/usr/bin/env bash
# Install Ralph into any project with a single command.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/niittymaa/Copilot-Ralph/main/install.sh | bash
#
# Options (when saved as a script):
#   --branch <name>   Branch to install from (default: main)
#   --no-start        Install only, don't start Ralph
#   --force           Overwrite existing ralph/ folder without prompting

set -euo pipefail

# ═══════════════════════════════════════════════════════════════
#                     CONFIGURATION
# ═══════════════════════════════════════════════════════════════

REPO_URL="https://github.com/niittymaa/Copilot-Ralph.git"
BRANCH="main"
NO_START=false
FORCE=false

# ═══════════════════════════════════════════════════════════════
#                     ARGUMENT PARSING
# ═══════════════════════════════════════════════════════════════

while [[ $# -gt 0 ]]; do
    case "$1" in
        --branch|-b)
            BRANCH="$2"
            shift 2
            ;;
        --no-start)
            NO_START=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        -h|--help)
            echo "Usage: install.sh [--branch <name>] [--no-start] [--force]"
            echo ""
            echo "Options:"
            echo "  --branch, -b  Branch to install from (default: main)"
            echo "  --no-start    Install only, don't start Ralph"
            echo "  --force, -f   Overwrite existing ralph/ folder"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

RALPH_DIR="$(pwd)/ralph"
RALPH_DATA_DIR="$(pwd)/.ralph"

# ═══════════════════════════════════════════════════════════════
#                     COLORS
# ═══════════════════════════════════════════════════════════════

if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    GRAY='\033[0;90m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' WHITE='' GRAY='' NC=''
fi

# ═══════════════════════════════════════════════════════════════
#                     DISPLAY
# ═══════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}  RALPH INSTALLER - Autonomous AI Coding Agent${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
#                     PREREQUISITES
# ═══════════════════════════════════════════════════════════════

# Check git
if ! command -v git &>/dev/null; then
    echo -e "${RED}  ERROR: git is not installed or not in PATH${NC}"
    echo -e "${YELLOW}  Install git from https://git-scm.com/${NC}"
    exit 1
fi

# Check copilot CLI (warn only)
if ! command -v copilot &>/dev/null; then
    echo -e "${YELLOW}  WARNING: GitHub Copilot CLI not found${NC}"
    echo -e "${GRAY}  Install with: npm install -g @github/copilot${NC}"
    echo -e "${GRAY}  Then run: copilot auth${NC}"
    echo ""
fi

# Check if ralph/ already exists
if [[ -d "$RALPH_DIR" ]]; then
    if [[ "$FORCE" != "true" ]]; then
        echo -e "${YELLOW}  ralph/ folder already exists in this directory.${NC}"
        echo ""
        read -rp "  Overwrite? (yes/[N]o): " confirm
        confirm="${confirm:-n}"
        if [[ ! "$confirm" =~ ^(y|yes)$ ]]; then
            echo -e "${GRAY}  Cancelled.${NC}"
            exit 0
        fi
    fi
    echo -e "${GRAY}  Removing existing ralph/ folder...${NC}"
    rm -rf "$RALPH_DIR"
fi

# ═══════════════════════════════════════════════════════════════
#                     DOWNLOAD
# ═══════════════════════════════════════════════════════════════

echo -e "${CYAN}  Downloading Ralph ($BRANCH)...${NC}"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

# Try sparse checkout first (minimal download)
if git clone --depth 1 --branch "$BRANCH" --filter=blob:none --sparse --quiet --no-progress "$REPO_URL" "$TEMP_DIR" 2>/dev/null; then
    (
        cd "$TEMP_DIR"
        git sparse-checkout set ralph 2>/dev/null
    )

    if [[ -d "$TEMP_DIR/ralph" ]]; then
        cp -r "$TEMP_DIR/ralph" "$RALPH_DIR"
        echo -e "${GREEN}  Downloaded ralph/ folder${NC}"
    else
        echo -e "${RED}  ERROR: ralph/ folder not found in repository${NC}"
        exit 1
    fi
else
    # Fallback: full shallow clone
    echo -e "${YELLOW}  Trying fallback download method...${NC}"
    rm -rf "$TEMP_DIR"
    TEMP_DIR="$(mktemp -d)"

    if git clone --depth 1 --branch "$BRANCH" --quiet --no-progress "$REPO_URL" "$TEMP_DIR" 2>/dev/null; then
        cp -r "$TEMP_DIR/ralph" "$RALPH_DIR"
        echo -e "${GREEN}  Downloaded ralph/ folder (fallback method)${NC}"
    else
        echo -e "${RED}  ERROR: Failed to download Ralph${NC}"
        echo -e "${YELLOW}  Check your network connection and try again.${NC}"
        exit 1
    fi
fi

# Make scripts executable
chmod +x "$RALPH_DIR/ralph.sh" 2>/dev/null || true
chmod +x "$RALPH_DIR/ralph.ps1" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════
#                     SOURCE TRACKING
# ═══════════════════════════════════════════════════════════════

# Create .ralph/ directory and source.json for update tracking
mkdir -p "$RALPH_DATA_DIR"

cat > "$RALPH_DATA_DIR/source.json" <<EOF
{
  "url": "$REPO_URL",
  "branch": "$BRANCH",
  "installed": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "method": "installer"
}
EOF
echo -e "${GREEN}  Created .ralph/source.json (for updates)${NC}"

# ═══════════════════════════════════════════════════════════════
#                     GITIGNORE
# ═══════════════════════════════════════════════════════════════

GITIGNORE_PATH="$(pwd)/.gitignore"

if [[ -f "$GITIGNORE_PATH" ]]; then
    additions=""
    if ! grep -qF ".ralph/" "$GITIGNORE_PATH"; then
        additions="${additions}.ralph/\n"
    fi
    if ! grep -qF "ralph/config.json" "$GITIGNORE_PATH"; then
        additions="${additions}ralph/config.json\n"
    fi
    if [[ -n "$additions" ]]; then
        printf "\n# Ralph runtime files\n%b" "$additions" >> "$GITIGNORE_PATH"
        echo -e "${GREEN}  Updated .gitignore${NC}"
    fi
else
    cat > "$GITIGNORE_PATH" <<'GITIGNORE'
# Ralph runtime files
.ralph/
ralph/config.json
GITIGNORE
    echo -e "${GREEN}  Created .gitignore${NC}"
fi

# ═══════════════════════════════════════════════════════════════
#                     COMPLETE
# ═══════════════════════════════════════════════════════════════

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}  RALPH INSTALLED SUCCESSFULLY!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}  Commands:${NC}"
echo -e "${WHITE}    ./ralph/ralph.ps1            # Start Ralph (PowerShell)${NC}"
echo -e "${WHITE}    ./ralph/ralph.sh             # Start Ralph (Bash)${NC}"
echo -e "${WHITE}    ./ralph/ralph.ps1 -Update    # Update Ralph later${NC}"
echo ""

# Start Ralph automatically unless --no-start was specified
if [[ "$NO_START" != "true" ]]; then
    echo -e "${CYAN}  Starting Ralph...${NC}"
    echo ""
    exec "$RALPH_DIR/ralph.sh"
fi
