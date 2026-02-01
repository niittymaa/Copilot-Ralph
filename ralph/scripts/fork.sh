#!/usr/bin/env bash
#
# Fork and clone a Ralph instance for a new project.
# Automatically falls back to local-only mode if GitHub CLI is unavailable.
#
# Usage: ./fork.sh [-n NAME] [-p PATH] [-f original|current|URL] [-l] [-V] [-h]

set -euo pipefail

# Constants
ORIGINAL_REPO_URL="https://github.com/niittymaa/Copilot-Ralph"
ORIGINAL_OWNER="niittymaa"
ORIGINAL_REPO="Copilot-Ralph"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m'

# Defaults
NAME=""
CUSTOM_PATH=""
FORK_FROM=""
LOCAL_ONLY=false
NO_VSCODE=false
NO_EXPLORER=false
NO_TERMINAL=false

#region Helper Functions

write_header() { echo -e "\n${CYAN}=== $1 ===${NC}\n"; }
write_step() { echo -e "${CYAN}[$1/$2] $3${NC}"; }
write_info() { echo -e "${GRAY}    $1${NC}"; }

show_help() {
    cat << EOF
Fork and clone a Ralph instance for a new project.

Usage: ./fork.sh [-n NAME] [-p PATH] [-f original|current|URL] [-l] [-V] [-h]

Options:
  -n, --name NAME       Name for the fork
  -p, --path PATH       Custom path for the fork (default: .ralph/forks/)
  -f, --fork-from SRC   Fork source: 'original', 'current', or GitHub URL
  -l, --local-only      Force local-only mode
  -V, --no-vscode       Skip opening VS Code
  --no-explorer         Skip opening file explorer
  --no-terminal         Skip opening terminal
  -h, --help            Show this help
EOF
}

test_github_available() {
    command -v gh &>/dev/null && gh auth status &>/dev/null
}

get_repo_info() {
    gh api "repos/$1/$2" 2>/dev/null
}

get_current_repo_info() {
    local origin_url
    origin_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
    if [[ "$origin_url" =~ github\.com[:/]([^/]+)/([^/]+?)(\.git)?$ ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
}

get_authenticated_user() {
    gh api user --jq '.login' 2>/dev/null || echo ""
}

get_next_available_name() {
    local base_name="$1" forks_dir="$2" candidate="$1" counter=2
    while [[ -d "$forks_dir/$candidate" ]]; do
        candidate="${base_name}-${counter}"
        ((counter++))
    done
    echo "$candidate"
}

# Validates and resolves a path to its full form
# Handles various formats: absolute, relative, drive-relative (Windows via WSL)
resolve_smart_path() {
    local input_path="$1"
    
    [[ -z "$input_path" ]] && return 1
    
    # Handle ~ expansion
    if [[ "$input_path" == "~"* ]]; then
        input_path="${input_path/#\~/$HOME}"
    fi
    
    # Get full path using realpath if available, fallback to readlink
    if command -v realpath &>/dev/null; then
        # realpath -m allows non-existent paths
        realpath -m "$input_path" 2>/dev/null || echo ""
    elif [[ -e "$input_path" ]]; then
        readlink -f "$input_path" 2>/dev/null || echo ""
    else
        # For non-existent paths, just resolve relative to pwd
        local dir_part base_part
        dir_part=$(dirname "$input_path")
        base_part=$(basename "$input_path")
        
        if [[ -d "$dir_part" ]]; then
            echo "$(cd "$dir_part" && pwd)/$base_part"
        else
            echo ""
        fi
    fi
}

#endregion

#region Argument Parsing

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name) NAME="$2"; shift 2 ;;
        -p|--path) CUSTOM_PATH="$2"; shift 2 ;;
        -f|--fork-from) FORK_FROM="$2"; shift 2 ;;
        -l|--local-only) LOCAL_ONLY=true; shift ;;
        -V|--no-vscode) NO_VSCODE=true; shift ;;
        --no-explorer) NO_EXPLORER=true; shift ;;
        --no-terminal) NO_TERMINAL=true; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; show_help; exit 1 ;;
    esac
