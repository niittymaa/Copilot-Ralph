#!/usr/bin/env bash
#
# Cross-session memory system for Ralph Loop (Bash version)
#
# Provides persistent memory storage that accumulates learnings across all sessions.
# Memory entries are stored in .ralph/memory.md and can be toggled ON/OFF via CLI.
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════
#                        CONFIGURATION
# ═══════════════════════════════════════════════════════════════

MEMORY_FILE=""
SETTINGS_FILE=""
PROJECT_ROOT=""
MEMORY_ENABLED=true

initialize_memory_system() {
    # Initialize memory system paths and load settings
    # Args: $1 = project root
    PROJECT_ROOT="$1"
    local ralph_dir="${PROJECT_ROOT}/.ralph"
    MEMORY_FILE="${ralph_dir}/memory.md"
    SETTINGS_FILE="${ralph_dir}/settings.json"
    
    # Ensure .ralph directory exists
    mkdir -p "$ralph_dir"
    
    # Load settings
    MEMORY_ENABLED=$(get_memory_setting)
    
    # Create memory file if enabled and doesn't exist
    if [[ "$MEMORY_ENABLED" == "true" ]] && [[ ! -f "$MEMORY_FILE" ]]; then
        initialize_memory_file
    fi
}

# ═══════════════════════════════════════════════════════════════
#                     SETTINGS MANAGEMENT
# ═══════════════════════════════════════════════════════════════

get_ralph_settings() {
    # Gets all Ralph settings from settings.json
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        echo '{"memory":{"enabled":true}}'
        return
    fi
    
    cat "$SETTINGS_FILE" 2>/dev/null || echo '{"memory":{"enabled":true}}'
}

save_ralph_settings() {
    # Saves Ralph settings to settings.json
    # Args: $1 = JSON settings string
    local settings="$1"
    local ralph_dir
    ralph_dir=$(dirname "$SETTINGS_FILE")
    
    mkdir -p "$ralph_dir"
    echo "$settings" > "$SETTINGS_FILE"
}

get_memory_setting() {
    # Gets the memory enabled/disabled setting
    local settings
    settings=$(get_ralph_settings)
    
    # Use jq if available, otherwise grep/sed
    if command -v jq &>/dev/null; then
        local enabled
        enabled=$(echo "$settings" | jq -r '.memory.enabled // true' 2>/dev/null)
        echo "$enabled"
    else
        # Simple fallback: check for "enabled":false
        if echo "$settings" | grep -q '"enabled"[[:space:]]*:[[:space:]]*false'; then
            echo "false"
        else
            echo "true"
        fi
    fi
}

set_memory_enabled() {
    # Enables or disables the memory system
    # Args: $1 = "true" or "false"
    local enabled="$1"
    local settings
    
    if command -v jq &>/dev/null; then
        settings=$(get_ralph_settings)
        settings=$(echo "$settings" | jq ".memory.enabled = $enabled" 2>/dev/null)
    else
        # Simple fallback
        settings="{\"memory\":{\"enabled\":$enabled}}"
    fi
    
    save_ralph_settings "$settings"
    MEMORY_ENABLED="$enabled"
    
    # Create memory file if enabling and it doesn't exist
    if [[ "$enabled" == "true" ]] && [[ ! -f "$MEMORY_FILE" ]]; then
        initialize_memory_file
    fi
}

test_memory_enabled() {
    # Checks if memory system is currently enabled
    # Returns: 0 if enabled, 1 if disabled
    [[ "$MEMORY_ENABLED" == "true" ]]
}

# ═══════════════════════════════════════════════════════════════
#                     MEMORY FILE OPERATIONS
# ═══════════════════════════════════════════════════════════════

