#!/usr/bin/env bash
# Python virtual environment management for Ralph
#
# Provides functions to create, activate, and manage a Python venv
# that isolates Ralph's operations from the system Python.
#
# The venv is created at .ralph/venv/ in the project root.

# ═══════════════════════════════════════════════════════════════
#                        CONFIGURATION
# ═══════════════════════════════════════════════════════════════

RALPH_DIR=""
VENV_DIR=""
VENV_PYTHON=""
VENV_PIP=""
VENV_ACTIVATED=false

# Colors
VENV_RED='\033[0;31m'
VENV_GREEN='\033[0;32m'
VENV_YELLOW='\033[1;33m'
VENV_CYAN='\033[0;36m'
VENV_GRAY='\033[0;90m'
VENV_WHITE='\033[1;37m'
VENV_NC='\033[0m'

venv_log() {
    local msg="$1"
    local color="${2:-$VENV_GRAY}"
    echo -e "${color}[venv] ${msg}${VENV_NC}"
}

# ═══════════════════════════════════════════════════════════════
#                        VENV FUNCTIONS
# ═══════════════════════════════════════════════════════════════

init_venv_paths() {
    # Initialize paths based on project root
    local project_root="$1"
    RALPH_DIR="$project_root/.ralph"
    VENV_DIR="$RALPH_DIR/venv"
    VENV_PYTHON="$VENV_DIR/bin/python"
    VENV_PIP="$VENV_DIR/bin/pip"
    VENV_ACTIVATE="$VENV_DIR/bin/activate"
}

test_venv_exists() {
    # Check if the venv already exists
    [[ -f "$VENV_PYTHON" ]]
}

test_python_available() {
    # Check if Python is available on the system
    if command -v python3 &> /dev/null; then
        return 0
    elif command -v python &> /dev/null; then
        # Verify it's Python 3
        if python --version 2>&1 | grep -q "Python 3"; then
            return 0
        fi
    fi
    return 1
}

get_python_command() {
    # Get the Python command to use (python3 or python)
    if command -v python3 &> /dev/null; then
        echo "python3"
    elif command -v python &> /dev/null; then
        if python --version 2>&1 | grep -q "Python 3"; then
            echo "python"
        fi
    fi
}

test_venv_needed() {
    # Intelligently detect if the project needs a Python virtual environment
    # Returns 0 (true) if project appears to need venv, 1 (false) otherwise
    local project_root="${1:-$(pwd)}"
    
    # Strong indicators that venv IS needed
    local python_indicators=(
        "requirements.txt"
        "requirements-dev.txt"
        "requirements-test.txt"
        "Pipfile"
        "Pipfile.lock"
        "pyproject.toml"
        "setup.py"
        "setup.cfg"
        "poetry.lock"
        "conda.yaml"
        "environment.yml"
        "environment.yaml"
    )
    
    for file in "${python_indicators[@]}"; do
        if [[ -f "$project_root/$file" ]]; then
            return 0
        fi
    done
    
    # Check for .py files in root
    if compgen -G "$project_root/*.py" > /dev/null 2>&1; then
        return 0
    fi
    
    # Check common Python directories
    local python_dirs=("src" "lib" "app" "scripts" "tests" "test")
    for dir in "${python_dirs[@]}"; do
        if [[ -d "$project_root/$dir" ]]; then
            if compgen -G "$project_root/$dir/*.py" > /dev/null 2>&1; then
                return 0
            fi
        fi
    done
    
    # Check for Jupyter notebooks (max 2 levels deep)
    if find "$project_root" -maxdepth 2 -name "*.ipynb" -print -quit 2>/dev/null | grep -q .; then
        return 0
    fi
    
    # No Python indicators found
    return 1
}

