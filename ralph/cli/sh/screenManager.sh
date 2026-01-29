#!/bin/sh
# ═══════════════════════════════════════════════════════════════
# Screen Manager for CLI Framework - POSIX Shell Implementation
# ═══════════════════════════════════════════════════════════════
#
# Provides terminal screen management:
# - Cursor positioning and visibility
# - Screen clearing and region clearing
# - Terminal size detection
# - Buffered rendering for flicker-free updates
# - Box drawing characters
#
# Part of the Ralph CLI Framework
# POSIX-compatible
# ═══════════════════════════════════════════════════════════════

# Source color utilities if not already loaded
if [ -z "$RESET" ]; then
    CLI_DIR=$(dirname "$0")
    if [ -f "$CLI_DIR/colorUtils.sh" ]; then
        . "$CLI_DIR/colorUtils.sh"
    fi
fi

# ═══════════════════════════════════════════════════════════════
#                    TERMINAL SIZE
# ═══════════════════════════════════════════════════════════════

# Get terminal width
cli_term_width() {
    if command -v tput >/dev/null 2>&1; then
        tput cols 2>/dev/null || echo 80
    elif [ -n "$COLUMNS" ]; then
        echo "$COLUMNS"
    else
        # Try stty
        stty size 2>/dev/null | cut -d' ' -f2 || echo 80
    fi
}

# Get terminal height
cli_term_height() {
    if command -v tput >/dev/null 2>&1; then
        tput lines 2>/dev/null || echo 24
    elif [ -n "$LINES" ]; then
        echo "$LINES"
    else
        # Try stty
        stty size 2>/dev/null | cut -d' ' -f1 || echo 24
    fi
}

# Get terminal size as "width height"
cli_term_size() {
    printf '%s %s\n' "$(cli_term_width)" "$(cli_term_height)"
}

# ═══════════════════════════════════════════════════════════════
#                    CURSOR CONTROL
# ═══════════════════════════════════════════════════════════════

# Move cursor to position (1-based)
cli_cursor_to() {
    row="${1:-1}"
    col="${2:-1}"
    printf '%s%s;%sH' "$CSI" "$row" "$col"
}

# Move cursor up
cli_cursor_up() {
    lines="${1:-1}"
    printf '%s%sA' "$CSI" "$lines"
}

# Move cursor down
cli_cursor_down() {
    lines="${1:-1}"
    printf '%s%sB' "$CSI" "$lines"
}

# Move cursor right
cli_cursor_right() {
    cols="${1:-1}"
    printf '%s%sC' "$CSI" "$cols"
}

# Move cursor left
cli_cursor_left() {
    cols="${1:-1}"
    printf '%s%sD' "$CSI" "$cols"
}

# Move cursor to column
cli_cursor_col() {
    col="${1:-1}"
    printf '%s%sG' "$CSI" "$col"
}

# Save cursor position
cli_save_cursor() {
    printf '%ss' "$CSI"
}

# Restore cursor position
cli_restore_cursor() {
    printf '%su' "$CSI"
}

# Hide cursor
cli_hide_cursor() {
    printf '%s?25l' "$CSI"
}

# Show cursor
cli_show_cursor() {
    printf '%s?25h' "$CSI"
}

# ═══════════════════════════════════════════════════════════════
#                    SCREEN CLEARING
# ═══════════════════════════════════════════════════════════════

# Clear entire screen
cli_clear_screen() {
    printf '%s2J' "$CSI"
}

# Clear screen and reset cursor
cli_clear_screen_reset() {
    printf '%s2J%sH' "$CSI" "$CSI"
}

# Clear from cursor to end of screen
cli_clear_to_end() {
    printf '%s0J' "$CSI"
}

# Clear from cursor to beginning of screen
cli_clear_to_start() {
    printf '%s1J' "$CSI"
}

# Clear current line
cli_clear_line() {
    printf '%s2K' "$CSI"
}

# Clear from cursor to end of line
cli_clear_line_end() {
    printf '%s0K' "$CSI"
}

# Clear from cursor to beginning of line
cli_clear_line_start() {
    printf '%s1K' "$CSI"
}

# Clear multiple lines (from current position going down)
cli_clear_lines() {
    count="${1:-1}"
    i=0
    while [ $i -lt "$count" ]; do
        cli_clear_line
        if [ $i -lt $((count - 1)) ]; then
            cli_cursor_down
            cli_cursor_col 1
        fi
        i=$((i + 1))
    done
    
    # Return to start
    if [ "$count" -gt 1 ]; then
        cli_cursor_up $((count - 1))
    fi
    cli_cursor_col 1
}

# ═══════════════════════════════════════════════════════════════
#                    ALTERNATE SCREEN
# ═══════════════════════════════════════════════════════════════

