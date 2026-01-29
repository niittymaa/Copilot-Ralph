#!/bin/sh
# ═══════════════════════════════════════════════════════════════
# Color Utilities for CLI Framework - POSIX Shell Implementation
# ═══════════════════════════════════════════════════════════════
#
# Provides cross-platform ANSI escape code support for:
# - Foreground and background colors (16-color, 256-color, RGB)
# - Text styles (bold, dim, italic, underline)
# - Color detection and terminal capability queries
#
# Usage: source this file to get access to color functions
#
# Part of the Ralph CLI Framework
# No external dependencies - POSIX-compatible
# ═══════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════
#                    ESCAPE CODE CONSTANTS
# ═══════════════════════════════════════════════════════════════

# ANSI escape sequence
ESC=$(printf '\033')
CSI="${ESC}["

# Reset all attributes
RESET="${CSI}0m"

# ═══════════════════════════════════════════════════════════════
#                    FOREGROUND COLORS
# ═══════════════════════════════════════════════════════════════

FG_BLACK="${CSI}30m"
FG_RED="${CSI}31m"
FG_GREEN="${CSI}32m"
FG_YELLOW="${CSI}33m"
FG_BLUE="${CSI}34m"
FG_MAGENTA="${CSI}35m"
FG_CYAN="${CSI}36m"
FG_WHITE="${CSI}37m"
FG_DEFAULT="${CSI}39m"

# Bright/high-intensity colors
FG_BRIGHT_BLACK="${CSI}90m"
FG_BRIGHT_RED="${CSI}91m"
FG_BRIGHT_GREEN="${CSI}92m"
FG_BRIGHT_YELLOW="${CSI}93m"
FG_BRIGHT_BLUE="${CSI}94m"
FG_BRIGHT_MAGENTA="${CSI}95m"
FG_BRIGHT_CYAN="${CSI}96m"
FG_BRIGHT_WHITE="${CSI}97m"

# Aliases
FG_GRAY="${FG_BRIGHT_BLACK}"
FG_DARK_GRAY="${FG_BRIGHT_BLACK}"

# ═══════════════════════════════════════════════════════════════
#                    BACKGROUND COLORS
# ═══════════════════════════════════════════════════════════════

BG_BLACK="${CSI}40m"
BG_RED="${CSI}41m"
BG_GREEN="${CSI}42m"
BG_YELLOW="${CSI}43m"
BG_BLUE="${CSI}44m"
BG_MAGENTA="${CSI}45m"
BG_CYAN="${CSI}46m"
BG_WHITE="${CSI}47m"
BG_DEFAULT="${CSI}49m"

BG_BRIGHT_BLACK="${CSI}100m"
BG_BRIGHT_RED="${CSI}101m"
BG_BRIGHT_GREEN="${CSI}102m"
BG_BRIGHT_YELLOW="${CSI}103m"
BG_BRIGHT_BLUE="${CSI}104m"
BG_BRIGHT_MAGENTA="${CSI}105m"
BG_BRIGHT_CYAN="${CSI}106m"
BG_BRIGHT_WHITE="${CSI}107m"

# ═══════════════════════════════════════════════════════════════
#                    TEXT STYLES
# ═══════════════════════════════════════════════════════════════

STYLE_BOLD="${CSI}1m"
STYLE_DIM="${CSI}2m"
STYLE_ITALIC="${CSI}3m"
STYLE_UNDERLINE="${CSI}4m"
STYLE_BLINK="${CSI}5m"
STYLE_REVERSE="${CSI}7m"
STYLE_HIDDEN="${CSI}8m"
STYLE_STRIKETHROUGH="${CSI}9m"

STYLE_NO_BOLD="${CSI}22m"
STYLE_NO_DIM="${CSI}22m"
STYLE_NO_ITALIC="${CSI}23m"
STYLE_NO_UNDERLINE="${CSI}24m"
STYLE_NO_BLINK="${CSI}25m"
STYLE_NO_REVERSE="${CSI}27m"
STYLE_NO_HIDDEN="${CSI}28m"
STYLE_NO_STRIKETHROUGH="${CSI}29m"

# ═══════════════════════════════════════════════════════════════
#                    COLOR DETECTION
# ═══════════════════════════════════════════════════════════════

# Check if terminal supports colors
# Returns 0 (true) if colors supported, 1 (false) otherwise
cli_test_color_support() {
    # Check for dumb terminal
    if [ "$TERM" = "dumb" ] || [ -z "$TERM" ]; then
        return 1
    fi
    
    # Check if stdout is a terminal
    if [ ! -t 1 ]; then
        return 1
    fi
    
    # Check TERM for color support
    case "$TERM" in
        *color*|xterm*|screen*|linux|vt100|ansi)
            return 0
            ;;
    esac
    
    # Check COLORTERM
    if [ -n "$COLORTERM" ]; then
        return 0
    fi
    
    # Default to supporting colors for most terminals
    return 0
}

# Check for true color (24-bit) support
cli_test_truecolor_support() {
    if [ "$COLORTERM" = "truecolor" ] || [ "$COLORTERM" = "24bit" ]; then
        return 0
    fi
    
    case "$TERM" in
        *-truecolor|*-24bit)
            return 0
            ;;
    esac
    
    return 1
}