create_ralph_venv() {
    # Create the Python virtual environment
    # Usage: create_ralph_venv [--force]
    # Respects RALPH_DRY_RUN environment variable
    local force=false
    [[ "$1" == "--force" ]] && force=true
    
    if [[ -z "$VENV_DIR" ]]; then
        venv_log "Error: Venv paths not initialized" "$VENV_RED"
        return 1
    fi
    
    # Dry-run mode check
    if [[ "$RALPH_DRY_RUN" == "true" ]]; then
        venv_log "[DRY-RUN] Would create virtual environment at $VENV_DIR" "$VENV_YELLOW"
        return 0
    fi
    
    # Check if venv already exists
    if test_venv_exists && [[ "$force" != "true" ]]; then
        venv_log "Virtual environment exists at $VENV_DIR" "$VENV_GRAY"
        return 0
    fi
    
    # Check Python availability
    local python_cmd
    python_cmd=$(get_python_command)
    if [[ -z "$python_cmd" ]]; then
        venv_log "Python 3 not found. Install Python to enable venv isolation." "$VENV_YELLOW"
        return 1
    fi
    
    # Ensure .ralph directory exists
    if [[ ! -d "$RALPH_DIR" ]]; then
        mkdir -p "$RALPH_DIR"
    fi
    
    # Remove existing venv if force
    if [[ "$force" == "true" ]] && [[ -d "$VENV_DIR" ]]; then
        venv_log "Removing existing virtual environment..." "$VENV_YELLOW"
        rm -rf "$VENV_DIR"
    fi
    
    # Create the venv
    venv_log "Creating virtual environment at $VENV_DIR..." "$VENV_CYAN"
    
    if $python_cmd -m venv "$VENV_DIR" 2>/dev/null; then
        if test_venv_exists; then
            venv_log "Virtual environment created successfully" "$VENV_GREEN"
            
            # Upgrade pip in the venv
            venv_log "Upgrading pip..." "$VENV_GRAY"
            "$VENV_PYTHON" -m pip install --upgrade pip --quiet 2>/dev/null
            
            return 0
        fi
    fi
    
    venv_log "Failed to create virtual environment" "$VENV_RED"
    return 1
}

enable_ralph_venv() {
    # Activate the virtual environment for the current session
    # Respects RALPH_DRY_RUN environment variable
    if [[ -z "$VENV_DIR" ]]; then
        venv_log "Error: Venv paths not initialized" "$VENV_RED"
        return 1
    fi
    
    # Dry-run mode check
    if [[ "$RALPH_DRY_RUN" == "true" ]]; then
        venv_log "[DRY-RUN] Would activate virtual environment at $VENV_DIR" "$VENV_YELLOW"
        return 0
    fi
    
    if ! test_venv_exists; then
        venv_log "Virtual environment not found. Creating..." "$VENV_YELLOW"
        if ! create_ralph_venv; then
            return 1
        fi
    fi
    
    if [[ "$VENV_ACTIVATED" == "true" ]]; then
        return 0
    fi
    
    # Set environment variables to use the venv
    export VIRTUAL_ENV="$VENV_DIR"
    export PATH="$VENV_DIR/bin:$PATH"
    
    # Unset PYTHONHOME if set
    unset PYTHONHOME 2>/dev/null || true
    
    VENV_ACTIVATED=true
    venv_log "Activated virtual environment" "$VENV_GREEN"
    
    return 0
}

disable_ralph_venv() {
    # Deactivate the virtual environment
    if [[ "$VENV_ACTIVATED" == "true" ]] && [[ -n "$VIRTUAL_ENV" ]]; then
        # Remove venv bin from PATH
        export PATH="${PATH//$VENV_DIR\/bin:/}"
        
        unset VIRTUAL_ENV
        VENV_ACTIVATED=false
        
        venv_log "Deactivated virtual environment" "$VENV_GRAY"
    fi
}

remove_ralph_venv() {
    # Remove the virtual environment completely
    if [[ -z "$VENV_DIR" ]]; then
        venv_log "Error: Venv paths not initialized" "$VENV_RED"
        return 1
    fi
    
    # Deactivate first
    disable_ralph_venv
    
    if [[ -d "$VENV_DIR" ]]; then
        venv_log "Removing virtual environment..." "$VENV_YELLOW"
        rm -rf "$VENV_DIR"
        venv_log "Virtual environment removed" "$VENV_GREEN"
        return 0
    else
        venv_log "No virtual environment to remove" "$VENV_GRAY"
        return 0
    fi
}

show_venv_status() {
    # Display current venv status
    echo ""
    echo -e "${VENV_CYAN}Virtual Environment Status${VENV_NC}"
    echo -e "${VENV_GRAY}─────────────────────────────────────${VENV_NC}"
    echo -e "${VENV_WHITE}  Path:      ${VENV_DIR}${VENV_NC}"
    
    if test_venv_exists; then
        echo -e "${VENV_GREEN}  Exists:    true${VENV_NC}"
    else
        echo -e "${VENV_YELLOW}  Exists:    false${VENV_NC}"
    fi
    
    if [[ "$VENV_ACTIVATED" == "true" ]]; then
        echo -e "${VENV_GREEN}  Activated: true${VENV_NC}"
    else
        echo -e "${VENV_GRAY}  Activated: false${VENV_NC}"
    fi
    
    if test_venv_exists; then
        local python_version
        python_version=$("$VENV_PYTHON" --version 2>&1)
        echo -e "${VENV_WHITE}  Python:    ${python_version}${VENV_NC}"
        
        local pkg_count
        pkg_count=$("$VENV_PIP" list --format=freeze 2>/dev/null | wc -l)
        echo -e "${VENV_WHITE}  Packages:  ${pkg_count} installed${VENV_NC}"
    fi
    echo ""
}
