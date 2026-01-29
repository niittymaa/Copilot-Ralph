#!/usr/bin/env bash
# Ralph Loop - Autonomous AI coding agent orchestrator
#
# Auto-detects when planning is needed:
# - Updates AGENTS.md from codebase analysis
# - If no plan exists or plan has no tasks → runs planning first
# - Then proceeds to build mode automatically
#
# Usage: ./ralph.sh [options]
#   -m, --mode         Mode: auto|plan|build|agents|continue (default: auto)
#   -M, --model        AI model to use (e.g., claude-sonnet-4, gpt-4.1)
#   -L, --list-models  List available AI models and exit
#   -n, --max          Max iterations (default: 0=unlimited, runs until complete)
#   -d, --delegate     Delegate to Copilot coding agent
#   --manual           Manual mode (copy/paste prompts)
#   -V, --verbose      Verbose mode (detailed output)
#   -v, --venv         Venv mode: auto|skip|reset (default: auto)
#   -h, --help         Show help

set -euo pipefail

# ═══════════════════════════════════════════════════════════════
#                        CONFIGURATION
# ═══════════════════════════════════════════════════════════════

# Path resolution:
# - CORE_DIR = ralph/core (where this script lives)
# - RALPH_DIR = ralph (parent of core)
# - PROJECT_ROOT = parent of ralph
CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RALPH_DIR="$(dirname "$CORE_DIR")"
PROJECT_ROOT="$(dirname "$RALPH_DIR")"
AGENTS_DIR="$PROJECT_ROOT/.github/agents"

# File paths - ralph files in ralph/ folder, specs at project root

# Options
MODE="auto"
MODEL=""
MAX_ITERATIONS=0
DELEGATE=false
MANUAL=false
VERBOSE=false
VENV_MODE="auto"

# Default model for Ralph
DEFAULT_MODEL="claude-sonnet-4.5"

# Available models with multipliers
declare -a MODEL_NAMES=("claude-sonnet-4.5" "claude-haiku-4.5" "claude-opus-4.5" "claude-sonnet-4" "gpt-5.2-codex" "gpt-5.1-codex-max" "gpt-5.1-codex" "gpt-5.2" "gpt-5.1" "gpt-5" "gpt-5.1-codex-mini" "gpt-5-mini" "gpt-4.1" "gemini-3-pro-preview")
declare -a MODEL_DISPLAYS=("Claude Sonnet 4.5" "Claude Haiku 4.5" "Claude Opus 4.5" "Claude Sonnet 4" "GPT-5.2-Codex" "GPT-5.1-Codex-Max" "GPT-5.1-Codex" "GPT-5.2" "GPT-5.1" "GPT-5" "GPT-5.1-Codex-Mini" "GPT-5 mini" "GPT-4.1" "Gemini 3 Pro (Preview)")
declare -a MODEL_MULTIPLIERS=("1x" "0.33x" "3x" "1x" "1x" "1x" "1x" "1x" "1x" "1x" "0.33x" "0x" "0x" "1x")

# Function to show model selection menu
show_model_menu() {
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  SELECT AI MODEL"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local current_model="${MODEL:-$DEFAULT_MODEL}"
    
    for i in "${!MODEL_NAMES[@]}"; do
        local num=$((i + 1))
        local name="${MODEL_NAMES[$i]}"
        local display="${MODEL_DISPLAYS[$i]}"
        local mult="${MODEL_MULTIPLIERS[$i]}"
        local indicator=""
        local default_tag=""
        local color="${NC}"
        
        [[ "$name" == "$current_model" ]] && indicator=" ✓" && color="${GREEN}"
        [[ "$name" == "$DEFAULT_MODEL" ]] && default_tag=" (Ralph default)"
        
        printf "${color}  [%2d] %-25s %6s%s%s${NC}\n" "$num" "$display" "$mult" "$default_tag" "$indicator"
    done
    
    echo ""
    echo -e "${GRAY}  [Enter] Keep current ($current_model)${NC}"
    echo -e "${GRAY}  [Q] Cancel${NC}"
    echo ""
    
    read -rp "  Select model (1-${#MODEL_NAMES[@]}): " choice
    
    if [[ -z "$choice" ]]; then
        echo "$current_model"
        return
    fi
    
    if [[ "${choice^^}" == "Q" ]]; then
        echo ""
        return
    fi
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#MODEL_NAMES[@]} )); then
        echo "${MODEL_NAMES[$((choice - 1))]}"
        return
    fi
    
    echo "$current_model"
}

# Function to show iteration prompt before building
# Returns: 0=unlimited, -1=cancelled, or positive number for limit
show_iteration_prompt() {
    local pending_tasks="$1"
    
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  BUILD ITERATION SETTINGS"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}  Pending tasks: $pending_tasks${NC}"
    echo ""
    echo -e "${GRAY}  By default, Ralph runs continuously until ALL tasks are completed.${NC}"
    echo ""
    echo -e "${GREEN}  [Enter] Run until complete (unlimited iterations) - RECOMMENDED${NC}"
    echo -e "${YELLOW}  [N]     Specify maximum iteration count${NC}"
    echo -e "${GRAY}  [Q]     Cancel and exit${NC}"
    echo ""
    
    read -rp "  Your choice: " choice
    
    if [[ -z "$choice" ]]; then
        echo ""
        echo -e "${GREEN}  → Running until all tasks complete (unlimited)${NC}"
        echo "0"
        return
    fi
    
    if [[ "${choice^^}" == "Q" ]]; then
        echo "-1"
        return
    fi
    
    if [[ "${choice^^}" == "N" ]]; then
        echo ""
        read -rp "  Enter max iterations (0 = unlimited): " iter_input
        
        if [[ "$iter_input" =~ ^[0-9]+$ ]]; then
            if [[ "$iter_input" -eq 0 ]]; then
                echo -e "${GREEN}  → Running until all tasks complete (unlimited)${NC}"
            else
                echo -e "${YELLOW}  → Maximum $iter_input iteration(s)${NC}"
            fi
            echo "$iter_input"
            return
        else
            echo -e "${YELLOW}  Invalid input. Using unlimited iterations.${NC}"
            echo "0"
            return
        fi
    fi
    
    # Any other input - default to unlimited
    echo -e "${GREEN}  → Running until all tasks complete (unlimited)${NC}"
    echo "0"
}

