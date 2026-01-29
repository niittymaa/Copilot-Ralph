#!/bin/bash
#
# Preset management module for Ralph Loop
#
# Provides functions to discover, load, and apply presets.
# Presets are pre-configured task templates for common operations like:
# - Code refactoring
# - Security hardening
# - Codebase cleanup
# - Documentation generation
# - Project analysis
#
# Presets are stored as .md files in ralph/presets/
# Each preset contains a description and task template that Ralph follows.

set -e

# ═══════════════════════════════════════════════════════════════
#                        CONFIGURATION
# ═══════════════════════════════════════════════════════════════

PRESETS_DIR=""
PRESET_PROJECT_ROOT=""

initialize_preset_paths() {
    local project_root="$1"
    PRESET_PROJECT_ROOT="$project_root"
    local ralph_dir="$project_root/ralph"
    PRESETS_DIR="$ralph_dir/presets"
}

# ═══════════════════════════════════════════════════════════════
#                      PRESET OPERATIONS
# ═══════════════════════════════════════════════════════════════

get_all_presets() {
    # Returns preset IDs (filenames without extension), one per line
    if [[ ! -d "$PRESETS_DIR" ]]; then
        return
    fi
    
    for file in "$PRESETS_DIR"/*.md; do
        [[ -f "$file" ]] || continue
        basename "$file" .md
    done | sort
}

get_preset_count() {
    local count=0
    if [[ -d "$PRESETS_DIR" ]]; then
        count=$(find "$PRESETS_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    fi
    echo "$count"
}

read_preset_field() {
    # Reads a field from preset YAML frontmatter
    local preset_path="$1"
    local field_name="$2"
    local default_value="${3:-}"
    
    if [[ ! -f "$preset_path" ]]; then
        echo "$default_value"
        return
    fi
    
    # Extract value from YAML frontmatter
    local value
    value=$(sed -n '/^---$/,/^---$/p' "$preset_path" | grep "^${field_name}:" | head -1 | sed "s/^${field_name}:[[:space:]]*['\"]\\?//" | sed "s/['\"]\\?[[:space:]]*$//")
    
    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "$default_value"
    fi
}

read_preset_body() {
    # Reads preset content after YAML frontmatter
    local preset_path="$1"
    
    if [[ ! -f "$preset_path" ]]; then
        return
    fi
    
    # Skip YAML frontmatter and get the rest
    awk 'BEGIN{p=0} /^---$/{p++; next} p>=2{print}' "$preset_path"
}

get_preset_path() {
    local preset_id="$1"
    echo "$PRESETS_DIR/${preset_id}.md"
}

get_preset_name() {
    local preset_id="$1"
    local preset_path
    preset_path=$(get_preset_path "$preset_id")
    read_preset_field "$preset_path" "name" "$preset_id"
}

get_preset_description() {
    local preset_id="$1"
    local preset_path
    preset_path=$(get_preset_path "$preset_id")
    read_preset_field "$preset_path" "description" ""
}

get_preset_category() {
    local preset_id="$1"
    local preset_path
    preset_path=$(get_preset_path "$preset_id")
    read_preset_field "$preset_path" "category" "General"
}

show_presets_menu() {
    # Interactive menu for selecting a preset
    # Returns preset ID via stdout, or empty string if cancelled
    
    local presets
    presets=$(get_all_presets)
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  RALPH - PRESET SELECTION"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    if [[ -z "$presets" ]]; then
        echo "  No presets found in ralph/presets/"
        echo "  Create .md files in that folder to add presets."
        echo ""
        read -r -p "  Press Enter to return..." _
        echo ""
        return
    fi
    
    echo "  Select a preset to apply to your session:"
    echo ""
    
    # Build array of presets
    local preset_array=()
    local i=1
    while IFS= read -r preset_id; do
        preset_array+=("$preset_id")
        local name description category
        name=$(get_preset_name "$preset_id")
        description=$(get_preset_description "$preset_id")
        category=$(get_preset_category "$preset_id")
        
        printf "  [%d] %s\n" "$i" "$name"
        if [[ -n "$description" ]]; then
            printf "      %s\n" "$description"
        fi
        ((i++))
    done <<< "$presets"
    
    echo ""
    echo "  [Q] Cancel / Return to menu"
    echo ""
    
    read -r -p "  Select preset (1-${#preset_array[@]}): " choice
    
    if [[ -z "$choice" ]] || [[ "${choice^^}" == "Q" ]]; then
        echo ""
        return
    fi
    
    # Validate numeric choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#preset_array[@]} )); then
        echo "${preset_array[$((choice-1))]}"
        return
    fi
    
    echo "  Invalid selection" >&2
    echo ""
}

apply_preset() {
    # Applies a preset to a task session
    # Creates spec file from preset content
    local preset_id="$1"
    local task_specs_dir="$2"
    local task_name="${3:-preset-task}"
    
    local preset_path
    preset_path=$(get_preset_path "$preset_id")
    
    if [[ ! -f "$preset_path" ]]; then
        echo "  Preset '$preset_id' not found" >&2
        return 1
    fi
    
    # Ensure specs directory exists
    mkdir -p "$task_specs_dir"
    
    # Get preset info
    local name description body
    name=$(get_preset_name "$preset_id")
    description=$(get_preset_description "$preset_id")
    body=$(read_preset_body "$preset_path")
    
    # Create spec file
    local spec_file="$task_specs_dir/${preset_id}-spec.md"
    
    cat > "$spec_file" << EOF
# $name

## Overview

$description

## Requirements

$body

---
Generated from preset: $preset_id
Applied: $(date "+%Y-%m-%d %H:%M:%S")
EOF
    
    echo "  ✓ Applied preset: $name"
    echo "    Created: ${preset_id}-spec.md"
    return 0
}

new_task_from_preset() {
    # Creates a new task session from a preset
    local preset_id="$1"
    local task_name="${2:-}"
    
    local preset_path
    preset_path=$(get_preset_path "$preset_id")
    
    if [[ ! -f "$preset_path" ]]; then
        echo "  Preset '$preset_id' not found" >&2
        return 1
    fi
    
    # Get preset name if task name not provided
    if [[ -z "$task_name" ]]; then
        task_name=$(get_preset_name "$preset_id")
    fi
    
    local description
    description=$(get_preset_description "$preset_id")
    
    # Create the task (requires tasks.sh to be sourced)
    local task_info
    task_info=$(create_task "$task_name" "$description" "isolated")
    
    if [[ -z "$task_info" ]]; then
        echo "  Failed to create task" >&2
        return 1
    fi
    
    # Extract task ID from output
    local task_id
    task_id=$(echo "$task_info" | grep -o '"id":[[:space:]]*"[^"]*"' | sed 's/"id":[[:space:]]*"//' | sed 's/"$//' || echo "$task_info")
    
    # If task_info is just the ID
    if [[ "$task_info" =~ ^[a-z0-9-]+$ ]]; then
        task_id="$task_info"
    fi
    
    # Apply the preset
    local specs_dir
    specs_dir=$(get_task_specs_dir "$task_id")
    apply_preset "$preset_id" "$specs_dir" "$task_name"
    
    # Set as active task
    set_active_task "$task_id"
    
    echo "$task_id"
}
