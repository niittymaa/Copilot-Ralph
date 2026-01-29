#!/bin/bash
#
# Task management module for Ralph Loop multi-task support
#
# Provides functions to create, switch, list, and manage isolated task contexts.
# Each task has its own:
# - specs/ folder (or references shared specs)
# - IMPLEMENTATION_PLAN.md
# - progress.txt
#
# All tasks are stored in .ralph/tasks/<task-id>/
#
# Task ID format: <name>-<timestamp> (e.g., "auth-feature-20260115-123456")
# Active task is tracked in .ralph/active-task

set -e

# ═══════════════════════════════════════════════════════════════
#                        CONFIGURATION
# ═══════════════════════════════════════════════════════════════

TASKS_ROOT=""
ACTIVE_TASK_FILE=""
SHARED_SPECS_DIR=""
TASK_PROJECT_ROOT=""

initialize_task_paths() {
    local project_root="$1"
    TASK_PROJECT_ROOT="$project_root"
    TASKS_ROOT="$project_root/.ralph/tasks"
    ACTIVE_TASK_FILE="$project_root/.ralph/active-task"
    SHARED_SPECS_DIR="$project_root/specs"
}

# ═══════════════════════════════════════════════════════════════
#                      TASK OPERATIONS
# ═══════════════════════════════════════════════════════════════

get_active_task_id() {
    if [[ -f "$ACTIVE_TASK_FILE" ]]; then
        local task_id
        task_id=$(cat "$ACTIVE_TASK_FILE" | tr -d '[:space:]')
        if [[ -n "$task_id" ]] && task_exists "$task_id"; then
            echo "$task_id"
            return
        fi
    fi
    echo ""  # No active task
}

set_active_task() {
    local task_id="$1"
    
    if ! task_exists "$task_id"; then
        echo "Error: Task '$task_id' does not exist" >&2
        return 1
    fi
    
    # Ensure .ralph directory exists
    local ralph_dir
    ralph_dir=$(dirname "$ACTIVE_TASK_FILE")
    mkdir -p "$ralph_dir"
    
    echo -n "$task_id" > "$ACTIVE_TASK_FILE"
}

task_exists() {
    local task_id="$1"
    
    [[ -z "$task_id" ]] && return 1
    
    local task_dir
    task_dir=$(get_task_directory "$task_id")
    [[ -d "$task_dir" ]]
}

get_task_directory() {
    local task_id="$1"
    
    [[ -z "$task_id" ]] && echo "" && return
    
    echo "$TASKS_ROOT/$task_id"
}

get_task_plan_file() {
    local task_id="${1:-$(get_active_task_id)}"
    
    [[ -z "$task_id" ]] && echo "" && return
    
    local task_dir
    task_dir=$(get_task_directory "$task_id")
    echo "$task_dir/IMPLEMENTATION_PLAN.md"
}

get_task_progress_file() {
    local task_id="${1:-$(get_active_task_id)}"
    
    [[ -z "$task_id" ]] && echo "" && return
    
    local task_dir
    task_dir=$(get_task_directory "$task_id")
    echo "$task_dir/progress.txt"
}

get_task_specs_dir() {
    local task_id="${1:-$(get_active_task_id)}"
    
    if [[ -z "$task_id" ]]; then
        echo "$SHARED_SPECS_DIR"
        return
    fi
    
    local task_dir
    task_dir=$(get_task_directory "$task_id")
    local task_specs="$task_dir/specs"
    
    # If task has its own specs, use them
    if [[ -d "$task_specs" ]]; then
        echo "$task_specs"
        return
    fi
    
    # Check for specs mode in task config
    local config_file="$task_dir/task.json"
    if [[ -f "$config_file" ]]; then
        local specs_mode
        specs_mode=$(jq -r '.specsMode // "isolated"' "$config_file" 2>/dev/null || echo "isolated")
        if [[ "$specs_mode" == "shared" ]]; then
            echo "$SHARED_SPECS_DIR"
            return
        fi
    fi
    
    # Task-specific specs
    echo "$task_specs"
}