# Function to list available models
list_models() {
    echo ""
    echo -e "\033[0;36mAvailable AI Models for GitHub Copilot CLI:\033[0m"
    echo ""
    echo -e "\033[1;37m  Anthropic Claude:\033[0m"
    echo -e "\033[0;90m    claude-sonnet-4.5    - Claude Sonnet 4.5 (Ralph default, 1x)\033[0m"
    echo -e "\033[0;90m    claude-sonnet-4      - Claude Sonnet 4 (1x)\033[0m"
    echo -e "\033[0;90m    claude-haiku-4.5     - Claude Haiku 4.5 (0.33x)\033[0m"
    echo -e "\033[0;90m    claude-opus-4.5      - Claude Opus 4.5 (3x)\033[0m"
    echo ""
    echo -e "\033[1;37m  OpenAI GPT:\033[0m"
    echo -e "\033[0;90m    gpt-5.2-codex        - GPT-5.2 Codex (1x)\033[0m"
    echo -e "\033[0;90m    gpt-5.1-codex-max    - GPT-5.1 Codex Max (1x)\033[0m"
    echo -e "\033[0;90m    gpt-5.1-codex        - GPT-5.1 Codex (1x)\033[0m"
    echo -e "\033[0;90m    gpt-5.1-codex-mini   - GPT-5.1 Codex Mini (0.33x)\033[0m"
    echo -e "\033[0;90m    gpt-5.2              - GPT-5.2 (1x)\033[0m"
    echo -e "\033[0;90m    gpt-5.1              - GPT-5.1 (1x)\033[0m"
    echo -e "\033[0;90m    gpt-5                - GPT-5 (1x)\033[0m"
    echo -e "\033[0;90m    gpt-5-mini           - GPT-5 Mini (0x)\033[0m"
    echo -e "\033[0;90m    gpt-4.1              - GPT-4.1 (0x)\033[0m"
    echo ""
    echo -e "\033[1;37m  Google Gemini:\033[0m"
    echo -e "\033[0;90m    gemini-3-pro-preview - Gemini 3 Pro (preview, 1x)\033[0m"
    echo ""
    echo -e "\033[1;33mUsage: ./ralph.sh -M <model-name>\033[0m"
    echo ""
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode) MODE="$2"; shift 2 ;;
        -M|--model) MODEL="$2"; shift 2 ;;
        -L|--list-models) list_models ;;
        -n|--max) MAX_ITERATIONS="$2"; shift 2 ;;
        -d|--delegate) DELEGATE=true; shift ;;
        --manual) MANUAL=true; shift ;;
        -V|--verbose) VERBOSE=true; shift ;;
        --venv) VENV_MODE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: ./ralph.sh [options]"
            echo "  -m, --mode         Mode: auto|plan|build|agents|continue (default: auto)"
            echo "  -M, --model        AI model to use (e.g., claude-sonnet-4, gpt-4.1)"
            echo "  -L, --list-models  List available AI models and exit"
            echo "  -n, --max          Max iterations (default: 0=unlimited)"
            echo "  -d, --delegate     Delegate to Copilot coding agent"
            echo "  --manual           Manual mode (copy/paste prompts)"
            echo "  -V, --verbose      Verbose mode (detailed output)"
            echo "  --venv             Venv mode: auto|skip|reset (default: auto)"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# File paths - ralph files in ralph/ folder, specs at project root
PLAN_FILE="$RALPH_DIR/IMPLEMENTATION_PLAN.md"
PROGRESS_FILE="$RALPH_DIR/progress.txt"
SPECS_DIR="$PROJECT_ROOT/specs"

# Agent files (in .github/agents for Copilot CLI compatibility)
BUILD_AGENT="$AGENTS_DIR/ralph.agent.md"
PLAN_AGENT="$AGENTS_DIR/ralph-planner.agent.md"
SPEC_CREATOR_AGENT="$AGENTS_DIR/ralph-spec-creator.agent.md"
AGENTS_UPDATER_AGENT="$AGENTS_DIR/ralph-agents-updater.agent.md"

# Signals
COMPLETE_SIGNAL='<promise>COMPLETE</promise>'
PLAN_SIGNAL='<promise>PLANNING_COMPLETE</promise>'
SPEC_CREATED_SIGNAL='<promise>SPEC_CREATED</promise>'
AGENTS_UPDATED_SIGNAL='<promise>AGENTS_UPDATED</promise>'

ITERATION=0
SESSION_START=$(date +%s)

# Session statistics tracking
COPILOT_CALLS_TOTAL=0
COPILOT_CALLS_SUCCESSFUL=0
COPILOT_CALLS_FAILED=0
COPILOT_CALLS_CANCELLED=0
COPILOT_TOTAL_DURATION=0
COPILOT_AGENTS_UPDATE_CALLS=0
COPILOT_AGENTS_UPDATE_DURATION=0
COPILOT_PLANNING_CALLS=0
COPILOT_PLANNING_DURATION=0
COPILOT_BUILDING_CALLS=0
COPILOT_BUILDING_DURATION=0
COPILOT_SPEC_CREATION_CALLS=0
COPILOT_SPEC_CREATION_DURATION=0
INITIAL_GIT_STATUS=""
EFFECTIVE_MAX_ITERATIONS=0

# ═══════════════════════════════════════════════════════════════
#                     MODULE INITIALIZATION
# ═══════════════════════════════════════════════════════════════

VENV_SCRIPT="$CORE_DIR/venv.sh"
if [[ -f "$VENV_SCRIPT" ]]; then
    source "$VENV_SCRIPT"
    init_venv_paths "$PROJECT_ROOT"
fi

# Source the spinner module
SPINNER_SCRIPT="$CORE_DIR/spinner.sh"
if [[ -f "$SPINNER_SCRIPT" ]]; then
    source "$SPINNER_SCRIPT"
fi

# Source the tasks module for multi-task support
TASKS_SCRIPT="$CORE_DIR/tasks.sh"
if [[ -f "$TASKS_SCRIPT" ]]; then
    source "$TASKS_SCRIPT"
    initialize_task_paths "$PROJECT_ROOT"
    initialize_task_system
fi

# Source the presets module
PRESETS_SCRIPT="$CORE_DIR/presets.sh"
if [[ -f "$PRESETS_SCRIPT" ]]; then
    source "$PRESETS_SCRIPT"
    initialize_preset_paths "$PROJECT_ROOT"
fi

# ═══════════════════════════════════════════════════════════════
#                         UTILITIES
# ═══════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
MAGENTA='\033[0;35m'
DARK_CYAN='\033[0;36m'
NC='\033[0m'

log() {
    local msg="$1"
    local type="${2:-info}"
    local timestamp=$(date +"%H:%M:%S")
    local color=""
    
    # Skip verbose/debug messages unless verbose mode is enabled
    if [[ "$type" == "verbose" || "$type" == "debug" ]] && [[ "$VERBOSE" != "true" ]]; then
        return
    fi
    
    case "$type" in
        success) color="$GREEN" ;;
        warning) color="$YELLOW" ;;
        error)   color="$RED" ;;
        task)    color="$CYAN" ;;
        verbose) color="$GRAY" ;;
        debug)   color="$DARK_CYAN" ;;
        header)
            echo ""
            echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
            echo -e "${WHITE}  $msg${NC}"
            echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
            return
            ;;
        *)       color="$GRAY" ;;
    esac
    
    local prefix=""
    if [[ "$type" == "verbose" ]]; then
        prefix="  │ "
    elif [[ "$type" == "debug" ]]; then
        prefix="  ▸ "
    fi
    
    echo -e "${color}${prefix}[$timestamp] $msg${NC}"
}

log_verbose() {
    # Writes verbose output (only shown when VERBOSE is enabled)
    local msg="$1"
    local category="${2:-}"
    
    [[ "$VERBOSE" != "true" ]] && return
    
    local prefix=""
    [[ -n "$category" ]] && prefix="[$category] "
    echo -e "${GRAY}  │ ${prefix}$msg${NC}"
}

