#!/bin/sh
# ═══════════════════════════════════════════════════════════════
# Menu Renderer for CLI Framework - POSIX Shell Implementation
# ═══════════════════════════════════════════════════════════════
#
# Provides menu rendering capabilities:
# - Single-select menus with arrow navigation
# - Highlighted selection indicators
# - Scrollable menus for large lists
# - Separator and header support
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

# Selection indicators
MENU_INDICATOR_SELECTED='❯'
MENU_INDICATOR_UNSELECTED=' '
MENU_INDENT='  '

# ═══════════════════════════════════════════════════════════════
#                    MENU ITEM STORAGE
# ═══════════════════════════════════════════════════════════════

# Menu items stored as indexed variables
# MENU_ITEM_0_TEXT, MENU_ITEM_0_VALUE, MENU_ITEM_0_TYPE, etc.
MENU_ITEM_COUNT=0

# Clear all menu items
cli_menu_clear() {
    i=0
    while [ $i -lt "$MENU_ITEM_COUNT" ]; do
        unset "MENU_ITEM_${i}_TEXT"
        unset "MENU_ITEM_${i}_VALUE"
        unset "MENU_ITEM_${i}_TYPE"
        unset "MENU_ITEM_${i}_HOTKEY"
        unset "MENU_ITEM_${i}_DISABLED"
        i=$((i + 1))
    done
    MENU_ITEM_COUNT=0
}

# Add a menu item
# Usage: cli_menu_add "text" "value" [type] [hotkey] [disabled]
cli_menu_add() {
    eval "MENU_ITEM_${MENU_ITEM_COUNT}_TEXT=\"\$1\""
    eval "MENU_ITEM_${MENU_ITEM_COUNT}_VALUE=\"\${2:-\$1}\""
    eval "MENU_ITEM_${MENU_ITEM_COUNT}_TYPE=\"\${3:-item}\""
    eval "MENU_ITEM_${MENU_ITEM_COUNT}_HOTKEY=\"\${4:-}\""
    eval "MENU_ITEM_${MENU_ITEM_COUNT}_DISABLED=\"\${5:-false}\""
    MENU_ITEM_COUNT=$((MENU_ITEM_COUNT + 1))
}

# Add separator
cli_menu_separator() {
    cli_menu_add "${1:-}" "" "separator"
}

# Add header
cli_menu_header() {
    cli_menu_add "$1" "" "header"
}

# Get item property
cli_menu_get() {
    idx="$1"
    prop="$2"
    eval "printf '%s' \"\$MENU_ITEM_${idx}_${prop}\""
}

# ═══════════════════════════════════════════════════════════════
#                    RENDERING
# ═══════════════════════════════════════════════════════════════

# Format menu title
cli_format_title() {
    title="$1"
    desc="${2:-}"
    
    if [ -n "$title" ]; then
        printf '\n%s%s%s%s%s\n' "$MENU_INDENT" "$STYLE_BOLD" "$FG_CYAN" "$title" "$RESET"
    fi
    
    if [ -n "$desc" ]; then
        printf '%s%s%s%s\n' "$MENU_INDENT" "$FG_GRAY" "$desc" "$RESET"
    fi
}

# Format a menu item
# Usage: cli_format_item index is_selected
cli_format_item() {
    idx="$1"
    selected="$2"
    
    text=$(cli_menu_get "$idx" "TEXT")
    type=$(cli_menu_get "$idx" "TYPE")
    hotkey=$(cli_menu_get "$idx" "HOTKEY")
    disabled=$(cli_menu_get "$idx" "DISABLED")
    
    case "$type" in
        separator)
            if [ -n "$text" ]; then
                printf '%s%s─── %s %s%s' "$MENU_INDENT" "$FG_GRAY" "$text" "$(cli_hline 30)" "$RESET"
            else
                printf '%s%s%s%s' "$MENU_INDENT" "$FG_GRAY" "$(cli_hline 40)" "$RESET"
            fi
            ;;
            
        header)
            printf '\n%s%s%s%s%s' "$MENU_INDENT" "$STYLE_BOLD" "$FG_MAGENTA" "$text" "$RESET"
            ;;
            
        *)
            # Regular item
            if [ "$selected" = "true" ]; then
                indicator="${FG_CYAN}${MENU_INDICATOR_SELECTED}${RESET}"
            else
                indicator="$MENU_INDICATOR_UNSELECTED"
            fi
            
            printf '%s%s ' "$MENU_INDENT" "$indicator"
            
            # Hotkey
            if [ -n "$hotkey" ]; then
                if [ "$disabled" = "true" ]; then
                    printf '%s[%s]%s ' "$FG_GRAY" "$hotkey" "$RESET"
                else
                    printf '%s[%s]%s ' "$FG_YELLOW" "$hotkey" "$RESET"
                fi
            fi
            
            # Text
            if [ "$disabled" = "true" ]; then
                printf '%s%s%s' "$FG_GRAY" "$text" "$RESET"
            elif [ "$selected" = "true" ]; then
                printf '%s%s%s%s' "$STYLE_BOLD" "$FG_BRIGHT_WHITE" "$text" "$RESET"
            else
                printf '%s' "$text"
            fi
            ;;
    esac
}

