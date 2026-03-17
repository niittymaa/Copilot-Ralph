#!/usr/bin/env bash
# Install, update, or uninstall Ralph in any project.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/niittymaa/Copilot-Ralph/main/install.sh | bash
#
# Options (when saved as a script):
#   --branch <name>   Branch to install from (default: main)
#   --no-start        Install only, don't start Ralph
#   --force           Skip interactive prompts
#   --action <name>   Pre-select action: fresh, update, uninstall

set -euo pipefail

# ═══════════════════════════════════════════════════════════════
#                     CONFIGURATION
# ═══════════════════════════════════════════════════════════════

REPO_URL="https://github.com/niittymaa/Copilot-Ralph.git"
BRANCH="main"
NO_START=false
FORCE=false
ACTION=""

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
        --action|-a)
            ACTION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: install.sh [--branch <name>] [--no-start] [--force] [--action <fresh|update|uninstall>]"
            echo ""
            echo "Options:"
            echo "  --branch, -b   Branch to install from (default: main)"
            echo "  --no-start     Install only, don't start Ralph"
            echo "  --force, -f    Skip interactive prompts"
            echo "  --action, -a   Pre-select action: fresh, update, uninstall"
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
GITHUB_DIR="$(pwd)/.github"
AGENTS_DIR="$GITHUB_DIR/agents"
INSTRUCTIONS_DIR="$GITHUB_DIR/instructions"
AGENTS_MD_PATH="$(pwd)/AGENTS.md"

# Ralph agent files
RALPH_AGENT_FILES=(
    "ralph.agent.md"
    "ralph-planner.agent.md"
    "ralph-spec-creator.agent.md"
    "ralph-agents-updater.agent.md"
)

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
    DGRAY='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' WHITE='' GRAY='' DGRAY='' NC=''
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
#                     DISCLAIMER
# ═══════════════════════════════════════════════════════════════

if [[ "$FORCE" != "true" ]]; then
    echo -e "${YELLOW}  ┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}  │                    ⚠️  DISCLAIMER                       │${NC}"
    echo -e "${YELLOW}  │                                                         │${NC}"
    echo -e "${YELLOW}  │  Ralph is an autonomous AI coding agent that modifies   │${NC}"
    echo -e "${YELLOW}  │  your codebase. By installing, you acknowledge:         │${NC}"
    echo -e "${YELLOW}  │                                                         │${NC}"
    echo -e "${YELLOW}  │  • Ralph will read, write, and delete files in your     │${NC}"
    echo -e "${YELLOW}  │    project directory autonomously                       │${NC}"
    echo -e "${YELLOW}  │  • By default, Ralph has unrestricted filesystem        │${NC}"
    echo -e "${YELLOW}  │    access (configurable in ralph/config.json)           │${NC}"
    echo -e "${YELLOW}  │  • Continuous AI loops consume significant tokens       │${NC}"
    echo -e "${YELLOW}  │  • Always use Git version control and review changes    │${NC}"
    echo -e "${YELLOW}  │                                                         │${NC}"
    echo -e "${YELLOW}  │  USE AT YOUR OWN RISK. The authors assume no           │${NC}"
    echo -e "${YELLOW}  │  responsibility for any damage, data loss, or           │${NC}"
    echo -e "${YELLOW}  │  unintended modifications caused by this software.      │${NC}"
    echo -e "${YELLOW}  │                                                         │${NC}"
    echo -e "${YELLOW}  │  Requires: GitHub Copilot CLI + active subscription     │${NC}"
    echo -e "${YELLOW}  └─────────────────────────────────────────────────────────┘${NC}"
    echo ""
    read -rp "  Accept and continue? (yes/[N]o): " accept
    accept="${accept:-n}"
    if [[ ! "$accept" =~ ^(y|yes)$ ]]; then
        echo -e "${GRAY}  Installation cancelled.${NC}"
        exit 0
    fi
    echo ""
fi

# ═══════════════════════════════════════════════════════════════
#                     PREREQUISITES
# ═══════════════════════════════════════════════════════════════

if ! command -v git &>/dev/null; then
    echo -e "${RED}  ERROR: git is not installed or not in PATH${NC}"
    echo -e "${YELLOW}  Install git from https://git-scm.com/${NC}"
    exit 1