log_debug() {
    # Writes debug output for raw CLI responses
    local msg="$1"
    local max_lines="${2:-20}"
    
    [[ "$VERBOSE" != "true" ]] && return
    
    local total_lines=$(echo "$msg" | wc -l)
    
    echo -e "${DARK_CYAN}  ┌─ CLI Output ($total_lines lines) ──────────────────────────${NC}"
    
    echo "$msg" | head -n "$max_lines" | while IFS= read -r line; do
        # Truncate long lines
        if [[ ${#line} -gt 70 ]]; then
            line="${line:0:67}..."
        fi
        echo -e "${GRAY}  │ $line${NC}"
    done
    
    if [[ "$total_lines" -gt "$max_lines" ]]; then
        local remaining=$((total_lines - max_lines))
        echo -e "${GRAY}  │ ... ($remaining more lines)${NC}"
    fi
    
    echo -e "${DARK_CYAN}  └──────────────────────────────────────────────────────${NC}"
}

check_copilot_cli() {
    if command -v copilot &> /dev/null; then
        local version=$(copilot --version 2>/dev/null || echo "unknown")
        log "Copilot CLI: $version"
        return 0
    fi
    log "Copilot CLI not found. Install: npm install -g @github/copilot" "error"
    return 1
}

get_current_branch() {
    git branch --show-current 2>/dev/null || echo "unknown"
}

get_task_stats() {
    if [[ ! -f "$PLAN_FILE" ]]; then
        echo "0 0 0"
        return
    fi
    local pending=$(grep -c '^\s*-\s*\[\s*\]' "$PLAN_FILE" 2>/dev/null || echo 0)
    local completed=$(grep -c '^\s*-\s*\[x\]' "$PLAN_FILE" 2>/dev/null || echo 0)
    local total=$((pending + completed))
    echo "$total $completed $pending"
}

get_next_task() {
    [[ ! -f "$PLAN_FILE" ]] && return 1
    grep -m1 '^\s*-\s*\[\s*\]' "$PLAN_FILE" | sed 's/^\s*-\s*\[\s*\]\s*//' || return 1
}

# ═══════════════════════════════════════════════════════════════
#                     SESSION STATISTICS
# ═══════════════════════════════════════════════════════════════

get_git_file_changes() {
    # Gets current git status for file change tracking
    git status --porcelain 2>/dev/null || echo ""
}

get_git_line_stats() {
    # Gets lines added/removed using git diff --numstat
    local lines_added=0
    local lines_removed=0
    
    # Get stats for staged changes
    while IFS=$'\t' read -r added removed file; do
        [[ -z "$added" ]] && continue
        [[ "$added" == "-" ]] && continue  # Binary file
        lines_added=$((lines_added + added))
        lines_removed=$((lines_removed + removed))
    done < <(git diff --cached --numstat 2>/dev/null)
    
    # Get stats for unstaged changes (working directory)
    while IFS=$'\t' read -r added removed file; do
        [[ -z "$added" ]] && continue
        [[ "$added" == "-" ]] && continue  # Binary file
        lines_added=$((lines_added + added))
        lines_removed=$((lines_removed + removed))
    done < <(git diff --numstat 2>/dev/null)
    
    # For untracked files, count all lines as added
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if [[ -f "$file" ]]; then
            local file_lines
            file_lines=$(wc -l < "$file" 2>/dev/null || echo 0)
            lines_added=$((lines_added + file_lines))
        fi
    done < <(git ls-files --others --exclude-standard 2>/dev/null)
    
    echo "$lines_added $lines_removed"
}

initialize_session_stats() {
    # Capture initial git state
    INITIAL_GIT_STATUS=$(get_git_file_changes)
}

update_copilot_stats() {
    # Updates statistics after a Copilot CLI call
    local success="$1"
    local cancelled="${2:-false}"
    local duration="${3:-0}"
    local phase="${4:-Building}"
    
    COPILOT_CALLS_TOTAL=$((COPILOT_CALLS_TOTAL + 1))
    
    if [[ "$success" == "true" ]]; then
        COPILOT_CALLS_SUCCESSFUL=$((COPILOT_CALLS_SUCCESSFUL + 1))
    elif [[ "$cancelled" == "true" ]]; then
        COPILOT_CALLS_CANCELLED=$((COPILOT_CALLS_CANCELLED + 1))
    else
        COPILOT_CALLS_FAILED=$((COPILOT_CALLS_FAILED + 1))
    fi
    
    COPILOT_TOTAL_DURATION=$((COPILOT_TOTAL_DURATION + duration))
    
    case "$phase" in
        AgentsUpdate)
            COPILOT_AGENTS_UPDATE_CALLS=$((COPILOT_AGENTS_UPDATE_CALLS + 1))
            COPILOT_AGENTS_UPDATE_DURATION=$((COPILOT_AGENTS_UPDATE_DURATION + duration))
            ;;
        Planning)
            COPILOT_PLANNING_CALLS=$((COPILOT_PLANNING_CALLS + 1))
            COPILOT_PLANNING_DURATION=$((COPILOT_PLANNING_DURATION + duration))
            ;;
        Building)
            COPILOT_BUILDING_CALLS=$((COPILOT_BUILDING_CALLS + 1))
            COPILOT_BUILDING_DURATION=$((COPILOT_BUILDING_DURATION + duration))
            ;;
        SpecCreation)
            COPILOT_SPEC_CREATION_CALLS=$((COPILOT_SPEC_CREATION_CALLS + 1))
            COPILOT_SPEC_CREATION_DURATION=$((COPILOT_SPEC_CREATION_DURATION + duration))
            ;;
    esac
}

format_duration() {
    # Formats seconds into human-readable string
    local seconds="$1"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [[ $hours -ge 1 ]]; then
        printf "%02d:%02d:%02d" $hours $minutes $secs
    elif [[ $minutes -ge 1 ]]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

get_file_changes() {
    # Calculates file changes since session start
    local current_changes
    current_changes=$(get_git_file_changes)
    
    local created=0
    local modified=0
    local deleted=0
    local created_files=""
    local modified_files=""
    local deleted_files=""
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local status="${line:0:2}"
        local file="${line:3}"
        
        # Skip if this was in initial state (approximate check)
        if echo "$INITIAL_GIT_STATUS" | grep -qF "$line" 2>/dev/null; then
            continue
        fi
        
        case "$status" in
            "A "|\?\?) 
                created=$((created + 1))
                created_files="${created_files}${file}"$'\n'
                ;;
            "D ") 
                deleted=$((deleted + 1))
                deleted_files="${deleted_files}${file}"$'\n'
                ;;
            *) 
                modified=$((modified + 1))
                modified_files="${modified_files}${file}"$'\n'
                ;;
        esac
    done <<< "$current_changes"
    
    echo "$created $modified $deleted"
    echo "$created_files"
    echo "$modified_files"
    echo "$deleted_files"
}