# Format scroll indicator
cli_format_scroll() {
    direction="$1"
    
    if [ "$direction" = "up" ]; then
        printf '%s  %s▲ more above%s' "$MENU_INDENT" "$FG_GRAY" "$RESET"
    else
        printf '%s  %s▼ more below%s' "$MENU_INDENT" "$FG_GRAY" "$RESET"
    fi
}

# ═══════════════════════════════════════════════════════════════
#                    MENU DISPLAY
# ═══════════════════════════════════════════════════════════════

# Build list of selectable indices
cli_build_selectable() {
    MENU_SELECTABLE=""
    MENU_SELECTABLE_COUNT=0
    
    i=0
    while [ $i -lt "$MENU_ITEM_COUNT" ]; do
        type=$(cli_menu_get "$i" "TYPE")
        disabled=$(cli_menu_get "$i" "DISABLED")
        
        if [ "$type" = "item" ] && [ "$disabled" != "true" ]; then
            if [ -n "$MENU_SELECTABLE" ]; then
                MENU_SELECTABLE="${MENU_SELECTABLE} ${i}"
            else
                MENU_SELECTABLE="$i"
            fi
            MENU_SELECTABLE_COUNT=$((MENU_SELECTABLE_COUNT + 1))
        fi
        i=$((i + 1))
    done
}

# Get nth selectable index
cli_selectable_at() {
    n="$1"
    echo "$MENU_SELECTABLE" | tr ' ' '\n' | sed -n "$((n + 1))p"
}

# Find position of index in selectable list
cli_selectable_pos() {
    target="$1"
    pos=0
    for idx in $MENU_SELECTABLE; do
        if [ "$idx" = "$target" ]; then
            echo "$pos"
            return
        fi
        pos=$((pos + 1))
    done
    echo "0"
}