initialize_memory_file() {
    # Creates the initial memory.md file structure
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    cat > "$MEMORY_FILE" << EOF
# Ralph Memory

> Cross-session learnings that persist across all Ralph sessions.
> This file is automatically managed by Ralph. You can also edit it manually.

---

## Patterns

> Code patterns, conventions, and best practices discovered in this codebase.

<!-- Add patterns here -->

---

## Commands

> Build, test, lint, and other commands that work for this project.

<!-- Add commands here -->

---

## Gotchas

> Common pitfalls, edge cases, and things to watch out for.

<!-- Add gotchas here -->

---

## Decisions

> Architectural decisions, design choices, and their rationale.

<!-- Add decisions here -->

---

*Last updated: ${timestamp}*
EOF
}

get_memory_content() {
    # Gets the current memory file content
    if [[ "$MEMORY_ENABLED" != "true" ]]; then
        echo ""
        return
    fi
    
    if [[ ! -f "$MEMORY_FILE" ]]; then
        echo ""
        return
    fi
    
    cat "$MEMORY_FILE"
}

add_memory_entry() {
    # Adds an entry to a memory section
    # Args: $1 = section (Patterns|Commands|Gotchas|Decisions), $2 = entry, $3 = source (optional)
    local section="$1"
    local entry="$2"
    local source="${3:-}"
    
    if [[ "$MEMORY_ENABLED" != "true" ]]; then
        return 1
    fi
    
    if [[ ! -f "$MEMORY_FILE" ]]; then
        initialize_memory_file
    fi
    
    # Check if entry already exists
    if grep -qF "$entry" "$MEMORY_FILE" 2>/dev/null; then
        return 1
    fi
    
    local timestamp
    timestamp=$(date "+%Y-%m-%d")
    local source_text=""
    if [[ -n "$source" ]]; then
        source_text=" *(from: ${source})*"
    fi
    
    local formatted_entry="- ${entry}${source_text} [${timestamp}]"
    
    # Insert entry after the section comment
    local temp_file="${MEMORY_FILE}.tmp"
    local in_section=false
    local inserted=false
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        echo "$line" >> "$temp_file"
        
        if [[ "$line" == "## $section" ]]; then
            in_section=true
        elif [[ "$in_section" == true ]] && [[ "$line" == *"<!-- Add"* ]] && [[ "$inserted" == false ]]; then
            # Remove the comment line we just added, insert entry, then add comment back
            head -n -1 "$temp_file" > "${temp_file}.2"
            echo "$formatted_entry" >> "${temp_file}.2"
            echo "" >> "${temp_file}.2"
            echo "$line" >> "${temp_file}.2"
            mv "${temp_file}.2" "$temp_file"
            inserted=true
            in_section=false
        fi
    done < "$MEMORY_FILE"
    
    # Update last updated timestamp
    sed -i.bak "s/\*Last updated:.*\*/*Last updated: $(date '+%Y-%m-%d %H:%M:%S')*/" "$temp_file" 2>/dev/null || true
    rm -f "${temp_file}.bak"
    
    mv "$temp_file" "$MEMORY_FILE"
    
    if [[ "$inserted" == true ]]; then
        return 0
    fi
    return 1
}

get_memory_stats() {
    # Gets statistics about the memory file
    # Outputs: JSON-like stats
    local patterns=0 commands=0 gotchas=0 decisions=0
    
    if [[ "$MEMORY_ENABLED" != "true" ]] || [[ ! -f "$MEMORY_FILE" ]]; then
        echo "enabled=$MEMORY_ENABLED patterns=0 commands=0 gotchas=0 decisions=0 total=0"
        return
    fi
    
    # Count entries in each section
    local content
    content=$(cat "$MEMORY_FILE")
    
    # Simple counting - lines starting with "- " after each section header
    patterns=$(echo "$content" | awk '/^## Patterns/,/^---/{if(/^- /)count++}END{print count+0}')
    commands=$(echo "$content" | awk '/^## Commands/,/^---/{if(/^- /)count++}END{print count+0}')
    gotchas=$(echo "$content" | awk '/^## Gotchas/,/^---/{if(/^- /)count++}END{print count+0}')
    decisions=$(echo "$content" | awk '/^## Decisions/,/^---/{if(/^- /)count++}END{print count+0}')
    
    local total=$((patterns + commands + gotchas + decisions))
    
    echo "enabled=$MEMORY_ENABLED patterns=$patterns commands=$commands gotchas=$gotchas decisions=$decisions total=$total"
}