show_session_summary() {
    # Displays comprehensive end-of-session summary
    local iterations="$1"
    local start_time="$2"
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    read -r total completed pending <<< $(get_task_stats)
    
    # Get model display name
    local model_display="$MODEL"
    for i in "${!MODEL_NAMES[@]}"; do
        if [[ "${MODEL_NAMES[$i]}" == "$MODEL" ]]; then
            model_display="${MODEL_DISPLAYS[$i]} (${MODEL_MULTIPLIERS[$i]})"
            break
        fi
    done
    
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  RALPH SESSION SUMMARY${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Session Overview
    echo -e "${CYAN}  SESSION OVERVIEW${NC}"
    echo -e "${GRAY}  ─────────────────────────────────────────────────────────────${NC}"
    echo -e "${WHITE}  Model:           ${GREEN}$model_display${NC}"
    echo -e "${WHITE}  Mode:            ${YELLOW}$MODE${NC}"
    echo -e "${WHITE}  Start Time:      ${GRAY}$(date -d "@$start_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$start_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")${NC}"
    echo -e "${WHITE}  End Time:        ${GRAY}$(date "+%Y-%m-%d %H:%M:%S")${NC}"
    echo -e "${WHITE}  Total Duration:  ${CYAN}$(format_duration $total_duration)${NC}"
    echo ""
    
    # Task Progress
    echo -e "${CYAN}  TASK PROGRESS${NC}"
    echo -e "${GRAY}  ─────────────────────────────────────────────────────────────${NC}"
    local iter_limit
    if [[ "$EFFECTIVE_MAX_ITERATIONS" -eq 0 ]]; then
        iter_limit="unlimited"
    else
        iter_limit="of $EFFECTIVE_MAX_ITERATIONS"
    fi
    echo -e "${WHITE}  Build Iterations:${YELLOW} $iterations ${GRAY}($iter_limit)${NC}"
    local task_color="${GREEN}"
    local task_suffix=" (all complete!)"
    if [[ $pending -gt 0 ]]; then
        task_color="${YELLOW}"
        task_suffix=" ($pending remaining)"
    fi
    echo -e "${WHITE}  Tasks Completed: ${task_color}$completed/$total${task_suffix}${NC}"
    echo ""
    
    # Copilot CLI Statistics
    echo -e "${CYAN}  COPILOT CLI CALLS${NC}"
    echo -e "${GRAY}  ─────────────────────────────────────────────────────────────${NC}"
    echo -e "${WHITE}  Total Calls:     ${YELLOW}$COPILOT_CALLS_TOTAL${NC}"
    echo -e "${WHITE}  Successful:      ${GREEN}$COPILOT_CALLS_SUCCESSFUL${NC}"
    if [[ $COPILOT_CALLS_FAILED -gt 0 ]]; then
        echo -e "${WHITE}  Failed:          ${RED}$COPILOT_CALLS_FAILED${NC}"
    fi
    if [[ $COPILOT_CALLS_CANCELLED -gt 0 ]]; then
        echo -e "${WHITE}  Cancelled:       ${YELLOW}$COPILOT_CALLS_CANCELLED${NC}"
    fi
    echo -e "${WHITE}  AI Time:         ${CYAN}$(format_duration $COPILOT_TOTAL_DURATION)${NC}"
    
    # Phase breakdown if there were multiple phases
    local active_phases=0
    [[ $COPILOT_AGENTS_UPDATE_CALLS -gt 0 ]] && active_phases=$((active_phases + 1))
    [[ $COPILOT_PLANNING_CALLS -gt 0 ]] && active_phases=$((active_phases + 1))
    [[ $COPILOT_BUILDING_CALLS -gt 0 ]] && active_phases=$((active_phases + 1))
    [[ $COPILOT_SPEC_CREATION_CALLS -gt 0 ]] && active_phases=$((active_phases + 1))
    
    if [[ $active_phases -gt 1 ]]; then
        echo ""
        echo -e "${GRAY}  Phase Breakdown:${NC}"
        if [[ $COPILOT_AGENTS_UPDATE_CALLS -gt 0 ]]; then
            echo -e "${WHITE}    AgentsUpdate: ${GRAY}$COPILOT_AGENTS_UPDATE_CALLS call(s), $(format_duration $COPILOT_AGENTS_UPDATE_DURATION)${NC}"
        fi
        if [[ $COPILOT_PLANNING_CALLS -gt 0 ]]; then
            echo -e "${WHITE}    Planning: ${GRAY}$COPILOT_PLANNING_CALLS call(s), $(format_duration $COPILOT_PLANNING_DURATION)${NC}"
        fi
        if [[ $COPILOT_BUILDING_CALLS -gt 0 ]]; then
            echo -e "${WHITE}    Building: ${GRAY}$COPILOT_BUILDING_CALLS call(s), $(format_duration $COPILOT_BUILDING_DURATION)${NC}"
        fi
        if [[ $COPILOT_SPEC_CREATION_CALLS -gt 0 ]]; then
            echo -e "${WHITE}    SpecCreation: ${GRAY}$COPILOT_SPEC_CREATION_CALLS call(s), $(format_duration $COPILOT_SPEC_CREATION_DURATION)${NC}"
        fi
    fi
    echo ""
    
    # File Changes
    echo -e "${CYAN}  FILE CHANGES${NC}"
    echo -e "${GRAY}  ─────────────────────────────────────────────────────────────${NC}"
    
    local file_info
    file_info=$(get_file_changes)
    local counts
    counts=$(echo "$file_info" | head -n1)
    read -r created_count modified_count deleted_count <<< "$counts"
    
    # Get line-level statistics
    local line_stats
    line_stats=$(get_git_line_stats)
    read -r lines_added lines_removed <<< "$line_stats"
    
    local total_changes=$((created_count + modified_count + deleted_count))
    
    if [[ $total_changes -eq 0 ]] && [[ $lines_added -eq 0 ]] && [[ $lines_removed -eq 0 ]]; then
        echo -e "${GRAY}  No file changes detected${NC}"
    else
        # Show line-level statistics
        echo -e "${WHITE}  Total code changes:${NC} ${GREEN}$lines_added lines added${NC}, ${RED}$lines_removed lines removed${NC}"
        
        if [[ $created_count -gt 0 ]]; then
            echo -e "${WHITE}  Created:         ${GREEN}$created_count file(s)${NC}"
        fi
        if [[ $modified_count -gt 0 ]]; then
            echo -e "${WHITE}  Modified:        ${YELLOW}$modified_count file(s)${NC}"
        fi
        if [[ $deleted_count -gt 0 ]]; then
            echo -e "${WHITE}  Deleted:         ${RED}$deleted_count file(s)${NC}"
        fi
    fi
    echo ""
    
    # Final status bar
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    if [[ $pending -eq 0 ]] && [[ $total -gt 0 ]]; then
        echo -e "  ${GREEN}✓ ALL TASKS COMPLETED SUCCESSFULLY${NC}"
    elif [[ $completed -gt 0 ]]; then
        echo -e "  ${YELLOW}◐ SESSION ENDED - Progress saved, $pending tasks remaining${NC}"
    else
        echo -e "  ${GRAY}○ SESSION ENDED${NC}"
    fi
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

get_user_specs() {
    # Returns user spec files (excludes templates starting with _)
    [[ ! -d "$SPECS_DIR" ]] && return
    find "$SPECS_DIR" -maxdepth 1 -name "*.md" ! -name "_*" -type f 2>/dev/null
}

has_user_specs() {
    local specs
    specs=$(get_user_specs)
    [[ -n "$specs" ]]
}

show_main_menu() {
    # Shows when project has pending tasks - allows continuing or adding new specs
    read -r total completed pending <<< $(get_task_stats)
    local user_specs
    user_specs=$(get_user_specs)
    local spec_count=0
    if [[ -n "$user_specs" ]]; then
        spec_count=$(echo "$user_specs" | wc -l)
    fi
    
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  RALPH - PROJECT MENU${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}  Project Status:${NC}"
    echo -e "${GRAY}    • Specs: $spec_count specification(s)${NC}"
    echo -e "${GRAY}    • Tasks: $pending pending, $completed completed${NC}"
    echo ""
    echo -e "${GREEN}  [1] Continue building (use existing specs)${NC}"
    echo -e "${YELLOW}  [2] Add new spec to project${NC}"
    echo -e "${CYAN}  [3] Start fresh (reset plan and progress)${NC}"
    echo -e "${RED}  [Q] Quit${NC}"
    echo ""
    
    read -rp "  Select option (1/2/3/Q): " choice
    
    case "${choice^^}" in
        1) echo "continue" ;;
        2) echo "add-spec" ;;
        3) echo "start-fresh" ;;
        Q) echo "quit" ;;
        *) echo "continue" ;;
    esac
}

