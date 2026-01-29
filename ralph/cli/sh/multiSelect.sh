#!/bin/sh
# ═══════════════════════════════════════════════════════════════
# Multi-Select for CLI Framework - POSIX Shell Implementation
# ═══════════════════════════════════════════════════════════════
#
# Provides multi-selection capabilities:
# - Checkbox-style selection with spacebar toggle
# - Select all / deselect all
# - Visual feedback
#
# Part of the Ralph CLI Framework
# POSIX-compatible
# ═══════════════════════════════════════════════════════════════

# Source dependencies
CLI_DIR=$(dirname "$0")
if [ -f "$CLI_DIR/colorUtils.sh" ]; then
    . "$CLI_DIR/colorUtils.sh"
fi
if [ -f "$CLI_DIR/keyReader.sh" ]; then
    . "$CLI_DIR/keyReader.sh"
fi
if [ -f "$CLI_DIR/screenManager.sh" ]; then
    . "$CLI_DIR/screenManager.sh"
fi

# ═══════════════════════════════════════════════════════════════
#                    CONFIGURATION
# ═══════════════════════════════════════════════════════════════

MS_CHECKED='[✓]'
MS_UNCHECKED='[ ]'
MS_FOCUSED='❯'
MS_UNFOCUSED=' '
MS_INDENT='  '

# ═══════════════════════════════════════════════════════════════
#                    ITEM STORAGE
# ═══════════════════════════════════════════════════════════════

# Multi-select items stored as indexed variables
MS_ITEM_COUNT=0

# Clear all items
cli_ms_clear() {
    i=0
    while [ $i -lt "$MS_ITEM_COUNT" ]; do
        unset "MS_ITEM_${i}_TEXT"
        unset "MS_ITEM_${i}_VALUE"
        unset "MS_ITEM_${i}_CHECKED"
        unset "MS_ITEM_${i}_DISABLED"
        i=$((i + 1))
    done
    MS_ITEM_COUNT=0
}

# Add item
# Usage: cli_ms_add "text" "value" [checked] [disabled]
cli_ms_add() {
    eval "MS_ITEM_${MS_ITEM_COUNT}_TEXT=\"\$1\""
    eval "MS_ITEM_${MS_ITEM_COUNT}_VALUE=\"\${2:-\$1}\""
    eval "MS_ITEM_${MS_ITEM_COUNT}_CHECKED=\"\${3:-false}\""
    eval "MS_ITEM_${MS_ITEM_COUNT}_DISABLED=\"\${4:-false}\""
    MS_ITEM_COUNT=$((MS_ITEM_COUNT + 1))
}

# Get item property
cli_ms_get() {
    idx="$1"
    prop="$2"
    eval "printf '%s' \"\$MS_ITEM_${idx}_${prop}\""
}

# Set item property
cli_ms_set() {
    idx="$1"
    prop="$2"
    val="$3"
    eval "MS_ITEM_${idx}_${prop}=\"\$val\""
}

# Toggle item checked state
cli_ms_toggle() {
    idx="$1"
    current=$(cli_ms_get "$idx" "CHECKED")
    if [ "$current" = "true" ]; then
        cli_ms_set "$idx" "CHECKED" "false"
    else
        cli_ms_set "$idx" "CHECKED" "true"
    fi
}

# ═══════════════════════════════════════════════════════════════
#                    RENDERING
# ═══════════════════════════════════════════════════════════════

# Format selection counter
cli_format_counter() {
    selected="$1"
    total="$2"
    min="${3:-0}"
    max="${4:-0}"
    
    printf '%s%s%s%s/%s selected' "$MS_INDENT" "$FG_YELLOW" "$selected" "$RESET" "$total"
    
    if [ "$min" -gt 0 ] && [ "$selected" -lt "$min" ]; then
        printf ' %s(min: %s)%s' "$FG_BRIGHT_RED" "$min" "$RESET"
    elif [ "$max" -gt 0 ] && [ "$selected" -gt "$max" ]; then
        printf ' %s(max: %s)%s' "$FG_BRIGHT_RED" "$max" "$RESET"
    fi
}