# Show single-select menu
# Usage: cli_show_menu "title" [description] [default_index] [page_size]
# Result is stored in MENU_RESULT (value) or empty if cancelled
cli_show_menu() {
    title="${1:-}"
    description="${2:-}"
    default_index="${3:-0}"
    page_size="${4:-0}"
    
    MENU_RESULT=""
    
    # Build selectable list
    cli_build_selectable
    
    if [ "$MENU_SELECTABLE_COUNT" -eq 0 ]; then
        cli_error "No selectable items in menu"
        return 1
    fi
    
    # Initialize selection
    current_pos=0
    if [ "$default_index" -gt 0 ]; then
        type=$(cli_menu_get "$default_index" "TYPE")
        disabled=$(cli_menu_get "$default_index" "DISABLED")
        if [ "$type" = "item" ] && [ "$disabled" != "true" ]; then
            current_pos=$(cli_selectable_pos "$default_index")
        fi
    fi
    current_index=$(cli_selectable_at "$current_pos")
    
    # Calculate visible height
    term_height=$(cli_term_height)
    visible_height=$((term_height - 8))
    if [ "$page_size" -gt 0 ] && [ "$page_size" -lt "$visible_height" ]; then
        visible_height="$page_size"
    fi
    if [ "$visible_height" -gt "$MENU_ITEM_COUNT" ]; then
        visible_height="$MENU_ITEM_COUNT"
    fi
    
    # Initialize viewport
    cli_viewport_init "$MENU_ITEM_COUNT" "$visible_height" "$current_index"
    
    # Build hotkey lookup
    hotkey_list=""
    i=0
    while [ $i -lt "$MENU_ITEM_COUNT" ]; do
        hk=$(cli_menu_get "$i" "HOTKEY")
        if [ -n "$hk" ]; then
            hotkey_list="${hotkey_list}$(echo "$hk" | tr '[:upper:]' '[:lower:]')"
        fi
        i=$((i + 1))
    done
    
    first_render=true
    total_lines=0
    
    cli_hide_cursor
    
    # Render loop
    while true; do
        # Calculate total lines for redraw
        new_total=0
        if [ -n "$title" ]; then new_total=$((new_total + 2)); fi
        if [ -n "$description" ]; then new_total=$((new_total + 1)); fi
        new_total=$((new_total + visible_height + 4))  # items + scroll + hints
        
        # Clear previous render
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
        
        # Scroll up indicator
        if [ "$CLI_VP_SCROLL_UP" = true ]; then
            cli_format_scroll "up"
        else
            printf ''
        fi
        printf '\n'
        
        # Render visible items
        i="$CLI_VP_START"
        while [ $i -le "$CLI_VP_END" ]; do
            is_selected="false"
            if [ "$i" = "$current_index" ]; then
                is_selected="true"
            fi
            cli_format_item "$i" "$is_selected"
            printf '\n'
            i=$((i + 1))
        done
        
        # Scroll down indicator
        if [ "$CLI_VP_SCROLL_DOWN" = true ]; then
            cli_format_scroll "down"
        else
            printf ''
        fi
        printf '\n'
        
        # Help text
        printf '%s%s↑↓ Navigate  Enter Select  Esc Cancel%s\n' "$MENU_INDENT" "$FG_GRAY" "$RESET"
        
        # Read key
        cli_read_nav_key "$hotkey_list"
        
        case "$CLI_KEY_ACTION" in
            up)
                if [ "$current_pos" -gt 0 ]; then
                    current_pos=$((current_pos - 1))
                else
                    current_pos=$((MENU_SELECTABLE_COUNT - 1))
                fi
                current_index=$(cli_selectable_at "$current_pos")
                ;;
                
            down)
                if [ "$current_pos" -lt $((MENU_SELECTABLE_COUNT - 1)) ]; then
                    current_pos=$((current_pos + 1))
                else
                    current_pos=0
                fi
                current_index=$(cli_selectable_at "$current_pos")
                ;;
                
            home)
                current_pos=0
                current_index=$(cli_selectable_at "$current_pos")
                ;;
                
            end)
                current_pos=$((MENU_SELECTABLE_COUNT - 1))
                current_index=$(cli_selectable_at "$current_pos")
                ;;
                
            pageup)
                current_pos=$((current_pos - visible_height))
                if [ "$current_pos" -lt 0 ]; then
                    current_pos=0
                fi
                current_index=$(cli_selectable_at "$current_pos")
                ;;
                
            pagedown)
                current_pos=$((current_pos + visible_height))
                if [ "$current_pos" -ge "$MENU_SELECTABLE_COUNT" ]; then
                    current_pos=$((MENU_SELECTABLE_COUNT - 1))
                fi
                current_index=$(cli_selectable_at "$current_pos")
                ;;
                
            select)
                MENU_RESULT=$(cli_menu_get "$current_index" "VALUE")
                cli_show_cursor
                return 0
                ;;
                
            cancel)
                MENU_RESULT=""
                cli_show_cursor
                return 1
                ;;
                
            *)
                # Check for hotkey match
                if [ -n "$CLI_KEY_ACTION" ]; then
                    i=0
                    while [ $i -lt "$MENU_ITEM_COUNT" ]; do
                        hk=$(cli_menu_get "$i" "HOTKEY")
                        type=$(cli_menu_get "$i" "TYPE")
                        disabled=$(cli_menu_get "$i" "DISABLED")
                        
                        if [ -n "$hk" ]; then
                            hk_lower=$(echo "$hk" | tr '[:upper:]' '[:lower:]')
                            if [ "$hk_lower" = "$CLI_KEY_ACTION" ] && 
                               [ "$type" = "item" ] && 
                               [ "$disabled" != "true" ]; then
                                MENU_RESULT=$(cli_menu_get "$i" "VALUE")
                                cli_show_cursor
                                return 0
                            fi
                        fi
                        i=$((i + 1))
                    done
                fi
                ;;
        esac
    done
}

# Quick menu from simple list
# Usage: cli_quick_menu "title" "option1" "option2" "option3" ...
# Result in MENU_RESULT
cli_quick_menu() {
    title="$1"
    shift
    
    cli_menu_clear
    for opt in "$@"; do
        cli_menu_add "$opt" "$opt"
    done
    
    cli_show_menu "$title"
}