show_spec_menu() {
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  RALPH - SPECIFICATION SETUP${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local user_specs
    user_specs=$(get_user_specs)
    
    if [[ -n "$user_specs" ]]; then
        echo -e "${CYAN}  Found existing specifications:${NC}"
        while IFS= read -r spec; do
            echo -e "${GRAY}    • $(basename "$spec")${NC}"
        done <<< "$user_specs"
        echo ""
        echo -e "${GREEN}  [1] Use existing specs${NC}"
        echo -e "${YELLOW}  [2] Create new spec with Ralph${NC}"
        echo -e "${RED}  [Q] Quit${NC}"
        echo ""
        
        read -rp "  Select option (1/2/Q): " choice
        
        case "${choice^^}" in
            1) echo "use-existing" ;;
            2) echo "create-new" ;;
            Q) echo "quit" ;;
            *) echo "use-existing" ;;
        esac
    else
        echo -e "${YELLOW}  No specifications found in specs/${NC}"
        echo -e "${GRAY}  (Files starting with _ are templates and ignored)${NC}"
        echo ""
        echo -e "${GREEN}  [1] Create spec with Ralph (interview mode)${NC}"
        echo -e "${YELLOW}  [2] Quick spec (describe in one prompt)${NC}"
        echo -e "${RED}  [Q] Quit${NC}"
        echo ""
        
        read -rp "  Select option (1/2/Q): " choice
        
        case "${choice^^}" in
            1) echo "interview" ;;
            2) echo "quick" ;;
            Q) echo "quit" ;;
            *) echo "interview" ;;
        esac
    fi
}

invoke_spec_creation() {
    local spec_mode="${1:-interview}"
    
    log "SPEC CREATION MODE [$MODE]" "header"
    
    if [[ ! -f "$SPEC_CREATOR_AGENT" ]]; then
        log "Spec creator agent not found: $SPEC_CREATOR_AGENT" "error"
        return 1
    fi
    
    local agent_prompt
    agent_prompt=$(get_agent_prompt "$SPEC_CREATOR_AGENT") || return 1
    
    local full_prompt
    
    if [[ "$spec_mode" == "quick" ]]; then
        echo ""
        echo -e "${CYAN}  Describe what you want to build in one prompt.${NC}"
        echo -e "${GRAY}  Ralph will generate a complete specification from your description.${NC}"
        echo ""
        echo -e "${GRAY}  Example: 'A REST API for user authentication with JWT tokens,${NC}"
        echo -e "${GRAY}           password hashing, and role-based access control'${NC}"
        echo ""
        
        read -rp "  Your description: " description
        
        if [[ -z "$description" ]]; then
            log "No description provided. Aborting." "warning"
            return 1
        fi
        
        full_prompt="$agent_prompt

## User Request (One-Shot Mode)

The user has provided this description. Generate a complete specification from it:

$description

Create the spec file immediately without asking questions. Extract all requirements from the description above."
    else
        # Interactive interview mode - AI asks questions dynamically
        echo ""
        echo -e "${CYAN}  Interactive Interview Mode${NC}"
        echo -e "${GRAY}  Ralph will ask you questions to understand what you want to build.${NC}"
        echo -e "${GRAY}  Type 'done' when you've provided enough information.${NC}"
        echo ""
        
        read -rp "  What do you want to build? " initial_idea
        
        if [[ -z "$initial_idea" ]]; then
            log "No idea provided. Aborting." "warning"
            return 1
        fi
        
        # Build conversation history
        local conversation="User: $initial_idea"
        local max_questions=5
        local question_count=0
        
        while [[ $question_count -lt $max_questions ]]; do
            ((question_count++))
            
            # Ask AI for next question based on conversation so far
            local question_prompt="You are helping create a software specification. Based on the conversation so far, ask ONE focused clarifying question to better understand the requirements. Keep questions short and specific.

Conversation so far:
$conversation

If you have enough information to create a good specification, respond with exactly: READY_TO_CREATE

Otherwise, ask your next question (just the question, no preamble):"
            
            log "Thinking..." "info"
            local ai_response
            ai_response=$(invoke_copilot "$question_prompt" "Copilot is working..." "SpecCreation")
            
            # Check if AI has enough info
            if [[ "$ai_response" == *"READY_TO_CREATE"* ]]; then
                echo ""
                echo -e "${GREEN}  Ralph has enough information to create your specification.${NC}"
                break
            fi
            
            # Display AI's question
            echo ""
            echo -e "${CYAN}  Ralph: $ai_response${NC}"
            
            # Get user's answer
            read -rp "  You: " user_answer
            
            # Check for done signal
            if [[ "$user_answer" =~ ^done$ ]] || [[ "$user_answer" =~ ^q$ ]] || [[ -z "$user_answer" ]]; then
                echo ""
                echo -e "${GRAY}  Proceeding to create specification...${NC}"
                break
            fi
            
            # Add to conversation
            conversation+=$'\n'"Ralph: $ai_response"
            conversation+=$'\n'"User: $user_answer"
        done
        
        full_prompt="$agent_prompt

## User Request (Interview Summary)

The user has described what they want to build through this conversation:

$conversation

Create the spec file immediately. Use all information from the conversation above."
    fi
    
    if [[ "$MANUAL" == "true" ]]; then
        log "Copy this prompt to Copilot Chat:" "warning"
        echo ""
        echo "────────────────────────────────────────────────────────────"
        echo "$full_prompt"
        echo "────────────────────────────────────────────────────────────"
        echo ""
        log "Press ENTER when spec creation is complete" "warning"
        read -r
        return 0
    fi
    
    log "Starting spec creation..."
    
    local output
    output=$(invoke_copilot "$full_prompt" "Copilot is working..." "SpecCreation")
    
    if [[ "$output" == *"$SPEC_CREATED_SIGNAL"* ]]; then
        log "Specification created!" "success"
    fi
    
    # Verify spec was created
    if has_user_specs; then
        local count
        count=$(get_user_specs | wc -l)
        log "Specs available: $count" "success"
        return 0
    else
        log "No spec files found after creation." "warning"
        return 1
    fi
}

needs_planning() {
    # Check if user specs exist (not templates)
    if ! has_user_specs; then
        log "No user specs found in specs/. Create specifications first." "warning"
        return 1
    fi
    
    read -r total completed pending <<< $(get_task_stats)
    [[ "$pending" -eq 0 ]]
}

ensure_progress_file() {
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        cat > "$PROGRESS_FILE" << 'EOF'
# Ralph Progress Log

## Codebase Patterns
(Add reusable patterns here)

---
EOF
        echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$PROGRESS_FILE"
        log "Created progress.txt"
    fi
}

ensure_plan_file() {
    if [[ ! -f "$PLAN_FILE" ]]; then
        cat > "$PLAN_FILE" << 'EOF'
# Implementation Plan

## Tasks

(No tasks yet - planning phase will populate this)

---
EOF
        echo "Created: $(date '+%Y-%m-%d %H:%M:%S')" >> "$PLAN_FILE"
        log "Created IMPLEMENTATION_PLAN.md"
    fi
}

ensure_ralph_instructions() {
    local instructions_dir="$PROJECT_ROOT/.github/instructions"
    local ralph_instructions="$instructions_dir/ralph.instructions.md"
    
    if [[ ! -f "$ralph_instructions" ]]; then
        # Ensure directories exist
        mkdir -p "$instructions_dir"
        
        # Copy from template or create inline
        local template_path="$RALPH_DIR/templates/ralph.instructions.md"
        if [[ -f "$template_path" ]]; then
            cp "$template_path" "$ralph_instructions"
        else
            cat > "$ralph_instructions" << 'EOF'
---
description: 'Ralph orchestrator instructions - AI coding agent configuration'
applyTo: '**/*'
---

# Ralph Instructions

This project uses Ralph - an autonomous AI coding agent orchestrator.

## Completion Patterns

- `<promise>COMPLETE</promise>` - Task completed
- `<promise>PLANNING_COMPLETE</promise>` - Planning phase done
- `<promise>SPEC_CREATED</promise>` - Specification created

## Task Format

- Pending: `- [ ] Task description`
- Complete: `- [x] Task description`
EOF
        fi
        log "Created .github/instructions/ralph.instructions.md"
    fi
}