# Format multi-select item
cli_format_ms_item() {
    idx="$1"
    focused="$2"
    
    text=$(cli_ms_get "$idx" "TEXT")
    checked=$(cli_ms_get "$idx" "CHECKED")
    disabled=$(cli_ms_get "$idx" "DISABLED")
    
    # Focus indicator
    if [ "$focused" = "true" ]; then
        focus="${FG_CYAN}${MS_FOCUSED}${RESET}"
    else
        focus="$MS_UNFOCUSED"
    fi
    
    # Checkbox
    if [ "$disabled" = "true" ]; then
        checkbox="${FG_GRAY}${MS_UNCHECKED}${RESET}"
    elif [ "$checked" = "true" ]; then
        checkbox="${FG_GREEN}${MS_CHECKED}${RESET}"
    else
        checkbox="$MS_UNCHECKED"
    fi
    
    # Text
    if [ "$disabled" = "true" ]; then
        text_fmt="${FG_GRAY}${text}${RESET}"
    elif [ "$focused" = "true" ]; then
        text_fmt="${STYLE_BOLD}${FG_BRIGHT_WHITE}${text}${RESET}"
    else
        text_fmt="$text"
    fi
    
    printf '%s%s %s %s' "$MS_INDENT" "$focus" "$checkbox" "$text_fmt"
}

# ═══════════════════════════════════════════════════════════════
#                    MULTI-SELECT MENU
# ═══════════════════════════════════════════════════════════════

# Build list of selectable indices
cli_ms_build_selectable() {
    MS_SELECTABLE=""
    MS_SELECTABLE_COUNT=0
    
    i=0
    while [ $i -lt "$MS_ITEM_COUNT" ]; do
        disabled=$(cli_ms_get "$i" "DISABLED")
        if [ "$disabled" != "true" ]; then
            if [ -n "$MS_SELECTABLE" ]; then
                MS_SELECTABLE="${MS_SELECTABLE} ${i}"
            else
                MS_SELECTABLE="$i"
            fi
            MS_SELECTABLE_COUNT=$((MS_SELECTABLE_COUNT + 1))
        fi
        i=$((i + 1))
    done
}

# Get nth selectable index
cli_ms_selectable_at() {
    n="$1"
    echo "$MS_SELECTABLE" | tr ' ' '\n' | sed -n "$((n + 1))p"
}

# Count checked items
cli_ms_count_checked() {
    count=0
    i=0
    while [ $i -lt "$MS_ITEM_COUNT" ]; do
        checked=$(cli_ms_get "$i" "CHECKED")
        if [ "$checked" = "true" ]; then
            count=$((count + 1))
        fi
        i=$((i + 1))
    done
    echo "$count"
}

# Get checked values as space-separated string
cli_ms_get_checked() {
    result=""
    i=0
    while [ $i -lt "$MS_ITEM_COUNT" ]; do
        checked=$(cli_ms_get "$i" "CHECKED")
        if [ "$checked" = "true" ]; then
            value=$(cli_ms_get "$i" "VALUE")
            if [ -n "$result" ]; then
                result="${result} ${value}"
            else
                result="$value"
            fi
        fi
        i=$((i + 1))
    done
    echo "$result"
}