# Enter alternate screen buffer
cli_enter_alt_screen() {
    printf '%s?1049h' "$CSI"
    cli_clear_screen_reset
}

# Exit alternate screen buffer
cli_exit_alt_screen() {
    printf '%s?1049l' "$CSI"
}

# ═══════════════════════════════════════════════════════════════
#                    SCROLLING
# ═══════════════════════════════════════════════════════════════

# Set scroll region
cli_set_scroll_region() {
    top="${1:-1}"
    bottom="${2:-$(cli_term_height)}"
    printf '%s%s;%sr' "$CSI" "$top" "$bottom"
}

# Reset scroll region to full screen
cli_reset_scroll_region() {
    printf '%sr' "$CSI"
}

# Scroll up
cli_scroll_up() {
    lines="${1:-1}"
    printf '%s%sS' "$CSI" "$lines"
}

# Scroll down
cli_scroll_down() {
    lines="${1:-1}"
    printf '%s%sT' "$CSI" "$lines"
}

# ═══════════════════════════════════════════════════════════════
#                    BUFFERED RENDERING
# ═══════════════════════════════════════════════════════════════

# Buffer for collecting output
CLI_RENDER_BUFFER=""
CLI_BUFFERING=false

# Start buffered rendering
cli_buffer_start() {
    CLI_RENDER_BUFFER=""
    CLI_BUFFERING=true
    cli_hide_cursor
}

# Add to buffer
cli_buffer_add() {
    if [ "$CLI_BUFFERING" = true ]; then
        CLI_RENDER_BUFFER="${CLI_RENDER_BUFFER}$*"
    else
        printf '%s' "$*"
    fi
}

# Add line to buffer
cli_buffer_line() {
    if [ "$CLI_BUFFERING" = true ]; then
        CLI_RENDER_BUFFER="${CLI_RENDER_BUFFER}$*
"
    else
        printf '%s\n' "$*"
    fi
}

# Flush buffer to screen
cli_buffer_flush() {
    if [ "$CLI_BUFFERING" = true ]; then
        printf '%s' "$CLI_RENDER_BUFFER"
        CLI_RENDER_BUFFER=""
        CLI_BUFFERING=false
    fi
    cli_show_cursor
}

# ═══════════════════════════════════════════════════════════════
#                    VIEWPORT MANAGEMENT
# ═══════════════════════════════════════════════════════════════

# Viewport state (using environment variables)
CLI_VP_ITEMS=0
CLI_VP_HEIGHT=0
CLI_VP_OFFSET=0
CLI_VP_SELECTED=0

# Create viewport
# Usage: cli_viewport_init items visible_height [start_index]
cli_viewport_init() {
    CLI_VP_ITEMS="$1"
    CLI_VP_HEIGHT="$2"
    CLI_VP_OFFSET="${3:-0}"
    CLI_VP_SELECTED="${3:-0}"
    
    # Clamp offset
    max_offset=$((CLI_VP_ITEMS - CLI_VP_HEIGHT))
    if [ "$max_offset" -lt 0 ]; then
        max_offset=0
    fi
    if [ "$CLI_VP_OFFSET" -gt "$max_offset" ]; then
        CLI_VP_OFFSET="$max_offset"
    fi
}

# Update viewport for new selection
# Usage: cli_viewport_update selected_index [margin]
cli_viewport_update() {
    selected="$1"
    margin="${2:-2}"
    
    CLI_VP_SELECTED="$selected"
    
    # Clamp selection
    if [ "$CLI_VP_SELECTED" -lt 0 ]; then
        CLI_VP_SELECTED=0
    fi
    if [ "$CLI_VP_SELECTED" -ge "$CLI_VP_ITEMS" ]; then
        CLI_VP_SELECTED=$((CLI_VP_ITEMS - 1))
    fi
    
    # Scroll up if needed
    scroll_top=$((CLI_VP_OFFSET + margin))
    if [ "$CLI_VP_SELECTED" -lt "$scroll_top" ]; then
        CLI_VP_OFFSET=$((CLI_VP_SELECTED - margin))
    fi
    
    # Scroll down if needed
    scroll_bottom=$((CLI_VP_OFFSET + CLI_VP_HEIGHT - margin - 1))
    if [ "$CLI_VP_SELECTED" -gt "$scroll_bottom" ]; then
        CLI_VP_OFFSET=$((CLI_VP_SELECTED - CLI_VP_HEIGHT + margin + 1))
    fi
    
    # Clamp offset
    if [ "$CLI_VP_OFFSET" -lt 0 ]; then
        CLI_VP_OFFSET=0
    fi
    max_offset=$((CLI_VP_ITEMS - CLI_VP_HEIGHT))
    if [ "$max_offset" -lt 0 ]; then
        max_offset=0
    fi
    if [ "$CLI_VP_OFFSET" -gt "$max_offset" ]; then
        CLI_VP_OFFSET="$max_offset"
    fi
}