reset_ralph_state() {
    # Resets Ralph state files for a fresh start
    log "Resetting Ralph state for fresh start..."
    
    # Reset progress file
    cat > "$PROGRESS_FILE" << 'EOF'
# Ralph Progress Log

## Codebase Patterns
(Add reusable patterns here)

---
EOF
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$PROGRESS_FILE"
    log "Reset progress.txt"
    
    # Reset plan file
    cat > "$PLAN_FILE" << 'EOF'
# Implementation Plan

## Tasks

(No tasks yet - planning phase will populate this)

---
EOF
    echo "Created: $(date '+%Y-%m-%d %H:%M:%S')" >> "$PLAN_FILE"
    log "Reset IMPLEMENTATION_PLAN.md"
    
    log "State reset complete. Ready for fresh start!" "success"
}

get_agent_prompt() {
    local agent_path="$1"
    [[ ! -f "$agent_path" ]] && return 1
    
    log_verbose "Loading agent: $agent_path" "Agent"
    
    local content=$(cat "$agent_path")
    # Strip YAML frontmatter
    if [[ "$content" =~ ^--- ]]; then
        content=$(echo "$content" | sed '1{/^---$/d}' | sed '1,/^---$/d')
    fi
    
    log_verbose "Prompt length: ${#content} chars" "Agent"
    echo "$content"
}