# Show multi-select menu
# Usage: cli_show_multiselect "title" [description] [min] [max] [page_size]
# Result stored in MS_RESULT (space-separated values)
cli_show_multiselect() {
    title="${1:-}"
    description="${2:-}"
    min_select="${3:-0}"
    max_select="${4:-0}"
    page_size="${5:-0}"
    
    MS_RESULT=""
    
    # Build selectable list
    cli_ms_build_selectable
    
    if [ "$MS_SELECTABLE_COUNT" -eq 0 ]; then
        cli_error "No selectable items"
        return 1
    fi
    
    # Initialize
    current_pos=0
    current_index=$(cli_ms_selectable_at 0)
    
    # Calculate visible height
    term_height=$(cli_term_height)
    visible_height=$((term_height - 10))
    if [ "$page_size" -gt 0 ] && [ "$page_size" -lt "$visible_height" ]; then
        visible_height="$page_size"
    fi
    if [ "$visible_height" -gt "$MS_ITEM_COUNT" ]; then
        visible_height="$MS_ITEM_COUNT"
    fi
    
    # Initialize viewport
    cli_viewport_init "$MS_ITEM_COUNT" "$visible_height" 0
    
    first_render=true
    total_lines=0
    
    cli_hide_cursor
    
    while true; do
        # Count selections
        selected_count=$(cli_ms_count_checked)
        
        # Calculate total lines
        new_total=0
        if [ -n "$title" ]; then new_total=$((new_total + 2)); fi
        if [ -n "$description" ]; then new_total=$((new_total + 1)); fi
        new_total=$((new_total + 2))  # counter + blank
        new_total=$((new_total + visible_height + 4))  # items + scroll + hints
        
        # Clear previous
        if [ "$first_render" = false ]; then
            cli_cursor_up "$total_lines"
        fi
        first_render=false
        total_lines="$new_total"
        
        # Update viewport
        cli_viewport_update "$current_index"
        cli_viewport_range
        
        # Title
        if [ -n "$title" ] || [ -n "$description" ]; then
            cli_format_title "$title" "$description"
        fi
        
        # Counter
        cli_format_counter "$selected_count" "$MS_SELECTABLE_COUNT" "$min_select" "$max_select"
        printf '\n\n'
        
        # Scroll up indicator
        if [ "$CLI_VP_SCROLL_UP" = true ]; then
            cli_format_scroll "up"
        fi
        printf '\n'
        
        # Render visible items
        i="$CLI_VP_START"
        while [ $i -le "$CLI_VP_END" ]; do
            is_focused="false"
            if [ "$i" = "$current_index" ]; then
                is_focused="true"
            fi
            cli_format_ms_item "$i" "$is_focused"
            printf '\n'
            i=$((i + 1))
        done
        
        # Scroll down indicator
        if [ "$CLI_VP_SCROLL_DOWN" = true ]; then
            cli_format_scroll "down"
        fi
        printf '\n'
        
        # Help
        printf '%s%s↑↓ Move  Space Toggle  A All  N None  Enter Confirm  Esc Cancel%s\n' \
            "$MS_INDENT" "$FG_GRAY" "$RESET"
        
        # Read key
        cli_read_nav_key "an"
        
        case "$CLI_KEY_ACTION" in
            up)
                if [ "$current_pos" -gt 0 ]; then
                    current_pos=$((current_pos - 1))
                else
                    current_pos=$((MS_SELECTABLE_COUNT - 1))
                fi
                current_index=$(cli_ms_selectable_at "$current_pos")
                ;;
                
            down)
                if [ "$current_pos" -lt $((MS_SELECTABLE_COUNT - 1)) ]; then
                    current_pos=$((current_pos + 1))
                else
                    current_pos=0
                fi
                current_index=$(cli_ms_selectable_at "$current_pos")
                ;;
                
            home)
                current_pos=0
                current_index=$(cli_ms_selectable_at 0)
                ;;
                
            end)
                current_pos=$((MS_SELECTABLE_COUNT - 1))
                current_index=$(cli_ms_selectable_at "$current_pos")
                ;;
                
            space)
                disabled=$(cli_ms_get "$current_index" "DISABLED")
                if [ "$disabled" != "true" ]; then
                    checked=$(cli_ms_get "$current_index" "CHECKED")
                    
                    # Check max limit
                    if [ "$checked" != "true" ] && [ "$max_select" -gt 0 ]; then
                        if [ "$selected_count" -ge "$max_select" ]; then
                            continue
                        fi
                    fi
                    
                    cli_ms_toggle "$current_index"
                fi
                ;;
                
            a)
                # Select all (up to max)
                i=0
                count=0
                while [ $i -lt "$MS_ITEM_COUNT" ]; do
                    disabled=$(cli_ms_get "$i" "DISABLED")
                    if [ "$disabled" != "true" ]; then
                        if [ "$max_select" -eq 0 ] || [ "$count" -lt "$max_select" ]; then
                            cli_ms_set "$i" "CHECKED" "true"
                            count=$((count + 1))
                        fi
                    fi
                    i=$((i + 1))
                done
                ;;
                
            n)
                # Deselect all
                i=0
                while [ $i -lt "$MS_ITEM_COUNT" ]; do
                    disabled=$(cli_ms_get "$i" "DISABLED")
                    if [ "$disabled" != "true" ]; then
                        cli_ms_set "$i" "CHECKED" "false"
                    fi
                    i=$((i + 1))
                done
                ;;
                
            select)
                # Validate
                selected_count=$(cli_ms_count_checked)
                
                if [ "$min_select" -gt 0 ] && [ "$selected_count" -lt "$min_select" ]; then
                    continue
                fi
                
                MS_RESULT=$(cli_ms_get_checked)
                cli_show_cursor
                return 0
                ;;
                
            cancel)
                MS_RESULT=""
                cli_show_cursor
                return 1
                ;;
        esac
    done
}

# Quick multi-select from simple list
# Usage: cli_quick_multiselect "title" "option1" "option2" ...
cli_quick_multiselect() {
    title="$1"
    shift
    
    cli_ms_clear
    for opt in "$@"; do
        cli_ms_add "$opt" "$opt"
    done
    
    cli_show_multiselect "$title"
}