get_memory_file_path() {
    # Gets the path to the memory file
    echo "$MEMORY_FILE"
}

show_memory_status() {
    # Displays current memory system status
    local stats
    stats=$(get_memory_stats)
    
    # Parse stats
    local enabled patterns commands gotchas decisions total
    enabled=$(echo "$stats" | grep -oP 'enabled=\K\w+')
    patterns=$(echo "$stats" | grep -oP 'patterns=\K\d+')
    commands=$(echo "$stats" | grep -oP 'commands=\K\d+')
    gotchas=$(echo "$stats" | grep -oP 'gotchas=\K\d+')
    decisions=$(echo "$stats" | grep -oP 'decisions=\K\d+')
    total=$(echo "$stats" | grep -oP 'total=\K\d+')
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  RALPH MEMORY SYSTEM"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    if [[ "$enabled" == "true" ]]; then
        echo -e "  Status: \033[0;32mENABLED\033[0m"
        echo ""
        echo "  Memory entries:"
        echo "    Patterns:  $patterns"
        echo "    Commands:  $commands"
        echo "    Gotchas:   $gotchas"
        echo "    Decisions: $decisions"
        echo "    ─────────────"
        echo "    Total:     $total"
        echo ""
        echo "  File: $MEMORY_FILE"
    else
        echo -e "  Status: \033[0;33mDISABLED\033[0m"
        echo ""
        echo "  Memory is not being recorded."
        echo "  Enable with: ./ralph.sh --memory on"
    fi
    
    echo ""
}

clear_memory() {
    # Clears all memory entries (resets to template)
    # Args: $1 = "--force" to skip confirmation
    local force="${1:-}"
    
    if [[ "$force" != "--force" ]]; then
        echo -n "  Clear all memory entries? This cannot be undone. (yes/N): "
        read -r confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "  Cancelled."
            return 1
        fi
    fi
    
    initialize_memory_file
    echo "  Memory cleared."
    return 0
}

# ═══════════════════════════════════════════════════════════════
#                     MENU INTEGRATION
# ═══════════════════════════════════════════════════════════════

show_memory_menu() {
    # Interactive menu for memory management
    local stats
    stats=$(get_memory_stats)
    local enabled total
    enabled=$(echo "$stats" | grep -oP 'enabled=\K\w+')
    total=$(echo "$stats" | grep -oP 'total=\K\d+')
    
    local status_text status_color
    if [[ "$enabled" == "true" ]]; then
        status_text="ON ($total entries)"
        status_color="\033[0;32m"
    else
        status_text="OFF"
        status_color="\033[0;33m"
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  RALPH MEMORY"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo -e "  Status: ${status_color}${status_text}\033[0m"
    echo ""
    
    if [[ "$enabled" == "true" ]]; then
        echo "  [T] Toggle memory OFF"
        echo "  [V] View memory file"
        echo "  [S] Show statistics"
        echo "  [C] Clear all memory"
    else
        echo "  [T] Toggle memory ON"
    fi
    
    echo ""
    echo "  [B] Back"
    echo ""
    
    echo -n "  Choice: "
    read -r choice
    
    case "${choice^^}" in
        T)
            if [[ "$enabled" == "true" ]]; then
                set_memory_enabled "false"
                echo "  Memory disabled."
            else
                set_memory_enabled "true"
                echo "  Memory enabled."
            fi
            echo "toggle"
            ;;
        V)
            if [[ "$enabled" == "true" ]] && [[ -f "$MEMORY_FILE" ]]; then
                echo ""
                cat "$MEMORY_FILE"
                echo ""
                echo -n "  Press Enter to continue"
                read -r
            fi
            echo "view"
            ;;
        S)
            show_memory_status
            echo -n "  Press Enter to continue"
            read -r
            echo "stats"
            ;;
        C)
            if [[ "$enabled" == "true" ]]; then
                clear_memory
            fi
            echo "clear"
            ;;
        B|*)
            echo "back"
            ;;
    esac
}