# Build task-injected prompt for build agent
# Args: $1 = base_prompt, $2 = task
# Returns: Combined prompt with task injection
build_task_prompt() {
    local base_prompt="$1"
    local task="$2"
    
    # Validate inputs
    if [[ -z "$base_prompt" ]]; then
        log "Error: Base prompt is empty" "error"
        return 1
    fi
    
    if [[ -z "$task" ]]; then
        log "Error: Task is empty" "error"
        return 1
    fi
    
    # Build the combined prompt with task injection
    local task_prompt="$base_prompt

## YOUR ASSIGNED TASK FOR THIS ITERATION

**DO NOT search for tasks in IMPLEMENTATION_PLAN.md.** Your task has already been selected for you:

\`\`\`
$task
\`\`\`

Focus ONLY on implementing this specific task. When complete, mark it as done in the plan and update progress.txt."
    
    log_verbose "Task prompt built: ${#task_prompt} chars (task: ${task:0:50}...)" "Agent"
    echo "$task_prompt"
}

invoke_copilot() {
    local prompt="$1"
    local spinner_message="${2:-Copilot is working...}"
    local phase="${3:-Building}"
    local model_info=""
    if [[ -n "$MODEL" ]]; then
        model_info=" (model: $MODEL)"
    fi
    
    log_verbose "Prompt preview: ${prompt:0:100}..." "Copilot"
    
    local cli_args=(-p "$prompt" --allow-all-tools)
    if [[ -n "$MODEL" ]]; then
        cli_args+=(--model "$MODEL")
    fi
    
    log_verbose "CLI args: copilot ${cli_args[*]:0:3}..." "Copilot"
    
    local start_time=$(date +%s)
    local output
    local success=true
    
    # Use spinner in non-verbose mode
    if [[ "$VERBOSE" == "true" ]]; then
        # Verbose mode - stream output directly with elapsed time indicator
        log "Invoking Copilot CLI$model_info..."
        echo -e "${DARK_CYAN}  ┌─ Live Output ───────────────────────────────────────────${NC}"
        
        # Run copilot in background and stream output with time updates
        local temp_output=$(mktemp)
        local last_time_update=$start_time
        
        # Start copilot in background
        copilot "${cli_args[@]}" > "$temp_output" 2>&1 &
        local copilot_pid=$!
        
        # Monitor and display output with elapsed time
        local last_line_count=0
        while kill -0 "$copilot_pid" 2>/dev/null; do
            local now=$(date +%s)
            local elapsed=$((now - start_time))
            
            # Show elapsed time every 10 seconds
            if [[ $((now - last_time_update)) -ge 10 ]]; then
                local mins=$((elapsed / 60))
                local secs=$((elapsed % 60))
                printf -v time_str "%02d:%02d" $mins $secs
                echo -e "${DARK_CYAN}  │ ⏱️  Elapsed: ${time_str}${NC}" >&2
                last_time_update=$now
            fi
            
            # Read and display new lines
            local current_lines=$(wc -l < "$temp_output")
            if [[ $current_lines -gt $last_line_count ]]; then
                tail -n $((current_lines - last_line_count)) "$temp_output" | while IFS= read -r line; do
                    echo -e "${GRAY}  │ $line${NC}" >&2
                done
                last_line_count=$current_lines
            fi
            
            sleep 0.1
        done
        
        # Wait for process to finish and get exit status
        wait "$copilot_pid" || success=false
        
        # Display any remaining output
        local final_lines=$(wc -l < "$temp_output")
        if [[ $final_lines -gt $last_line_count ]]; then
            tail -n $((final_lines - last_line_count)) "$temp_output" | while IFS= read -r line; do
                echo -e "${GRAY}  │ $line${NC}" >&2
            done
        fi
        
        output=$(cat "$temp_output")
        rm -f "$temp_output"
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${DARK_CYAN}  └─ Completed in ${duration}s ────────────────────────────────${NC}"
    else
        # Normal mode - use spinner if available
        if type start_spinner &>/dev/null; then
            start_spinner "$spinner_message"
            output=$(copilot "${cli_args[@]}" 2>&1) || success=false
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            stop_spinner "Completed in ${duration}s" $success
        else
            log "Invoking Copilot CLI$model_info..."
            output=$(copilot "${cli_args[@]}" 2>&1 | tee /dev/stderr) || success=false
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_verbose "Duration: ${duration}s" "Copilot"
    log_verbose "Output length: ${#output} chars" "Copilot"
    
    # Update statistics
    if [[ "$success" == "true" ]]; then
        update_copilot_stats "true" "false" "$duration" "$phase"
    else
        update_copilot_stats "false" "false" "$duration" "$phase"
    fi
    
    echo "$output"
}

# ═══════════════════════════════════════════════════════════════
#                     AGENTS.MD UPDATE PHASE
# ═══════════════════════════════════════════════════════════════

invoke_agents_update() {
    log "AGENTS.MD UPDATE PHASE [$MODE]" "header"
    
    if [[ ! -f "$AGENTS_UPDATER_AGENT" ]]; then
        log "Agents updater not found: $AGENTS_UPDATER_AGENT" "warning"
        return 1
    fi
    
    local agent_prompt
    agent_prompt=$(get_agent_prompt "$AGENTS_UPDATER_AGENT") || return 1
    
    log "Analyzing codebase and updating AGENTS.md..."
    
    if [[ "$MANUAL" == "true" ]]; then
        log "Copy this prompt to Copilot Chat:" "warning"
        echo ""
        echo "────────────────────────────────────────────────────────────"
        echo "$agent_prompt"
        echo "────────────────────────────────────────────────────────────"
        echo ""
        log "Press ENTER when AGENTS.md update complete" "warning"
        read -r
        return 0
    fi
    
    local output
    output=$(invoke_copilot "$agent_prompt" "Copilot is working..." "AgentsUpdate")
    
    if [[ "$output" == *"$AGENTS_UPDATED_SIGNAL"* ]]; then
        log "AGENTS.md updated!" "success"
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════════
#                        PLANNING PHASE
# ═══════════════════════════════════════════════════════════════

invoke_planning() {
    log "PLANNING PHASE [$MODE]" "header"
    
    if [[ ! -f "$PLAN_AGENT" ]]; then
        log "Planning agent not found: $PLAN_AGENT" "error"
        return 1
    fi
    
    local agent_prompt
    agent_prompt=$(get_agent_prompt "$PLAN_AGENT") || return 1
    
    log "Analyzing specs and creating implementation plan..."
    
    if [[ "$MANUAL" == "true" ]]; then
        log "Copy this prompt to Copilot Chat:" "warning"
        echo ""
        echo "────────────────────────────────────────────────────────────"
        echo "$agent_prompt"
        echo "────────────────────────────────────────────────────────────"
        echo ""
        log "Press ENTER when planning complete" "warning"
        read -r
        return 0
    fi
    
    local output
    output=$(invoke_copilot "$agent_prompt" "Copilot is working..." "Planning")
    
    if [[ "$output" == *"$PLAN_SIGNAL"* ]]; then
        log "Planning complete!" "success"
    fi
    
    read -r total completed pending <<< $(get_task_stats)
    if [[ "$pending" -gt 0 ]]; then
        log "Created $pending tasks" "success"
        return 0
    else
        log "No tasks created. Check specs/ for valid specifications." "warning"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
#                        BUILDING PHASE
# ═══════════════════════════════════════════════════════════════

invoke_building() {
    log "BUILDING PHASE" "header"
    
    local agent_path="$BUILD_AGENT"
    if [[ ! -f "$agent_path" ]]; then
        log "Build agent not found: $agent_path" "error"
        return 1
    fi
    
    local agent_prompt
    agent_prompt=$(get_agent_prompt "$agent_path") || return 1
    
    read -r total completed pending <<< $(get_task_stats)
    log "Tasks: $pending pending, $completed/$total complete"
    
    # Prompt for iteration settings before starting
    local effective_max_iterations
    effective_max_iterations=$(show_iteration_prompt "$pending" | tail -1)
    EFFECTIVE_MAX_ITERATIONS=$effective_max_iterations
    
    if [[ "$effective_max_iterations" == "-1" ]]; then
        log "Build cancelled by user."
        return 0
    fi
    
    echo ""
    
    while true; do
        # Check iteration limit
        if [[ "$effective_max_iterations" -gt 0 ]] && [[ "$ITERATION" -ge "$effective_max_iterations" ]]; then
            log "Reached max iterations: $effective_max_iterations" "warning"
            break
        fi
        
        ITERATION=$((ITERATION + 1))
        
        # Get current task
        local task
        task=$(get_next_task) || {
            log "All tasks completed!" "success"
            break
        }
        
        log "BUILD ITERATION $ITERATION [$MODE]" "header"
        log "Task: $task" "task"
        
        # Handle delegate mode
        if [[ "$DELEGATE" == "true" ]]; then
            copilot -p "/delegate $task" 2>&1 | tee /dev/stderr
            log "Delegated to Copilot coding agent. Check GitHub for PR." "success"
            break
        fi
        
        # Build task-injected prompt (used by both manual and programmatic modes)
        local task_prompt
        task_prompt=$(build_task_prompt "$agent_prompt" "$task") || {
            log "Failed to build task prompt" "error"
            break
        }
        
        # Manual mode
        if [[ "$MANUAL" == "true" ]]; then
            log "Copy this prompt to Copilot Chat:" "warning"
            echo ""
            echo "────────────────────────────────────────────────────────────"
            echo "$task_prompt"
            echo "────────────────────────────────────────────────────────────"
            echo ""
            log "Press ENTER when task complete, 'q' to quit" "warning"
            read -r user_input
            [[ "$user_input" == "q" ]] && break
            continue
        fi
        
        # Programmatic mode
        local output
        output=$(invoke_copilot "$task_prompt" "Copilot is working..." "Building")
        
        if [[ "$output" == *"$COMPLETE_SIGNAL"* ]]; then
            log "ALL TASKS COMPLETED!" "success"
            break
        fi
        
        sleep 2
    done
}

# ═══════════════════════════════════════════════════════════════
#                        MAIN ENTRY
# ═══════════════════════════════════════════════════════════════

main() {
    # Set default model if not specified
    if [[ -z "$MODEL" ]]; then
        MODEL="$DEFAULT_MODEL"
    fi
    
    local mode_text
    case "$MODE" in
        auto)     mode_text="AUTO (agents, plan if needed, then build)" ;;
        continue) mode_text="CONTINUE PROJECT" ;;
        plan)     mode_text="PLAN ONLY" ;;
        build)    mode_text="BUILD ONLY" ;;
        agents)   mode_text="AGENTS.MD UPDATE ONLY" ;;
        *)        echo "Invalid mode: $MODE"; exit 1 ;;
    esac
    
    log "RALPH LOOP - $mode_text" "header"
    
    check_copilot_cli || exit 1
    
    local branch=$(get_current_branch)
    echo -e "${WHITE}  Branch: $branch${NC}"
    local iter_display
    if [[ "$MAX_ITERATIONS" -eq 0 ]]; then
        iter_display="unlimited (until complete)"
    else
        iter_display="$MAX_ITERATIONS"
    fi
    echo -e "${WHITE}  Max iterations: $iter_display${NC}"
    
    # Find model display info
    local model_display="$MODEL"
    local model_mult=""
    for i in "${!MODEL_NAMES[@]}"; do
        if [[ "${MODEL_NAMES[$i]}" == "$MODEL" ]]; then
            model_display="${MODEL_DISPLAYS[$i]}"
            model_mult=" (${MODEL_MULTIPLIERS[$i]})"
            break
        fi
    done
    echo -e "  Model: ${GREEN}${model_display}${model_mult}${NC} ${GRAY}[M to change]${NC}"
    
    # Show verbose mode status with toggle option
    echo -n -e "  Verbose: "
    if [[ "$VERBOSE" == "true" ]]; then
        echo -n -e "${CYAN}ON${NC}"
    else
        echo -n -e "${GRAY}OFF${NC}"
    fi
    echo -e " ${GRAY}[V to toggle]${NC}"
    
    # Setup Python venv isolation
    if [[ "$VENV_MODE" != "skip" ]]; then
        if [[ -f "$VENV_SCRIPT" ]]; then
            echo -e "${WHITE}  Venv mode: $VENV_MODE${NC}"
            
            if [[ "$VENV_MODE" == "reset" ]]; then
                remove_ralph_venv >/dev/null 2>&1 || true
            fi
            
            if enable_ralph_venv; then
                echo -e "${GREEN}  Venv: ACTIVE${NC}"
            else
                echo -e "${YELLOW}  Venv: Not available (Python not found)${NC}"
            fi
        else
            echo -e "${YELLOW}  Venv: Module not found${NC}"
        fi
    else
        echo -e "${YELLOW}  Venv: SKIPPED${NC}"
    fi
    
    echo ""
    echo -e "${GRAY}  Press [M] to change model, [V] to toggle verbose, or [Enter] to continue...${NC}"
    
    # Loop to allow multiple changes before continuing
    while true; do
        read -rsn1 key
        
        if [[ "$key" == "m" ]] || [[ "$key" == "M" ]]; then
            local new_model
            new_model=$(show_model_menu)
            if [[ -z "$new_model" ]]; then
                log "Cancelled."
                return
            fi
            MODEL="$new_model"
            log "Model set to: $MODEL" "success"
            echo ""
            echo -e "${GRAY}  Press [M] to change model, [V] to toggle verbose, or [Enter] to continue...${NC}"
        elif [[ "$key" == "v" ]] || [[ "$key" == "V" ]]; then
            # Toggle verbose mode
            if [[ "$VERBOSE" == "true" ]]; then
                VERBOSE=false
                log "Verbose mode: OFF" "info"
            else
                VERBOSE=true
                log "Verbose mode: ON" "success"
            fi
            echo ""
            echo -e "${GRAY}  Press [M] to change model, [V] to toggle verbose, or [Enter] to continue...${NC}"
        elif [[ "$key" == "" ]]; then
            # Enter key - continue
            break
        fi
        # Ignore other keys
    done
    echo ""
    
    # Initialize required files if missing
    ensure_ralph_instructions
    ensure_progress_file
    ensure_plan_file
    
    # Initialize session statistics tracking
    initialize_session_stats
    
    # Determine which menu to show based on mode and project state
    if [[ "$MODE" == "auto" ]]; then
        read -r total completed pending <<< $(get_task_stats)
        
        if has_user_specs && [[ "$pending" -gt 0 ]]; then
            # Has specs AND has pending tasks - show main menu with continue option
            local main_choice
            main_choice=$(show_main_menu)
            
            case "$main_choice" in
                quit)
                    log "Exiting Ralph."
                    return
                    ;;
                add-spec)
                    # User wants to add new spec to existing project
                    echo ""
                    echo -e "${GREEN}  [1] Interview mode (Ralph asks questions)${NC}"
                    echo -e "${YELLOW}  [2] Quick mode (describe in one prompt)${NC}"
                    echo ""
                    read -rp "  Select mode (1/2): " sub_choice
                    
                    local spec_mode="interview"
                    [[ "$sub_choice" == "2" ]] && spec_mode="quick"
                    
                    if ! invoke_spec_creation "$spec_mode"; then
                        log "Spec creation did not complete. Exiting." "warning"
                        return
                    fi
                    ;;
                start-fresh)
                    # Reset state and start new project
                    echo ""
                    echo -e "${YELLOW}  This will reset IMPLEMENTATION_PLAN.md and progress.txt${NC}"
                    echo -e "${GRAY}  Your specs in specs/*.md will NOT be deleted.${NC}"
                    echo ""
                    read -rp "  Are you sure? (yes/[N]o): " confirm
                    [[ -z "$confirm" ]] && confirm="n"
                    if [[ ! "$confirm" =~ ^(y|yes|Y|Yes|YES)$ ]]; then
                        log "Cancelled. Exiting."
                        return
                    fi
                    reset_ralph_state
                    # After reset, proceed to spec menu for new project setup
                    local menu_choice
                    menu_choice=$(show_spec_menu)
                    case "$menu_choice" in
                        quit) log "Exiting Ralph."; return ;;
                        create-new)
                            echo ""
                            echo -e "${GREEN}  [1] Interview mode (Ralph asks questions)${NC}"
                            echo -e "${YELLOW}  [2] Quick mode (describe in one prompt)${NC}"
                            echo ""
                            read -rp "  Select mode (1/2): " sub_choice
                            local spec_mode="interview"
                            [[ "$sub_choice" == "2" ]] && spec_mode="quick"
                            if ! invoke_spec_creation "$spec_mode"; then
                                log "Spec creation did not complete. Exiting." "warning"
                                return
                            fi
                            ;;
                        interview)
                            if ! invoke_spec_creation "interview"; then
                                log "Spec creation did not complete. Exiting." "warning"
                                return
                            fi
                            ;;
                        quick)
                            if ! invoke_spec_creation "quick"; then
                                log "Spec creation did not complete. Exiting." "warning"
                                return
                            fi
                            ;;
                        use-existing)
                            log "Using existing specifications for fresh build."
                            ;;
                    esac
                    ;;
                continue)
                    log "Continuing with existing specifications."
                    ;;
            esac
        else
            # No specs OR no pending tasks - show spec menu
            local menu_choice
            menu_choice=$(show_spec_menu)
            
            case "$menu_choice" in
                quit)
                    log "Exiting Ralph."
                    return
                    ;;
                create-new)
                    echo ""
                    echo -e "${GREEN}  [1] Interview mode (Ralph asks questions)${NC}"
                    echo -e "${YELLOW}  [2] Quick mode (describe in one prompt)${NC}"
                    echo ""
                    read -rp "  Select mode (1/2): " sub_choice
                    
                    local spec_mode="interview"
                    [[ "$sub_choice" == "2" ]] && spec_mode="quick"
                    
                    if ! invoke_spec_creation "$spec_mode"; then
                        log "Spec creation did not complete. Exiting." "warning"
                        return
                    fi
                    ;;
                interview)
                    if ! invoke_spec_creation "interview"; then
                        log "Spec creation did not complete. Exiting." "warning"
                        return
                    fi
                    ;;
                quick)
                    if ! invoke_spec_creation "quick"; then
                        log "Spec creation did not complete. Exiting." "warning"
                        return
                    fi
                    ;;
                use-existing)
                    log "Using existing specifications."
                    ;;
            esac
        fi
    elif [[ "$MODE" == "continue" ]]; then
        # Continue mode always shows the main menu (for adding new specs)
        local main_choice
        main_choice=$(show_main_menu)
        
        case "$main_choice" in
            quit)
                log "Exiting Ralph."
                return
                ;;
            add-spec)
                echo ""
                echo -e "${GREEN}  [1] Interview mode (Ralph asks questions)${NC}"
                echo -e "${YELLOW}  [2] Quick mode (describe in one prompt)${NC}"
                echo ""
                read -rp "  Select mode (1/2): " sub_choice
                
                local spec_mode="interview"
                [[ "$sub_choice" == "2" ]] && spec_mode="quick"
                
                if ! invoke_spec_creation "$spec_mode"; then
                    log "Spec creation did not complete. Exiting." "warning"
                    return
                fi
                ;;
            start-fresh)
                # Reset state and start new project
                echo ""
                echo -e "${YELLOW}  This will reset IMPLEMENTATION_PLAN.md and progress.txt${NC}"
                echo -e "${GRAY}  Your specs in specs/*.md will NOT be deleted.${NC}"
                echo ""
                read -rp "  Are you sure? (yes/[N]o): " confirm
                [[ -z "$confirm" ]] && confirm="n"
                if [[ ! "$confirm" =~ ^(y|yes|Y|Yes|YES)$ ]]; then
                    log "Cancelled. Exiting."
                    return
                fi
                reset_ralph_state
                ;;
            continue)
                log "Continuing with existing specifications."
                ;;
        esac
    fi
    
    case "$MODE" in
        agents)
            invoke_agents_update
            ;;
        plan)
            if ! has_user_specs; then
                log "No specs found. Create specs first or use auto mode." "warning"
                return
            fi
            invoke_planning
            ;;
        build)
            read -r total completed pending <<< $(get_task_stats)
            if [[ "$pending" -eq 0 ]]; then
                if [[ "$total" -eq 0 ]]; then
                    log "No tasks found. Run with -m auto or -m plan first." "warning"
                else
                    log "All $total tasks already completed!" "success"
                fi
                return
            fi
            invoke_building
            ;;
        auto|continue)
            # Auto/Continue mode: update AGENTS.md, plan if needed, then build
            invoke_agents_update
            
            if needs_planning; then
                read -r total completed pending <<< $(get_task_stats)
                if [[ "$total" -eq 0 ]]; then
                    log "No existing plan. Running planning phase..."
                else
                    log "All tasks complete. Re-running planning to find new work..."
                fi
                
                invoke_planning || {
                    log "Planning did not create tasks. Nothing to build." "warning"
                    return
                }
            fi
            invoke_building
            ;;
    esac
    
    # Show comprehensive session summary
    show_session_summary "$ITERATION" "$SESSION_START"
}

main "$@"
