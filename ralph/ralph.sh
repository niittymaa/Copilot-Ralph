#!/usr/bin/env bash
# Ralph - Autonomous AI coding agent orchestrator for GitHub Copilot CLI
#
# Self-contained in the ralph/ folder. On first run, automatically sets up:
# - .github/instructions/ralph.instructions.md (Ralph config)
# - .github/agents/ with agent files
# - specs/ folder with template
# - .ralph/ cache folder
# - Optionally AGENTS.md (prompts user)
#
# Usage: ./ralph/ralph.sh [options]
#   -m, --mode         Mode: auto|plan|build|agents|sessions (default: auto)
#   -M, --model        AI model to use (e.g., claude-sonnet-4, gpt-4.1)
#   -L, --list-models  List available AI models and exit
#   -n, --max          Max iterations (default: 0=unlimited, runs until complete)
#   -d, --delegate     Delegate to Copilot coding agent
#   --manual           Manual mode (copy/paste prompts)
#   -V, --verbose      Verbose mode (detailed output)
#   -v, --venv         Venv mode: auto|skip|reset (default: auto)
#   -s, --session      Switch to session by ID
#   --new-session      Create a new session with name
#   -h, --help         Show help

set -euo pipefail

# ═══════════════════════════════════════════════════════════════
#                     PATH RESOLUTION
# ═══════════════════════════════════════════════════════════════

# Ralph folder (where this script lives)
RALPH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project root (parent of ralph folder)
PROJECT_ROOT="$(dirname "$RALPH_DIR")"
# Core scripts location
CORE_DIR="$RALPH_DIR/core"
# Templates location
TEMPLATES_DIR="$RALPH_DIR/templates"
# Agent source files
AGENT_SOURCE_DIR="$RALPH_DIR/agents"

# ═══════════════════════════════════════════════════════════════
#                     COLORS
# ═══════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════
#                     AUTO-SETUP FUNCTIONS
# ═══════════════════════════════════════════════════════════════