done

#endregion

#region Main Script

write_header "Ralph Fork Creator"

# Step 1: Check prerequisites and determine mode
write_step 1 6 "Checking prerequisites..."

GH_USER=""
if [[ "$LOCAL_ONLY" == "true" ]]; then
    write_info "Local-only mode: Forced by parameter"
elif ! test_github_available; then
    echo -e "  ${YELLOW}GitHub CLI not available - using local-only mode${NC}"
    LOCAL_ONLY=true
else
    GH_USER=$(get_authenticated_user)
    if [[ -z "$GH_USER" ]]; then
        echo -e "  ${YELLOW}Could not get GitHub user - using local-only mode${NC}"
        LOCAL_ONLY=true
    else
        write_info "GitHub: OK (logged in as $GH_USER)"
    fi
fi

# Step 2: Detect current repository
write_step 2 6 "Analyzing current repository..."

CURRENT_REPO=$(get_current_repo_info)
if [[ -z "$CURRENT_REPO" ]]; then
    echo -e "${RED}ERROR: Not in a git repository or no GitHub remote found!${NC}"
    exit 1
fi

CURRENT_OWNER="${CURRENT_REPO%/*}"
CURRENT_REPO_NAME="${CURRENT_REPO#*/}"
write_info "Current repo: $CURRENT_REPO"

IS_ORIGINAL=false
[[ "$CURRENT_OWNER" == "$ORIGINAL_OWNER" && "$CURRENT_REPO_NAME" == "$ORIGINAL_REPO" ]] && IS_ORIGINAL=true

IS_FORK=false
PARENT_OWNER="" PARENT_REPO="" PARENT_URL=""
if [[ "$LOCAL_ONLY" == "false" ]]; then
    REPO_JSON=$(get_repo_info "$CURRENT_OWNER" "$CURRENT_REPO_NAME" || echo "{}")
    IS_FORK=$(echo "$REPO_JSON" | jq -r '.fork // false')
    PARENT_OWNER=$(echo "$REPO_JSON" | jq -r '.parent.owner.login // empty')
    PARENT_REPO=$(echo "$REPO_JSON" | jq -r '.parent.name // empty')
    PARENT_URL=$(echo "$REPO_JSON" | jq -r '.parent.html_url // empty')
fi

echo ""
if [[ "$IS_ORIGINAL" == "true" ]]; then
    echo -e "${GREEN}This is the ORIGINAL Ralph repository.${NC}"
elif [[ "$IS_FORK" == "true" ]]; then
    echo -e "${YELLOW}This is a FORK of: $PARENT_OWNER/$PARENT_REPO${NC}"
else
    echo -e "${YELLOW}Standalone repository (not a fork).${NC}"
fi

# Step 3: Determine fork source
write_step 3 6 "Determining fork source..."

FORK_SOURCE_URL="" FORK_SOURCE_OWNER="" FORK_SOURCE_REPO=""

if [[ -n "$FORK_FROM" ]]; then
    case "$FORK_FROM" in
        original)
            FORK_SOURCE_OWNER="$ORIGINAL_OWNER"
            FORK_SOURCE_REPO="$ORIGINAL_REPO"
            FORK_SOURCE_URL="$ORIGINAL_REPO_URL"
            ;;
        current)
            FORK_SOURCE_OWNER="$CURRENT_OWNER"
            FORK_SOURCE_REPO="$CURRENT_REPO_NAME"
            FORK_SOURCE_URL="https://github.com/$CURRENT_OWNER/$CURRENT_REPO_NAME"
            ;;
        *)
            if [[ "$FORK_FROM" =~ github\.com[:/]([^/]+)/([^/]+?)(\.git)?$ ]]; then
                FORK_SOURCE_OWNER="${BASH_REMATCH[1]}"
                FORK_SOURCE_REPO="${BASH_REMATCH[2]}"
                FORK_SOURCE_URL="$FORK_FROM"
            else
                echo -e "${RED}ERROR: Invalid --fork-from. Use 'original', 'current', or GitHub URL.${NC}"
                exit 1
            fi
            ;;
    esac
