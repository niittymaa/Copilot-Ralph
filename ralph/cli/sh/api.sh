#!/bin/sh
# ═══════════════════════════════════════════════════════════════
# Unified CLI Framework API - POSIX Shell Implementation
# ═══════════════════════════════════════════════════════════════
#
# Provides a clean, high-level API for CLI interactions:
# - cli_show_menu - Single-select menu
# - cli_show_multiselect - Multi-select with checkboxes
# - cli_prompt_input - Text input with validation
# - cli_confirm - Yes/No confirmation
# - cli_show_progress - Progress indicator
# - cli_show_banner - Styled header
#
# This module loads and coordinates all other CLI modules.
#
# Part of the Ralph CLI Framework
# POSIX-compatible - no bash-specific features
# ═══════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════
#                    MODULE LOADING
# ═══════════════════════════════════════════════════════════════

CLI_API_DIR=$(dirname "$0")

# Load all dependent modules
if [ -f "$CLI_API_DIR/colorUtils.sh" ]; then
    . "$CLI_API_DIR/colorUtils.sh"
fi

if [ -f "$CLI_API_DIR/keyReader.sh" ]; then
    . "$CLI_API_DIR/keyReader.sh"
fi

if [ -f "$CLI_API_DIR/screenManager.sh" ]; then
    . "$CLI_API_DIR/screenManager.sh"
fi

if [ -f "$CLI_API_DIR/menuRenderer.sh" ]; then
    . "$CLI_API_DIR/menuRenderer.sh"
fi

if [ -f "$CLI_API_DIR/multiSelect.sh" ]; then
    . "$CLI_API_DIR/multiSelect.sh"
fi

if [ -f "$CLI_API_DIR/inputHandler.sh" ]; then
    . "$CLI_API_DIR/inputHandler.sh"
fi

# ═══════════════════════════════════════════════════════════════
#                    HIGH-LEVEL API
# ═══════════════════════════════════════════════════════════════

# Show a single-select menu
# Usage: cli_api_menu "title" "option1" "option2" ...
# Result in MENU_RESULT
cli_api_menu() {
    title="$1"
    shift
    cli_quick_menu "$title" "$@"
}

# Show multi-select menu
# Usage: cli_api_multiselect "title" "option1" "option2" ...
# Result in MS_RESULT (space-separated)
cli_api_multiselect() {
    title="$1"
    shift
    cli_quick_multiselect "$title" "$@"
}

# Prompt for text input
# Usage: cli_api_input "prompt" [default] [required]
# Result in INPUT_RESULT
cli_api_input() {
    cli_input_text "$1" "${2:-}" "${3:-false}"
}

# Prompt for password
# Usage: cli_api_password "prompt" [required]
# Result in INPUT_RESULT
cli_api_password() {
    cli_input_password "$1" "${2:-false}"
}

# Prompt for number
# Usage: cli_api_number "prompt" [default] [min] [max]
# Result in INPUT_RESULT
cli_api_number() {
    cli_input_number "$1" "${2:-0}" "${3:-}" "${4:-}"
}

# Show confirmation
# Usage: cli_api_confirm "message" [default_yes]
# Returns: 0 for yes, 1 for no
cli_api_confirm() {
    cli_confirm "$1" "${2:-false}"
}

# Show danger confirmation
# Usage: cli_api_danger_confirm "message" [confirm_text]
cli_api_danger_confirm() {
    cli_danger_confirm "$1" "${2:-DELETE}"
}