# ═══════════════════════════════════════════════════════════════
#                    COLOR FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Get foreground color by name
# Usage: cli_fg_color "red"
cli_fg_color() {
    case "$1" in
        black)        printf '%s' "$FG_BLACK" ;;
        red)          printf '%s' "$FG_RED" ;;
        green)        printf '%s' "$FG_GREEN" ;;
        yellow)       printf '%s' "$FG_YELLOW" ;;
        blue)         printf '%s' "$FG_BLUE" ;;
        magenta)      printf '%s' "$FG_MAGENTA" ;;
        cyan)         printf '%s' "$FG_CYAN" ;;
        white)        printf '%s' "$FG_WHITE" ;;
        gray|grey)    printf '%s' "$FG_GRAY" ;;
        bright_black) printf '%s' "$FG_BRIGHT_BLACK" ;;
        bright_red)   printf '%s' "$FG_BRIGHT_RED" ;;
        bright_green) printf '%s' "$FG_BRIGHT_GREEN" ;;
        bright_yellow) printf '%s' "$FG_BRIGHT_YELLOW" ;;
        bright_blue)  printf '%s' "$FG_BRIGHT_BLUE" ;;
        bright_magenta) printf '%s' "$FG_BRIGHT_MAGENTA" ;;
        bright_cyan)  printf '%s' "$FG_BRIGHT_CYAN" ;;
        bright_white) printf '%s' "$FG_BRIGHT_WHITE" ;;
        *)            printf '%s' "$FG_DEFAULT" ;;
    esac
}

# Get background color by name
# Usage: cli_bg_color "blue"
cli_bg_color() {
    case "$1" in
        black)        printf '%s' "$BG_BLACK" ;;
        red)          printf '%s' "$BG_RED" ;;
        green)        printf '%s' "$BG_GREEN" ;;
        yellow)       printf '%s' "$BG_YELLOW" ;;
        blue)         printf '%s' "$BG_BLUE" ;;
        magenta)      printf '%s' "$BG_MAGENTA" ;;
        cyan)         printf '%s' "$BG_CYAN" ;;
        white)        printf '%s' "$BG_WHITE" ;;
        *)            printf '%s' "$BG_DEFAULT" ;;
    esac
}

# Get 256-color foreground
# Usage: cli_fg_256 42
cli_fg_256() {
    printf '%s' "${CSI}38;5;${1}m"
}

# Get 256-color background
# Usage: cli_bg_256 42
cli_bg_256() {
    printf '%s' "${CSI}48;5;${1}m"
}

# Get RGB foreground color
# Usage: cli_fg_rgb 255 128 0
cli_fg_rgb() {
    printf '%s' "${CSI}38;2;${1};${2};${3}m"
}

# Get RGB background color
# Usage: cli_bg_rgb 255 128 0
cli_bg_rgb() {
    printf '%s' "${CSI}48;2;${1};${2};${3}m"
}

# Get hex color as RGB foreground
# Usage: cli_fg_hex "FF8800" or cli_fg_hex "#FF8800"
cli_fg_hex() {
    hex="${1#\#}"
    r=$((16#${hex%????}))
    g=$((16#${hex#??}))
    g=$((g >> 8))
    b=$((16#${hex#????}))
    cli_fg_rgb "$r" "$g" "$b"
}

# ═══════════════════════════════════════════════════════════════
#                    TEXT FORMATTING
# ═══════════════════════════════════════════════════════════════

# Format text with color and style
# Usage: cli_format "text" "color" "style"
# Example: cli_format "Hello" "green" "bold"
cli_format() {
    text="$1"
    color="${2:-}"
    style="${3:-}"
    
    prefix=""
    
    # Apply style
    case "$style" in
        bold)          prefix="${prefix}${STYLE_BOLD}" ;;
        dim)           prefix="${prefix}${STYLE_DIM}" ;;
        italic)        prefix="${prefix}${STYLE_ITALIC}" ;;
        underline)     prefix="${prefix}${STYLE_UNDERLINE}" ;;
        strikethrough) prefix="${prefix}${STYLE_STRIKETHROUGH}" ;;
    esac
    
    # Apply color
    if [ -n "$color" ]; then
        prefix="${prefix}$(cli_fg_color "$color")"
    fi
    
    printf '%s%s%s' "$prefix" "$text" "$RESET"
}

# Print colored text
# Usage: cli_print "message" "color"
cli_print() {
    printf '%s%s%s\n' "$(cli_fg_color "$2")" "$1" "$RESET"
}

# Print colored text without newline
# Usage: cli_print_n "message" "color"
cli_print_n() {
    printf '%s%s%s' "$(cli_fg_color "$2")" "$1" "$RESET"
}

# Print styled message types
cli_info() {
    printf '  %sℹ%s %s\n' "$FG_CYAN" "$RESET" "$1"
}

cli_success() {
    printf '  %s✓%s %s\n' "$FG_GREEN" "$RESET" "$1"
}

cli_warning() {
    printf '  %s⚠%s %s\n' "$FG_YELLOW" "$RESET" "$1"
}

cli_error() {
    printf '  %s✗%s %s\n' "$FG_BRIGHT_RED" "$RESET" "$1"
}

cli_debug() {
    printf '  %s●%s %s\n' "$FG_GRAY" "$RESET" "$1"
}