# Get viewport range
# Sets CLI_VP_START and CLI_VP_END
cli_viewport_range() {
    CLI_VP_START="$CLI_VP_OFFSET"
    CLI_VP_END=$((CLI_VP_OFFSET + CLI_VP_HEIGHT - 1))
    
    if [ "$CLI_VP_END" -ge "$CLI_VP_ITEMS" ]; then
        CLI_VP_END=$((CLI_VP_ITEMS - 1))
    fi
    
    # Set scroll indicators
    CLI_VP_SCROLL_UP=false
    CLI_VP_SCROLL_DOWN=false
    
    if [ "$CLI_VP_OFFSET" -gt 0 ]; then
        CLI_VP_SCROLL_UP=true
    fi
    
    if [ "$CLI_VP_END" -lt $((CLI_VP_ITEMS - 1)) ]; then
        CLI_VP_SCROLL_DOWN=true
    fi
}

# ═══════════════════════════════════════════════════════════════
#                    BOX DRAWING
# ═══════════════════════════════════════════════════════════════

# Box characters - Light style
BOX_TL='┌'
BOX_TR='┐'
BOX_BL='└'
BOX_BR='┘'
BOX_H='─'
BOX_V='│'

# Double style
BOX_TL_D='╔'
BOX_TR_D='╗'
BOX_BL_D='╚'
BOX_BR_D='╝'
BOX_H_D='═'
BOX_V_D='║'

# Rounded style
BOX_TL_R='╭'
BOX_TR_R='╮'
BOX_BL_R='╰'
BOX_BR_R='╯'

# Draw horizontal line
# Usage: cli_hline width [char]
cli_hline() {
    width="$1"
    char="${2:-$BOX_H}"
    i=0
    while [ $i -lt "$width" ]; do
        printf '%s' "$char"
        i=$((i + 1))
    done
}

# Draw box
# Usage: cli_draw_box width height [style] [title]
cli_draw_box() {
    width="$1"
    height="$2"
    style="${3:-light}"
    title="${4:-}"
    
    # Set characters based on style
    case "$style" in
        double)
            tl="$BOX_TL_D"; tr="$BOX_TR_D"
            bl="$BOX_BL_D"; br="$BOX_BR_D"
            h="$BOX_H_D"; v="$BOX_V_D"
            ;;
        rounded)
            tl="$BOX_TL_R"; tr="$BOX_TR_R"
            bl="$BOX_BL_R"; br="$BOX_BR_R"
            h="$BOX_H"; v="$BOX_V"
            ;;
        *)
            tl="$BOX_TL"; tr="$BOX_TR"
            bl="$BOX_BL"; br="$BOX_BR"
            h="$BOX_H"; v="$BOX_V"
            ;;
    esac
    
    inner_width=$((width - 2))
    
    # Top border
    printf '%s' "$tl"
    if [ -n "$title" ]; then
        printf '%s %s ' "$h" "$title"
        remaining=$((inner_width - ${#title} - 3))
        cli_hline "$remaining" "$h"
    else
        cli_hline "$inner_width" "$h"
    fi
    printf '%s\n' "$tr"
    
    # Sides
    i=0
    while [ $i -lt $((height - 2)) ]; do
        printf '%s' "$v"
        cli_hline "$inner_width" ' '
        printf '%s\n' "$v"
        i=$((i + 1))
    done
    
    # Bottom border
    printf '%s' "$bl"
    cli_hline "$inner_width" "$h"
    printf '%s\n' "$br"
}

# ═══════════════════════════════════════════════════════════════
#                    UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Repeat a string n times
cli_repeat() {
    str="$1"
    count="$2"
    i=0
    while [ $i -lt "$count" ]; do
        printf '%s' "$str"
        i=$((i + 1))
    done
}

# Pad string to length
cli_pad_right() {
    str="$1"
    len="$2"
    char="${3:- }"
    
    printf '%s' "$str"
    padding=$((len - ${#str}))
    if [ "$padding" -gt 0 ]; then
        cli_repeat "$char" "$padding"
    fi
}

cli_pad_left() {
    str="$1"
    len="$2"
    char="${3:- }"
    
    padding=$((len - ${#str}))
    if [ "$padding" -gt 0 ]; then
        cli_repeat "$char" "$padding"
    fi
    printf '%s' "$str"
}

cli_pad_center() {
    str="$1"
    len="$2"
    char="${3:- }"
    
    total_pad=$((len - ${#str}))
    left_pad=$((total_pad / 2))
    right_pad=$((total_pad - left_pad))
    
    cli_repeat "$char" "$left_pad"
    printf '%s' "$str"
    cli_repeat "$char" "$right_pad"
}