# ═══════════════════════════════════════════════════════════════
#                    DISPLAY FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Show banner
# Usage: cli_api_banner "title" [subtitle] [style]
cli_api_banner() {
    title="$1"
    subtitle="${2:-}"
    style="${3:-double}"
    
    # Calculate width
    title_len=${#title}
    sub_len=${#subtitle}
    if [ "$sub_len" -gt "$title_len" ]; then
        width=$((sub_len + 6))
    else
        width=$((title_len + 6))
    fi
    if [ "$width" -lt 40 ]; then
        width=40
    fi
    
    inner_width=$((width - 2))
    
    # Set box characters based on style
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
    
    printf '\n  %s%s' "$FG_CYAN" "$tl"
    cli_hline "$inner_width" "$h"
    printf '%s%s\n' "$tr" "$RESET"
    
    # Title line
    padding=$(((inner_width - title_len) / 2))
    printf '  %s%s%s' "$FG_CYAN" "$v" "$RESET"
    cli_repeat ' ' "$padding"
    printf '%s%s%s%s' "$STYLE_BOLD" "$FG_BRIGHT_WHITE" "$title" "$RESET"
    right_pad=$((inner_width - padding - title_len))
    cli_repeat ' ' "$right_pad"
    printf '%s%s%s\n' "$FG_CYAN" "$v" "$RESET"
    
    # Subtitle line (if provided)
    if [ -n "$subtitle" ]; then
        padding=$(((inner_width - sub_len) / 2))
        printf '  %s%s%s' "$FG_CYAN" "$v" "$RESET"
        cli_repeat ' ' "$padding"
        printf '%s%s%s' "$FG_GRAY" "$subtitle" "$RESET"
        right_pad=$((inner_width - padding - sub_len))
        cli_repeat ' ' "$right_pad"
        printf '%s%s%s\n' "$FG_CYAN" "$v" "$RESET"
    fi
    
    printf '  %s%s' "$FG_CYAN" "$bl"
    cli_hline "$inner_width" "$h"
    printf '%s%s\n\n' "$br" "$RESET"
}

# Show a table
# Usage: cli_api_table "col1,col2,col3" "val1,val2,val3" "val4,val5,val6" ...
cli_api_table() {
    headers="$1"
    shift
    
    # Parse headers
    IFS=',' read -r h1 h2 h3 h4 h5 <<EOF
$headers
EOF
    
    # Calculate column widths
    w1=${#h1}; w2=${#h2}; w3=${#h3}; w4=${#h4}; w5=${#h5}
    
    for row in "$@"; do
        IFS=',' read -r c1 c2 c3 c4 c5 <<EOF
$row
EOF
        [ ${#c1} -gt "$w1" ] && w1=${#c1}
        [ ${#c2} -gt "$w2" ] && w2=${#c2}
        [ ${#c3} -gt "$w3" ] && w3=${#c3}
        [ ${#c4} -gt "$w4" ] && w4=${#c4}
        [ ${#c5} -gt "$w5" ] && w5=${#c5}
    done
    
    # Print headers
    printf '  %s%s%s' "$STYLE_BOLD" "$FG_CYAN" "$h1"
    cli_pad_right "" $((w1 - ${#h1} + 2))
    if [ -n "$h2" ]; then
        printf '%s' "$h2"
        cli_pad_right "" $((w2 - ${#h2} + 2))
    fi
    if [ -n "$h3" ]; then
        printf '%s' "$h3"
        cli_pad_right "" $((w3 - ${#h3} + 2))
    fi
    printf '%s\n' "$RESET"
    
    # Separator
    printf '  %s' "$FG_GRAY"
    cli_hline $((w1 + 2))
    [ -n "$h2" ] && cli_hline $((w2 + 2))
    [ -n "$h3" ] && cli_hline $((w3 + 2))
    printf '%s\n' "$RESET"
    
    # Print rows
    for row in "$@"; do
        IFS=',' read -r c1 c2 c3 c4 c5 <<EOF
$row
EOF
        printf '  %s' "$c1"
        cli_pad_right "" $((w1 - ${#c1} + 2))
        if [ -n "$c2" ]; then
            printf '%s' "$c2"
            cli_pad_right "" $((w2 - ${#c2} + 2))
        fi
        if [ -n "$c3" ]; then
            printf '%s' "$c3"
            cli_pad_right "" $((w3 - ${#c3} + 2))
        fi
        printf '\n'
    done
    printf '\n'
}

# ═══════════════════════════════════════════════════════════════
#                    WIZARD SYSTEM
# ═══════════════════════════════════════════════════════════════

# Wizard step results stored in WIZARD_* variables
WIZARD_STEP=0
WIZARD_CANCELLED=false

# Run a simple wizard
# Usage: cli_api_wizard "title" then call wizard step functions
# At the end, results are in WIZARD_* variables
cli_api_wizard_start() {
    title="${1:-Wizard}"
    WIZARD_TITLE="$title"
    WIZARD_STEP=0
    WIZARD_CANCELLED=false
}

# Add input step
# Usage: cli_api_wizard_input "name" "prompt" [default] [required]
cli_api_wizard_input() {
    name="$1"
    prompt="$2"
    default="${3:-}"
    required="${4:-false}"
    
    WIZARD_STEP=$((WIZARD_STEP + 1))
    
    printf '\n%sStep %s%s\n' "$FG_GRAY" "$WIZARD_STEP" "$RESET"
    
    cli_input_text "$prompt" "$default" "$required"
    
    if [ $? -ne 0 ]; then
        WIZARD_CANCELLED=true
        return 1
    fi
    
    eval "WIZARD_${name}=\"\$INPUT_RESULT\""
    return 0
}

# Add select step
# Usage: cli_api_wizard_select "name" "prompt" "opt1" "opt2" ...
cli_api_wizard_select() {
    name="$1"
    prompt="$2"
    shift 2
    
    WIZARD_STEP=$((WIZARD_STEP + 1))
    
    printf '\n%sStep %s%s\n' "$FG_GRAY" "$WIZARD_STEP" "$RESET"
    
    cli_quick_menu "$prompt" "$@"
    
    if [ $? -ne 0 ]; then
        WIZARD_CANCELLED=true
        return 1
    fi
    
    eval "WIZARD_${name}=\"\$MENU_RESULT\""
    return 0
}

# Add confirm step
# Usage: cli_api_wizard_confirm "name" "message" [default_yes]
cli_api_wizard_confirm() {
    name="$1"
    message="$2"
    default_yes="${3:-false}"
    
    WIZARD_STEP=$((WIZARD_STEP + 1))
    
    printf '\n%sStep %s%s\n' "$FG_GRAY" "$WIZARD_STEP" "$RESET"
    
    cli_confirm "$message" "$default_yes"
    result=$?
    
    if [ $result -eq 2 ]; then
        WIZARD_CANCELLED=true
        return 1
    fi
    
    if [ $result -eq 0 ]; then
        eval "WIZARD_${name}=true"
    else
        eval "WIZARD_${name}=false"
    fi
    return 0
}

# Check if wizard was cancelled
cli_api_wizard_cancelled() {
    [ "$WIZARD_CANCELLED" = "true" ]
}

# ═══════════════════════════════════════════════════════════════
#                    CONVENIENCE FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Print colored text
cli_print_color() {
    text="$1"
    color="${2:-white}"
    cli_print "$text" "$color"
}

# Print formatted message
cli_print_msg() {
    type="$1"
    message="$2"
    
    case "$type" in
        info)    cli_msg_info "$message" ;;
        success) cli_msg_success "$message" ;;
        warning) cli_msg_warning "$message" ;;
        error)   cli_msg_error "$message" ;;
        *)       printf '%s\n' "$message" ;;
    esac
}

# Clear screen and show cursor
cli_reset() {
    cli_clear_screen_reset
    cli_show_cursor
    cli_restore_term
}

# ═══════════════════════════════════════════════════════════════
#                    INITIALIZATION
# ═══════════════════════════════════════════════════════════════

# Set up cleanup on exit
trap 'cli_reset' EXIT INT TERM

# Test color support and set flag
CLI_HAS_COLOR=false
if cli_test_color_support; then
    CLI_HAS_COLOR=true
fi

CLI_HAS_TRUECOLOR=false
if cli_test_truecolor_support; then
    CLI_HAS_TRUECOLOR=true
fi