invoke_project_setup() {
    local setup_needed=false
    local setup_actions=()
    
    # Check for .github/instructions/ralph.instructions.md (required)
    local instructions_dir="$PROJECT_ROOT/.github/instructions"
    local ralph_instructions_path="$instructions_dir/ralph.instructions.md"
    if [[ ! -f "$ralph_instructions_path" ]]; then
        setup_needed=true
        setup_actions+=('.github/instructions/ralph.instructions.md')
    fi
    
    # Check for .github/agents/
    local github_agents_dir="$PROJECT_ROOT/.github/agents"
    if [[ ! -d "$github_agents_dir" ]]; then
        setup_needed=true
        setup_actions+=('.github/agents/')
    fi
    
    # Check for specs/
    local specs_dir="$PROJECT_ROOT/specs"
    if [[ ! -d "$specs_dir" ]]; then
        setup_needed=true
        setup_actions+=('specs/')
    fi
    
    # Check for .ralph/
    local ralph_cache_dir="$PROJECT_ROOT/.ralph"
    if [[ ! -d "$ralph_cache_dir" ]]; then
        setup_needed=true
        setup_actions+=('.ralph/')
    fi
    
    if [[ "$setup_needed" == "false" ]]; then
        return
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}  RALPH - FIRST-RUN SETUP${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}  Ralph needs to create the following files and folders:${NC}"
    echo ""
    for action in "${setup_actions[@]}"; do
        echo -e "    ${CYAN}• $action${NC}"
    done
    echo ""
    echo -e "${GRAY}  These files are required for Ralph to function properly.${NC}"
    echo ""
    read -p "  Proceed with setup? ([Y]es/No): " response
    
    if [[ ! -z "$response" ]] && [[ ! "$response" =~ ^[Yy] ]]; then
        echo ""
        echo -e "${YELLOW}  Setup cancelled. Ralph cannot run without these files.${NC}"
        echo -e "${GRAY}  Run again when ready to set up.${NC}"
        echo ""
        exit 0
    fi
    
    echo ""
    echo -e "${GRAY}  Setting up project structure...${NC}"
    echo ""
    
    # Create .github/instructions/ralph.instructions.md
    if [[ ! -f "$ralph_instructions_path" ]]; then
        mkdir -p "$instructions_dir"
        local template_path="$TEMPLATES_DIR/ralph.instructions.md"
        if [[ -f "$template_path" ]]; then
            cp "$template_path" "$ralph_instructions_path"
            echo -e "  ${GREEN}✓ Created .github/instructions/ralph.instructions.md${NC}"
        else
            echo -e "  ${RED}✗ Template not found: ralph.instructions.md${NC}"
        fi
    fi
    
    # Create .github/agents/ and copy agent files
    if [[ ! -d "$github_agents_dir" ]]; then
        mkdir -p "$github_agents_dir"
        
        # Copy all agent files
        local agent_count=0
        for file in "$AGENT_SOURCE_DIR"/*.agent.md; do
            if [[ -f "$file" ]]; then
                cp "$file" "$github_agents_dir/"
                ((agent_count++))
            fi
        done
        echo -e "  ${GREEN}✓ Created .github/agents/ with $agent_count agent files${NC}"
    fi
    
    # Create specs/ with template
    if [[ ! -d "$specs_dir" ]]; then
        mkdir -p "$specs_dir"
        local spec_template="$TEMPLATES_DIR/spec.template.md"
        if [[ -f "$spec_template" ]]; then
            cp "$spec_template" "$specs_dir/_example.template.md"
        fi
        echo -e "  ${GREEN}✓ Created specs/${NC}"
    fi
    
    # Create .ralph/
    if [[ ! -d "$ralph_cache_dir" ]]; then
        mkdir -p "$ralph_cache_dir"
        echo -e "  ${GREEN}✓ Created .ralph/${NC}"
    fi
    
    # Check for AGENTS.md - offer to create if missing (optional)
    local agents_md_path="$PROJECT_ROOT/AGENTS.md"
    if [[ ! -f "$agents_md_path" ]]; then
        echo ""
        echo -e "  ${YELLOW}Note: No AGENTS.md found in project root.${NC}"
        echo -e "  ${GRAY}Ralph can create one with build/test documentation.${NC}"
        echo ""
        read -rp "  Create AGENTS.md? (Y/n): " response
        if [[ -z "$response" || "$response" =~ ^[Yy] ]]; then
            local agents_template="$TEMPLATES_DIR/AGENTS.template.md"
            if [[ -f "$agents_template" ]]; then
                cp "$agents_template" "$agents_md_path"
                echo -e "  ${GREEN}✓ Created AGENTS.md (customize with your build/test commands)${NC}"
            fi
        else
            echo -e "  ${GRAY}⊘ Skipped AGENTS.md (you can create it later)${NC}"
        fi
    fi
    
    echo ""
    echo -e "  ${GREEN}Setup complete! Ralph is ready to use.${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
#                     LIST MODELS
# ═══════════════════════════════════════════════════════════════

show_models() {
    echo ""
    echo -e "${CYAN}Available AI Models for GitHub Copilot CLI:${NC}"
    echo ""
    echo -e "${WHITE}  Anthropic Claude:${NC}"
    echo -e "${GRAY}    claude-sonnet-4.5    - Claude Sonnet 4.5 (recommended)${NC}"
    echo -e "${GRAY}    claude-sonnet-4      - Claude Sonnet 4${NC}"
    echo -e "${GRAY}    claude-haiku-4.5     - Claude Haiku 4.5 (fast/cheap)${NC}"
    echo -e "${GRAY}    claude-opus-4.5      - Claude Opus 4.5 (premium)${NC}"
    echo ""
    echo -e "${WHITE}  OpenAI GPT:${NC}"
    echo -e "${GRAY}    gpt-5.2-codex        - GPT-5.2 Codex${NC}"
    echo -e "${GRAY}    gpt-5.1-codex-max    - GPT-5.1 Codex Max${NC}"
    echo -e "${GRAY}    gpt-5.1-codex        - GPT-5.1 Codex${NC}"
    echo -e "${GRAY}    gpt-5.1-codex-mini   - GPT-5.1 Codex Mini (fast/cheap)${NC}"
    echo -e "${GRAY}    gpt-5.2              - GPT-5.2${NC}"
    echo -e "${GRAY}    gpt-5.1              - GPT-5.1${NC}"
    echo -e "${GRAY}    gpt-5                - GPT-5${NC}"
    echo -e "${GRAY}    gpt-5-mini           - GPT-5 Mini (fast/cheap)${NC}"
    echo -e "${GRAY}    gpt-4.1              - GPT-4.1 (fast/cheap)${NC}"
    echo ""
    echo -e "${WHITE}  Google Gemini:${NC}"
    echo -e "${GRAY}    gemini-3-pro-preview - Gemini 3 Pro (preview)${NC}"
    echo ""
    echo -e "${YELLOW}Usage: ./ralph/ralph.sh -M <model-name>${NC}"
    echo ""
    exit 0
}

show_help() {
    echo "Ralph - Autonomous AI coding agent orchestrator"
    echo ""
    echo "Usage: ./ralph/ralph.sh [options]"
    echo ""
    echo "Options:"
    echo "  -m, --mode MODE       Operation mode (default: auto)"
    echo "                        auto|plan|build|agents|continue|sessions"
    echo "  -M, --model MODEL     AI model to use"
    echo "  -L, --list-models     List available models"
    echo "  -n, --max N           Max build iterations (0=unlimited)"
    echo "  -d, --delegate        Hand off to background agent"
    echo "  --manual              Copy/paste mode"
    echo "  -V, --verbose         Verbose output"
    echo "  -v, --venv MODE       Python venv: auto|skip|reset"
    echo "  -s, --session ID      Switch to session"
    echo "  --new-session NAME    Create new session"
    echo "  --memory MODE         Memory system: on|off|status"
    echo "  -h, --help            Show this help"
    echo ""
    exit 0
}

# ═══════════════════════════════════════════════════════════════
#                     PARSE ARGUMENTS
# ═══════════════════════════════════════════════════════════════

MODE="auto"
MODEL=""
MAX_ITERATIONS=0
DELEGATE=false
MANUAL=false
VERBOSE=false
VENV_MODE="auto"
SESSION=""
NEW_SESSION=""
MEMORY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -M|--model)
            MODEL="$2"
            shift 2
            ;;
        -L|--list-models)
            show_models
            ;;
        -n|--max)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        -d|--delegate)
            DELEGATE=true
            shift
            ;;
        --manual)
            MANUAL=true
            shift
            ;;
        -V|--verbose)
            VERBOSE=true
            shift
            ;;
        -v|--venv)
            VENV_MODE="$2"
            shift 2
            ;;
        -s|--session)
            SESSION="$2"
            shift 2
            ;;
        --new-session)
            NEW_SESSION="$2"
            shift 2
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# ═══════════════════════════════════════════════════════════════
#                     MEMORY MANAGEMENT
# ═══════════════════════════════════════════════════════════════

# Source memory module if available
if [[ -f "$CORE_DIR/memory.sh" ]]; then
    source "$CORE_DIR/memory.sh"
    initialize_memory_system "$PROJECT_ROOT"
fi

# Handle --memory parameter
if [[ -n "$MEMORY" ]]; then
    case "$MEMORY" in
        on)
            set_memory_enabled "true"
            echo ""
            echo -e "  ${GREEN}✓ Memory system ENABLED${NC}"
            echo -e "  ${GRAY}  Learnings will be recorded across sessions.${NC}"
            echo -e "  ${GRAY}  File: .ralph/memory.md${NC}"
            echo ""
            exit 0
            ;;
        off)
            set_memory_enabled "false"
            echo ""
            echo -e "  ${YELLOW}✓ Memory system DISABLED${NC}"
            echo -e "  ${GRAY}  Learnings will not be recorded.${NC}"
            echo ""
            exit 0
            ;;
        status)
            show_memory_status
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid memory mode: $MEMORY${NC}" >&2
            echo "Use: on, off, or status" >&2
            exit 1
            ;;
    esac
fi

# ═══════════════════════════════════════════════════════════════
#                     RUN SETUP
# ═══════════════════════════════════════════════════════════════

invoke_project_setup

# ═══════════════════════════════════════════════════════════════
#                     VALIDATE CORE SCRIPT
# ═══════════════════════════════════════════════════════════════

LOOP_SCRIPT="$CORE_DIR/loop.sh"
if [[ ! -f "$LOOP_SCRIPT" ]]; then
    echo -e "${RED}Error: Ralph core not found at $LOOP_SCRIPT${NC}" >&2
    echo "Ensure the ralph/core/ directory contains loop.sh" >&2
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
#                     BUILD ARGUMENTS
# ═══════════════════════════════════════════════════════════════

ARGS=()
ARGS+=("-m" "$MODE")
ARGS+=("-n" "$MAX_ITERATIONS")
ARGS+=("-v" "$VENV_MODE")

[[ -n "$MODEL" ]] && ARGS+=("-M" "$MODEL")
[[ "$DELEGATE" == "true" ]] && ARGS+=("-d")
[[ "$MANUAL" == "true" ]] && ARGS+=("--manual")
[[ "$VERBOSE" == "true" ]] && ARGS+=("-V")
[[ -n "$SESSION" ]] && ARGS+=("-s" "$SESSION")
[[ -n "$NEW_SESSION" ]] && ARGS+=("--new-session" "$NEW_SESSION")

# ═══════════════════════════════════════════════════════════════
#                     INVOKE CORE LOOP
# ═══════════════════════════════════════════════════════════════

exec "$LOOP_SCRIPT" "${ARGS[@]}"