elif [[ "$IS_ORIGINAL" == "true" ]]; then
    FORK_SOURCE_OWNER="$ORIGINAL_OWNER"
    FORK_SOURCE_REPO="$ORIGINAL_REPO"
    FORK_SOURCE_URL="$ORIGINAL_REPO_URL"
elif [[ "$IS_FORK" == "true" && "$LOCAL_ONLY" == "false" ]]; then
    echo -e "\nChoose fork source:"
    echo -e "  ${CYAN}[1] Original: $PARENT_OWNER/$PARENT_REPO${NC}"
    echo -e "  ${CYAN}[2] Current:  $CURRENT_OWNER/$CURRENT_REPO_NAME${NC}"
    echo ""
    while true; do
        read -rp "Enter choice (1 or 2): " choice
        [[ "$choice" =~ ^[12]$ ]] && break
    done
    if [[ "$choice" == "1" ]]; then
        FORK_SOURCE_OWNER="$PARENT_OWNER"
        FORK_SOURCE_REPO="$PARENT_REPO"
        FORK_SOURCE_URL="$PARENT_URL"
    else
        FORK_SOURCE_OWNER="$CURRENT_OWNER"
        FORK_SOURCE_REPO="$CURRENT_REPO_NAME"
        FORK_SOURCE_URL="https://github.com/$CURRENT_OWNER/$CURRENT_REPO_NAME"
    fi
else
    FORK_SOURCE_OWNER="$CURRENT_OWNER"
    FORK_SOURCE_REPO="$CURRENT_REPO_NAME"
    FORK_SOURCE_URL="https://github.com/$CURRENT_OWNER/$CURRENT_REPO_NAME"
fi

# Ask for fork mode if GitHub is available and not already forced to local
if [[ "$LOCAL_ONLY" == "false" && -n "$GH_USER" ]]; then
    echo -e "\nChoose fork mode:"
    echo -e "  ${CYAN}[1] GitHub fork: Create fork on GitHub${NC}"
    echo -e "  ${CYAN}[2] Local only:  Clone locally without GitHub${NC}"
    echo ""
    while true; do
        read -rp "Enter choice (1 or 2): " choice
        [[ "$choice" =~ ^[12]$ ]] && break
    done
    [[ "$choice" == "2" ]] && LOCAL_ONLY=true
fi

local_suffix=""
[[ "$LOCAL_ONLY" == "true" ]] && local_suffix=" (local only)"
write_info "Fork source: $FORK_SOURCE_URL$local_suffix"

# Determine paths
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
FORKS_DIR="$REPO_ROOT/.ralph/forks"

# Handle custom path if provided
if [[ -n "$CUSTOM_PATH" ]]; then
    RESOLVED_PATH=$(resolve_smart_path "$CUSTOM_PATH")
    if [[ -z "$RESOLVED_PATH" ]]; then
        echo -e "${RED}ERROR: Invalid path: $CUSTOM_PATH${NC}"
        exit 1
    fi
    
    # If path is a directory that exists, use it as parent
    if [[ -d "$RESOLVED_PATH" ]]; then
        FORKS_DIR="$RESOLVED_PATH"
    else
        # Use as full path, derive fork directory from parent
        FORKS_DIR=$(dirname "$RESOLVED_PATH")
        NAME=$(basename "$RESOLVED_PATH")
    fi
fi

# Step 4: Get fork name
write_step 4 6 "Configuring fork location..."

DEFAULT_NAME=$(get_next_available_name "my-project" "$FORKS_DIR")

if [[ -z "$NAME" ]]; then
    echo ""
    echo -e "${GRAY}  Default location: $FORKS_DIR/$DEFAULT_NAME${NC}"
    echo -e "${GRAY}  (You can specify a different parent folder or full path)${NC}"
    echo ""
    read -rp "  Enter name for your new fork (Enter for '$DEFAULT_NAME'): " NAME
    [[ -z "$NAME" ]] && NAME="$DEFAULT_NAME"