create_task() {
    local name="$1"
    local description="${2:-}"
    local specs_mode="${3:-isolated}"
    
    # Generate task ID: slugified name + date
    local slug
    slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
    local date_stamp
    date_stamp=$(date +%Y%m%d-%H%M%S)
    local task_id="${slug}-${date_stamp}"
    
    # Create task directory
    local task_dir="$TASKS_ROOT/$task_id"
    if [[ -d "$task_dir" ]]; then
        echo "Error: Task directory already exists: $task_dir" >&2
        return 1
    fi
    
    mkdir -p "$task_dir"
    
    # Create task config
    cat > "$task_dir/task.json" << EOF
{
  "id": "$task_id",
  "name": "$name",
  "description": "$description",
  "specsMode": "$specs_mode",
  "created": "$(date -Iseconds)",
  "status": "active"
}
EOF
    
    # Create IMPLEMENTATION_PLAN.md
    cat > "$task_dir/IMPLEMENTATION_PLAN.md" << EOF
# Implementation Plan

## Task: $name

$description

## Overview

Run \`./ralph.sh\` to auto-generate tasks from specs and start building.

## Tasks

### High Priority
- [ ] Define requirements in specs/
- [ ] Run Ralph (./ralph.sh)

### Medium Priority
(Generated from specs)

### Low Priority
(Generated from specs)

## Completed

(Completed tasks are marked with [x])
EOF
    
    # Create progress.txt
    cat > "$task_dir/progress.txt" << EOF
# Ralph Progress Log - $name

## Codebase Patterns
(Add reusable patterns here)

---
Task created: $(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    # Create specs directory if isolated mode
    if [[ "$specs_mode" == "isolated" ]]; then
        local specs_dir="$task_dir/specs"
        mkdir -p "$specs_dir"
        
        # Copy template if exists
        local template_file="$TASK_PROJECT_ROOT/specs/_example.template.md"
        if [[ -f "$template_file" ]]; then
            cp "$template_file" "$specs_dir/_example.template.md"
        fi
    fi
    
    echo "$task_id"
}

list_all_tasks() {
    local active_id
    active_id=$(get_active_task_id)
    
    echo "TASK_ID|NAME|DESCRIPTION|SPECS_MODE|STATUS|PENDING|COMPLETED|ACTIVE"
    
    # Add all tasks from .ralph/tasks/
    if [[ -d "$TASKS_ROOT" ]]; then
        for task_dir in "$TASKS_ROOT"/*/; do
            [[ -d "$task_dir" ]] || continue
            local config_file="$task_dir/task.json"
            [[ -f "$config_file" ]] || continue
            
            local task_id name description specs_mode status
            task_id=$(jq -r '.id' "$config_file")
            name=$(jq -r '.name' "$config_file")
            description=$(jq -r '.description // ""' "$config_file")
            specs_mode=$(jq -r '.specsMode // "isolated"' "$config_file")
            status=$(jq -r '.status // "active"' "$config_file")
            
            local plan_file="$task_dir/IMPLEMENTATION_PLAN.md"
            local pending=0
            local completed=0
            if [[ -f "$plan_file" ]]; then
                pending=$(grep -c '- \[ \]' "$plan_file" 2>/dev/null || echo "0")
                completed=$(grep -c '- \[x\]' "$plan_file" 2>/dev/null || echo "0")
            fi
            
            local is_active="false"
            [[ "$active_id" == "$task_id" ]] && is_active="true"
            
            echo "$task_id|$name|$description|$specs_mode|$status|$pending|$completed|$is_active"
        done
    fi
}

remove_task() {
    local task_id="$1"
    local force="${2:-false}"
    
    if ! task_exists "$task_id"; then
        echo "Error: Task '$task_id' does not exist" >&2
        return 1
    fi
    
    local task_dir
    task_dir=$(get_task_directory "$task_id")
    
    # If this is the active task, clear the active task
    if [[ "$(get_active_task_id)" == "$task_id" ]]; then
        rm -f "$ACTIVE_TASK_FILE"
    fi
    
    # Remove task directory
    rm -rf "$task_dir"
}

show_task_menu() {
    local active_id
    active_id=$(get_active_task_id)
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  RALPH - TASK MANAGEMENT"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    local tasks=()
    local IFS=$'\n'
    local first=true
    while read -r line; do
        if $first; then
            first=false
            continue  # Skip header
        fi
        tasks+=("$line")
    done < <(list_all_tasks)
    
    # Handle empty task list
    if [[ ${#tasks[@]} -eq 0 ]]; then
        echo "  No tasks found. Create a new task to get started."
        echo ""
        echo "  ─────────────────────────────────────────────────────────────"
        echo "  [N] New task  [P] Start from preset  [Q] Quit"
        echo ""
        
        read -rp "  Select action: " choice
        
        case "${choice^^}" in
            N)
                echo "new|"
                ;;
            P)
                echo "preset|"
                ;;
            *)
                echo "quit|"
                ;;
        esac
        return
    fi
    
    echo -n "  Current Task: "
    
    # Find and display active task
    local found_active=false
    for task in "${tasks[@]}"; do
        IFS='|' read -r id name desc specs status pending completed active <<< "$task"
        if [[ "$active" == "true" ]]; then
            echo -e "\033[32m$name\033[0m ($id)"
            found_active=true
            break
        fi
    done
    
    if ! $found_active; then
        echo "(none)"
    fi
    
    echo ""
    echo "  Available Tasks:"
    echo ""
    
    local index=1
    for task in "${tasks[@]}"; do
        IFS='|' read -r id name desc specs status pending completed active <<< "$task"
        local marker=" "
        [[ "$active" == "true" ]] && marker="►"
        local total=$((pending + completed))
        printf "  %s [%d] %-25s [%d/%d done]\n" "$marker" "$index" "$name" "$completed" "$total"
        if [[ -n "$desc" ]]; then
            printf "        %s\n" "$desc"
        fi
        ((index++))
    done
    
    echo ""
    echo "  ─────────────────────────────────────────────────────────────"
    echo "  [N] New task          [P] Start from preset"
    echo "  [S] Switch to task #  [D] Delete task #"
    echo "  [Enter] Continue current task  [Q] Quit"
    echo ""
    
    read -rp "  Select action: " choice
    
    if [[ -z "$choice" ]]; then
        echo "continue|$active_id"
        return
    fi
    
    case "${choice^^}" in
        N)
            echo "new|"
            ;;
        P)
            echo "preset|"
            ;;
        S)
            read -rp "  Enter task number: " task_num
            local task_index=$((task_num - 1))
            if [[ $task_index -ge 0 && $task_index -lt ${#tasks[@]} ]]; then
                IFS='|' read -r id _ <<< "${tasks[$task_index]}"
                echo "switch|$id"
            else
                echo "  Invalid task number" >&2
                echo "cancel|"
            fi
            ;;
        D)
            read -rp "  Enter task number to delete: " task_num
            local task_index=$((task_num - 1))
            if [[ $task_index -ge 0 && $task_index -lt ${#tasks[@]} ]]; then
                IFS='|' read -r id _ <<< "${tasks[$task_index]}"
                echo "delete|$id"
            else
                echo "  Invalid task number" >&2
                echo "cancel|"
            fi
            ;;
        Q)
            echo "quit|"
            ;;
        *)
            # Check if it's a number (direct task selection)
            if [[ "$choice" =~ ^[0-9]+$ ]]; then
                local task_index=$((choice - 1))
                if [[ $task_index -ge 0 && $task_index -lt ${#tasks[@]} ]]; then
                    IFS='|' read -r id _ <<< "${tasks[$task_index]}"
                    echo "switch|$id"
                    return
                fi
            fi
            echo "continue|$active_id"
            ;;
    esac
}

create_task_interactive() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CREATE NEW TASK"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    read -rp "  Task name (e.g., 'Auth Feature', 'API Refactor'): " name
    if [[ -z "$name" ]]; then
        echo "  Cancelled - name is required"
        return 1
    fi
    
    read -rp "  Description (optional): " description
    
    echo ""
    echo "  Specs mode:"
    echo "    [1] Isolated - Task has its own specs/ folder (default)"
    echo "    [2] Shared   - Task uses project-level specs/"
    read -rp "  Select (1/2): " specs_choice
    
    local specs_mode="isolated"
    [[ "$specs_choice" == "2" ]] && specs_mode="shared"
    
    echo ""
    echo "  Creating task..."
    
    local task_id
    task_id=$(create_task "$name" "$description" "$specs_mode")
    
    if [[ $? -eq 0 ]]; then
        local task_dir
        task_dir=$(get_task_directory "$task_id")
        
        echo ""
        echo "  ✓ Task created: $task_id"
        echo "    Directory: $task_dir"
        echo ""
        
        read -rp "  Activate this task now? (Y/n): " activate
        if [[ -z "$activate" || "${activate^^}" == "Y" ]]; then
            set_active_task "$task_id"
            echo "  ✓ Task activated"
        fi
        
        echo "$task_id"
    else
        echo "  ✗ Failed to create task"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
#                     INITIALIZATION
# ═══════════════════════════════════════════════════════════════

initialize_task_system() {
    # Ensure .ralph directory exists
    local ralph_dir="$TASK_PROJECT_ROOT/.ralph"
    mkdir -p "$ralph_dir"
    
    # Ensure tasks directory exists
    mkdir -p "$TASKS_ROOT"
}