fi

if ! command -v copilot &>/dev/null; then
    echo -e "${YELLOW}  WARNING: GitHub Copilot CLI not found${NC}"
    echo -e "${GRAY}  Install with: npm install -g @github/copilot${NC}"
    echo -e "${GRAY}  Then run: copilot auth${NC}"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════
#                     HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

show_affected_files() {
    # $1 = action label, $2 = include_data (true/false)
    local action_label="$1"
    local include_data="${2:-true}"

    echo ""
    echo -e "${YELLOW}  The following Ralph files ${action_label}:${NC}"
    echo ""

    # ralph/
    if [[ -d "$RALPH_DIR" ]]; then
        local size
        size=$(du -sh "$RALPH_DIR" 2>/dev/null | cut -f1 || echo "?")
        echo -e "    ${WHITE}ralph/${NC}  ${DGRAY}(Framework, ${size})${NC}"
    fi

    # .ralph/
    if [[ "$include_data" == "true" && -d "$RALPH_DATA_DIR" ]]; then
        local details=""
        if [[ -d "$RALPH_DATA_DIR/tasks" ]]; then
            local session_count
            session_count=$(find "$RALPH_DATA_DIR/tasks" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$session_count" -gt 0 ]]; then
                details="${session_count} session(s)"
            fi
        fi
        [[ -f "$RALPH_DATA_DIR/memory.md" ]] && details="${details:+$details, }memory"
        [[ -d "$RALPH_DATA_DIR/venv" ]] && details="${details:+$details, }venv"
        [[ -d "$RALPH_DATA_DIR/logs" ]] && details="${details:+$details, }logs"
        local desc="${details:+Runtime data: $details}"
        desc="${desc:-Runtime data}"
        echo -e "    ${WHITE}.ralph/${NC}  ${DGRAY}(${desc})${NC}"
    fi

    # .github/agents/ - Ralph files only
    if [[ -d "$AGENTS_DIR" ]]; then
        for agent_file in "${RALPH_AGENT_FILES[@]}"; do
            if [[ -f "$AGENTS_DIR/$agent_file" ]]; then
                echo -e "    ${WHITE}.github/agents/${agent_file}${NC}  ${DGRAY}(Ralph agent prompt)${NC}"
            fi
        done
    fi

    # .github/instructions/ralph.instructions.md only
    if [[ -f "$INSTRUCTIONS_DIR/ralph.instructions.md" ]]; then
        echo -e "    ${WHITE}.github/instructions/ralph.instructions.md${NC}  ${DGRAY}(Ralph Copilot config)${NC}"
    fi

    # AGENTS.md if Ralph-generated
    if [[ -f "$AGENTS_MD_PATH" ]]; then
        if grep -qi "ralph" "$AGENTS_MD_PATH" 2>/dev/null; then
            echo -e "    ${WHITE}AGENTS.md${NC}  ${DGRAY}(Project guide, Ralph-generated)${NC}"
        fi
    fi

    # Show non-Ralph files that will be preserved
    local has_preserved=false
    if [[ -d "$AGENTS_DIR" ]]; then
        for f in "$AGENTS_DIR"/*; do
            [[ -f "$f" ]] || continue
            local fname
            fname=$(basename "$f")
            local is_ralph=false
            for rf in "${RALPH_AGENT_FILES[@]}"; do
                [[ "$fname" == "$rf" ]] && is_ralph=true && break
            done
            if [[ "$is_ralph" == "false" ]]; then
                if [[ "$has_preserved" == "false" ]]; then
                    echo ""
                    echo -e "${GREEN}  The following non-Ralph files will NOT be touched:${NC}"
                    has_preserved=true
                fi
                echo -e "    ${GRAY}.github/agents/${fname}${NC}"
            fi
        done
    fi
    if [[ -d "$INSTRUCTIONS_DIR" ]]; then
        for f in "$INSTRUCTIONS_DIR"/*; do
            [[ -f "$f" ]] || continue
            local fname
            fname=$(basename "$f")
            if [[ "$fname" != "ralph.instructions.md" ]]; then
                if [[ "$has_preserved" == "false" ]]; then
                    echo ""
                    echo -e "${GREEN}  The following non-Ralph files will NOT be touched:${NC}"
                    has_preserved=true
                fi
                echo -e "    ${GRAY}.github/instructions/${fname}${NC}"
            fi
        done
    fi
    echo ""
}

remove_ralph_files() {
    # $1 = include_data (true/false)
    local include_data="${1:-true}"

    # ralph/
    if [[ -d "$RALPH_DIR" ]]; then
        rm -rf "$RALPH_DIR"
        echo -e "    ${DGRAY}Removed: ralph/${NC}"
    fi

    # .ralph/
    if [[ "$include_data" == "true" && -d "$RALPH_DATA_DIR" ]]; then
        rm -rf "$RALPH_DATA_DIR"
        echo -e "    ${DGRAY}Removed: .ralph/${NC}"
    fi

    # .github/agents/ - only Ralph files
    if [[ -d "$AGENTS_DIR" ]]; then
        for agent_file in "${RALPH_AGENT_FILES[@]}"; do
            if [[ -f "$AGENTS_DIR/$agent_file" ]]; then
                rm -f "$AGENTS_DIR/$agent_file"
                echo -e "    ${DGRAY}Removed: .github/agents/${agent_file}${NC}"
            fi
        done
    fi

    # .github/instructions/ralph.instructions.md only
    if [[ -f "$INSTRUCTIONS_DIR/ralph.instructions.md" ]]; then
        rm -f "$INSTRUCTIONS_DIR/ralph.instructions.md"
        echo -e "    ${DGRAY}Removed: .github/instructions/ralph.instructions.md${NC}"
    fi

    # AGENTS.md if Ralph-generated
    if [[ -f "$AGENTS_MD_PATH" ]]; then
        if grep -qi "ralph" "$AGENTS_MD_PATH" 2>/dev/null; then
            rm -f "$AGENTS_MD_PATH"
            echo -e "    ${DGRAY}Removed: AGENTS.md${NC}"
        fi
    fi
}

install_ralph_from_remote() {
    echo -e "${CYAN}  Downloading Ralph ($BRANCH)...${NC}"

    TEMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TEMP_DIR"' EXIT

    if git clone --depth 1 --branch "$BRANCH" --filter=blob:none --sparse --quiet --no-progress "$REPO_URL" "$TEMP_DIR" >/dev/null 2>&1; then
        (
            cd "$TEMP_DIR"
            git sparse-checkout set ralph >/dev/null 2>&1
        )

        if [[ -d "$TEMP_DIR/ralph" ]]; then
            cp -r "$TEMP_DIR/ralph" "$RALPH_DIR"
            echo -e "${GREEN}  Downloaded ralph/ folder${NC}"
        else
            echo -e "${RED}  ERROR: ralph/ folder not found in repository${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}  Trying fallback download method...${NC}"
        rm -rf "$TEMP_DIR"
        TEMP_DIR="$(mktemp -d)"

        if git clone --depth 1 --branch "$BRANCH" --quiet --no-progress "$REPO_URL" "$TEMP_DIR" >/dev/null 2>&1; then
            cp -r "$TEMP_DIR/ralph" "$RALPH_DIR"
            echo -e "${GREEN}  Downloaded ralph/ folder (fallback method)${NC}"
        else
            echo -e "${RED}  ERROR: Failed to download Ralph${NC}"
            echo -e "${YELLOW}  Check your network connection and try again.${NC}"
            exit 1
        fi
    fi

    chmod +x "$RALPH_DIR/ralph.sh" 2>/dev/null || true
    chmod +x "$RALPH_DIR/ralph.ps1" 2>/dev/null || true
}

set_ralph_source_tracking() {
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
}

set_ralph_gitignore() {
    local gitignore_path
    gitignore_path="$(pwd)/.gitignore"

    if [[ -f "$gitignore_path" ]]; then
        local additions=""
        if ! grep -qF ".ralph/" "$gitignore_path"; then
            additions="${additions}.ralph/\n"
        fi
        if ! grep -qF "ralph/config.json" "$gitignore_path"; then
            additions="${additions}ralph/config.json\n"
        fi
        if [[ -n "$additions" ]]; then
            printf "\n# Ralph runtime files\n%b" "$additions" >> "$gitignore_path"
            echo -e "${GREEN}  Updated .gitignore${NC}"
        fi
    else
        cat > "$gitignore_path" <<'GITIGNORE'
# Ralph runtime files
.ralph/
ralph/config.json
GITIGNORE
        echo -e "${GREEN}  Created .gitignore${NC}"
    fi
}

show_install_success() {
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
}

# ═══════════════════════════════════════════════════════════════
#                     EXISTING INSTALLATION DETECTED
# ═══════════════════════════════════════════════════════════════

selected_action="install"

if [[ -d "$RALPH_DIR" ]]; then
    echo -e "${YELLOW}  Ralph is already installed in this project.${NC}"
    echo ""

    # Show what exists
    echo -e "${GRAY}  Detected files:${NC}"
    echo -e "    ${WHITE}ralph/${NC}  (framework)"
    if [[ -d "$RALPH_DATA_DIR" ]]; then
        local_details=""
        if [[ -d "$RALPH_DATA_DIR/tasks" ]]; then
            sc=$(find "$RALPH_DATA_DIR/tasks" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
            [[ "$sc" -gt 0 ]] && local_details="$sc session(s)"
        fi
        echo -e "    ${WHITE}.ralph/${NC}  (runtime data${local_details:+, $local_details})"
    fi
    if [[ -d "$AGENTS_DIR" ]]; then
        for af in "${RALPH_AGENT_FILES[@]}"; do
            [[ -f "$AGENTS_DIR/$af" ]] && echo -e "    ${WHITE}.github/agents/${af}${NC}" && break
        done
    fi
    [[ -f "$INSTRUCTIONS_DIR/ralph.instructions.md" ]] && echo -e "    ${WHITE}.github/instructions/ralph.instructions.md${NC}"
    [[ -f "$AGENTS_MD_PATH" ]] && grep -qi "ralph" "$AGENTS_MD_PATH" 2>/dev/null && echo -e "    ${WHITE}AGENTS.md${NC}"
    echo ""

    if [[ "$FORCE" == "true" && -n "$ACTION" ]]; then
        selected_action="$ACTION"
    else
        echo -e "${CYAN}  What would you like to do?${NC}"
        echo ""
        echo -e "    ${WHITE}[1] Fresh install${NC}    - Remove all Ralph files, install clean"
        echo -e "                         ${DGRAY}(removes Ralph sessions, cache, memory)${NC}"
        echo -e "                         ${DGRAY}(your project source code is not affected)${NC}"
        echo -e "    ${WHITE}[2] Update Ralph${NC}     - Update framework only, keep your data"
        echo -e "                         ${DGRAY}(preserves sessions, specs, memory)${NC}"
        echo -e "    ${WHITE}[3] Uninstall Ralph${NC}  - Remove all Ralph files from project"
        echo -e "                         ${DGRAY}(only Ralph files, your code is safe)${NC}"
        echo -e "    ${WHITE}[4] Cancel${NC}           - Exit without changes"
        echo ""

        while true; do
            read -rp "  Enter choice (1-4): " choice
            case "$choice" in
                1) selected_action="fresh"; break ;;
                2) selected_action="update"; break ;;
                3) selected_action="uninstall"; break ;;
                4)
                    echo ""
                    echo -e "${GRAY}  Cancelled. No changes made.${NC}"
                    exit 0
                    ;;
                *) echo -e "${RED}  Invalid choice. Enter 1-4.${NC}" ;;
            esac
        done
    fi
fi

# ═══════════════════════════════════════════════════════════════
#                     EXECUTE ACTION
# ═══════════════════════════════════════════════════════════════

case "$selected_action" in

    install)
        install_ralph_from_remote
        set_ralph_source_tracking
        set_ralph_gitignore
        show_install_success

        if [[ "$NO_START" != "true" ]]; then
            echo -e "${CYAN}  Starting Ralph...${NC}"
            sleep 1.5
            clear
            exec "$RALPH_DIR/ralph.sh"
        fi
        ;;

    fresh)
        show_affected_files "will be REMOVED for fresh install" "true"

        if [[ "$FORCE" != "true" ]]; then
            read -rp "  Proceed with fresh install? (yes/[N]o): " confirm
            confirm="${confirm:-n}"
            if [[ ! "$confirm" =~ ^(y|yes)$ ]]; then
                echo -e "${GRAY}  Cancelled. No changes made.${NC}"
                exit 0
            fi
        fi

        echo ""
        echo -e "${YELLOW}  Removing all Ralph files...${NC}"
        remove_ralph_files "true"
        echo ""

        install_ralph_from_remote
        set_ralph_source_tracking
        set_ralph_gitignore
        show_install_success

        if [[ "$NO_START" != "true" ]]; then
            echo -e "${CYAN}  Starting Ralph...${NC}"
            sleep 1.5
            clear
            exec "$RALPH_DIR/ralph.sh"
        fi
        ;;

    update)
        echo -e "${CYAN}  Updating Ralph framework...${NC}"

        # Back up user specs (non-template files)
        specs_backup=""
        if [[ -d "$RALPH_DIR/specs" ]]; then
            user_specs=$(find "$RALPH_DIR/specs" -name "*.md" -not -name "_*" 2>/dev/null)
            if [[ -n "$user_specs" ]]; then
                specs_backup="$(mktemp -d)"
                while IFS= read -r spec; do
                    cp "$spec" "$specs_backup/"
                done <<< "$user_specs"
                spec_count=$(echo "$user_specs" | wc -l | tr -d ' ')
                echo -e "${GRAY}  Backed up $spec_count user spec(s)${NC}"
            fi
        fi

        # Back up config.json
        config_backup=""
        if [[ -f "$RALPH_DIR/config.json" ]]; then
            config_backup="$(mktemp)"
            cp "$RALPH_DIR/config.json" "$config_backup"
            echo -e "${GRAY}  Backed up config.json${NC}"
        fi

        rm -rf "$RALPH_DIR"
        install_ralph_from_remote

        # Restore user specs
        if [[ -n "$specs_backup" && -d "$specs_backup" ]]; then
            restored=0
            for spec in "$specs_backup"/*.md; do
                [[ -f "$spec" ]] || continue
                cp "$spec" "$RALPH_DIR/specs/"
                restored=$((restored + 1))
            done
            rm -rf "$specs_backup"
            [[ $restored -gt 0 ]] && echo -e "${GREEN}  Restored $restored user spec(s)${NC}"
        fi

        # Restore config.json
        if [[ -n "$config_backup" && -f "$config_backup" ]]; then
            cp "$config_backup" "$RALPH_DIR/config.json"
            rm -f "$config_backup"
            echo -e "${GREEN}  Restored config.json${NC}"
        fi

        set_ralph_source_tracking

        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${WHITE}  RALPH UPDATED SUCCESSFULLY!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${GRAY}  Your sessions, memory, and cache are preserved.${NC}"
        echo ""

        if [[ "$NO_START" != "true" ]]; then
            echo -e "${CYAN}  Starting Ralph...${NC}"
            sleep 1.5
            clear
            exec "$RALPH_DIR/ralph.sh"
        fi
        ;;

    uninstall)
        show_affected_files "will be PERMANENTLY REMOVED" "true"

        if [[ "$FORCE" != "true" ]]; then
            echo -e "${GRAY}  Your project source code will NOT be touched.${NC}"
            read -rp "  Type 'uninstall' to confirm: " confirm
            if [[ "$confirm" != "uninstall" ]]; then
                echo -e "${GRAY}  Cancelled. No changes made.${NC}"
                exit 0
            fi
        fi

        echo ""
        echo -e "${YELLOW}  Uninstalling Ralph...${NC}"
        remove_ralph_files "true"

        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${WHITE}  RALPH UNINSTALLED${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${GRAY}  All Ralph files have been removed from this project.${NC}"
        echo -e "${GRAY}  Your project source code is untouched.${NC}"
        echo ""
        echo -e "${GRAY}  To reinstall, run:${NC}"
        echo -e "${CYAN}    curl -fsSL https://raw.githubusercontent.com/niittymaa/Copilot-Ralph/main/install.sh | bash${NC}"
        echo ""
        ;;
esac