fi

SAFE_NAME=$(echo "$NAME" | sed 's/[^a-zA-Z0-9_-]/-/g')
FORK_PATH="$FORKS_DIR/$SAFE_NAME"

# Validate the final path
if [[ -d "$FORK_PATH" ]]; then
    # Check if directory is empty
    if [[ -n "$(ls -A "$FORK_PATH" 2>/dev/null)" ]]; then
        echo -e "${RED}ERROR: Fork directory already exists and is not empty: $FORK_PATH${NC}"
        exit 1
    fi
elif [[ -f "$FORK_PATH" ]]; then
    echo -e "${RED}ERROR: A file already exists at: $FORK_PATH${NC}"
    exit 1
fi

write_info "Location: $FORK_PATH"
write_info "Name: $NAME"

# Step 5: Confirmation
echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}FORK PLAN:${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "\nSource: ${CYAN}$FORK_SOURCE_URL${NC}"
if [[ "$LOCAL_ONLY" == "true" ]]; then
    echo -e "Mode:   ${YELLOW}LOCAL ONLY${NC}"
    echo -e "Local:  ${CYAN}$FORK_PATH${NC}"
else
    echo -e "GitHub: ${CYAN}github.com/$GH_USER/$SAFE_NAME${NC}"
    echo -e "Local:  ${CYAN}$FORK_PATH${NC}"
fi
echo -e "\n${YELLOW}========================================${NC}\n"

read -rp "Proceed? ([Y]es/no): " confirm
[[ -z "$confirm" ]] && confirm="y"
if [[ ! "$confirm" =~ ^(y|yes|Y|Yes|YES)$ ]]; then
    echo -e "${GRAY}Aborted.${NC}"
    exit 0
fi

# Step 6: Execute
write_header "Creating Fork"

mkdir -p "$FORKS_DIR"

if [[ "$LOCAL_ONLY" == "true" ]]; then
    write_step 1 3 "Cloning repository locally..."
    if ! git clone "$FORK_SOURCE_URL" "$FORK_PATH" 2>/dev/null; then
        echo -e "${RED}ERROR: Failed to clone repository!${NC}"
        exit 1
    fi
    
    write_step 2 3 "Creating fresh git repository..."
    # Remove original git history to create independent repository
    rm -rf "$FORK_PATH/.git"
    
    # Initialize new empty git repository
    pushd "$FORK_PATH" > /dev/null
    git init > /dev/null 2>&1
    git add -A > /dev/null 2>&1
    git commit -m "Initial commit from Ralph template" > /dev/null 2>&1
    popd > /dev/null
    write_info "Created new independent git repository"
    
    write_step 3 3 "Saving source configuration..."
    # Save source configuration (for reference, not as git remote)
    mkdir -p "$FORK_PATH/.ralph"
    cat > "$FORK_PATH/.ralph/source.json" <<EOF
{
  "url": "$FORK_SOURCE_URL",
  "owner": "$FORK_SOURCE_OWNER",
  "repo": "$FORK_SOURCE_REPO",
  "type": "local-copy",
  "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    write_info "Source info saved: .ralph/source.json"
else
    write_step 1 4 "Creating fork on GitHub..."
    if ! gh repo fork "$FORK_SOURCE_OWNER/$FORK_SOURCE_REPO" --fork-name "$SAFE_NAME" --clone=false 2>/dev/null; then
        if ! gh api "repos/$GH_USER/$SAFE_NAME" &>/dev/null; then
            echo -e "${RED}ERROR: Failed to create fork!${NC}"
            exit 1
        fi
        echo -e "  ${YELLOW}Fork already exists, continuing...${NC}"
    fi
    
    write_step 2 4 "Cloning fork locally..."
    if ! git clone "https://github.com/$GH_USER/$SAFE_NAME.git" "$FORK_PATH" 2>/dev/null; then
        echo -e "${RED}ERROR: Failed to clone fork!${NC}"
        exit 1
    fi
    
    write_step 3 4 "Setting up upstream remote..."
    pushd "$FORK_PATH" > /dev/null
    git remote add upstream "$FORK_SOURCE_URL" 2>/dev/null || true
    popd > /dev/null
    write_info "Origin: https://github.com/$GH_USER/$SAFE_NAME (your fork - push here)"
    write_info "Upstream: $FORK_SOURCE_URL (read-only, for pulling updates)"
    
    write_step 4 4 "Saving fork configuration..."
    mkdir -p "$FORK_PATH/.ralph"
    cat > "$FORK_PATH/.ralph/upstream.json" <<EOF
{
  "origin": "https://github.com/$GH_USER/$SAFE_NAME",
  "upstream": "$FORK_SOURCE_URL",
  "upstreamOwner": "$FORK_SOURCE_OWNER",
  "upstreamRepo": "$FORK_SOURCE_REPO",
  "type": "github-fork",
  "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    write_info "Fork config saved: .ralph/upstream.json"
fi

write_header "Success!"
echo -e "${GREEN}Location: $FORK_PATH${NC}"
[[ "$LOCAL_ONLY" == "false" ]] && echo -e "${CYAN}GitHub:   https://github.com/$GH_USER/$SAFE_NAME${NC}"

# Post-fork actions menu
echo ""
echo -e "${WHITE}Post-Fork Actions:${NC}"
echo ""

# VS Code
if [[ "$NO_VSCODE" == "false" ]]; then
    echo -e "  ${CYAN}[1] Open in VS Code${NC}"
    read -rp "  Open in VS Code? ([Y]es/no): " open_vscode
    [[ -z "$open_vscode" ]] && open_vscode="y"
    if [[ "$open_vscode" =~ ^(y|yes|Y|Yes|YES)$ ]]; then
        code "$FORK_PATH" 2>/dev/null || echo -e "    ${YELLOW}VS Code not found${NC}"
    fi
fi

# File Explorer (platform-specific)
if [[ "$NO_EXPLORER" == "false" ]]; then
    echo -e "  ${CYAN}[2] Open in File Explorer${NC}"
    read -rp "  Open folder in file explorer? (yes/[N]o): " open_explorer
    if [[ "$open_explorer" =~ ^(y|yes|Y|Yes|YES)$ ]]; then
        # Detect platform and open accordingly
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open "$FORK_PATH" 2>/dev/null || true
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Check for WSL
            if grep -qi microsoft /proc/version 2>/dev/null; then
                # WSL - use Windows explorer
                explorer.exe "$(wslpath -w "$FORK_PATH")" 2>/dev/null || true
            else
                # Native Linux
                xdg-open "$FORK_PATH" 2>/dev/null || true
            fi
        elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
            explorer "$FORK_PATH" 2>/dev/null || true
        fi
    fi
fi

# Terminal
if [[ "$NO_TERMINAL" == "false" ]]; then
    echo -e "  ${CYAN}[3] Open Terminal in Project${NC}"
    read -rp "  Open new terminal in project? (yes/[N]o): " open_terminal
    if [[ "$open_terminal" =~ ^(y|yes|Y|Yes|YES)$ ]]; then
        # Detect platform and open terminal
        if [[ "$OSTYPE" == "darwin"* ]]; then
            osascript -e "tell application \"Terminal\" to do script \"cd '$FORK_PATH'\"" 2>/dev/null || true
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Try various terminal emulators
            if command -v gnome-terminal &>/dev/null; then
                gnome-terminal --working-directory="$FORK_PATH" 2>/dev/null &
            elif command -v konsole &>/dev/null; then
                konsole --workdir "$FORK_PATH" 2>/dev/null &
            elif command -v xterm &>/dev/null; then
                xterm -e "cd '$FORK_PATH' && bash" 2>/dev/null &
            else
                echo -e "    ${YELLOW}No supported terminal emulator found${NC}"
            fi
        fi
    fi
fi

echo ""
echo -e "${YELLOW}Next: cd \"$FORK_PATH\" && ./ralph/ralph.sh${NC}"
echo ""

#endregion
