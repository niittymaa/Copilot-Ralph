#!/bin/sh
# ═══════════════════════════════════════════════════════════════
# Input Handler for CLI Framework - POSIX Shell Implementation
# ═══════════════════════════════════════════════════════════════
#
# Provides high-level input handling:
# - Text input with validation
# - Password/masked input
# - Confirmation dialogs
# - Number input with range validation
# - Choice selection
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
#                    TEXT INPUT
# ═══════════════════════════════════════════════════════════════

# Read text input
# Usage: cli_input_text "prompt" [default] [required]
# Result in INPUT_RESULT
cli_input_text() {
    prompt="${1:-Enter value}"
    default="${2:-}"
    required="${3:-false}"
    
    INPUT_RESULT=""
    
    printf '\n%s%s%s%s' "$MS_INDENT" "$FG_CYAN" "$prompt" "$RESET"
    
    if [ -n "$default" ]; then
        printf ' %s(default: %s)%s' "$FG_GRAY" "$default" "$RESET"
    fi
    
    printf ':\n%s' "$MS_INDENT"
    
    while true; do
        cli_read_line "" "$default"
        
        if [ $? -ne 0 ]; then
            INPUT_RESULT=""
            return 1
        fi
        
        result="$CLI_LINE_INPUT"
        
        # Use default if empty
        if [ -z "$result" ] && [ -n "$default" ]; then
            result="$default"
        fi
        
        # Validate required
        if [ "$required" = "true" ] && [ -z "$result" ]; then
            printf '%s%sThis field is required%s\n' "$MS_INDENT" "$FG_BRIGHT_RED" "$RESET"
            printf '%s' "$MS_INDENT"
            continue
        fi
        
        INPUT_RESULT="$result"
        return 0
    done
}

# Read password input
# Usage: cli_input_password "prompt" [required] [min_length]
# Result in INPUT_RESULT
cli_input_password() {
    prompt="${1:-Enter password}"
    required="${2:-false}"
    min_length="${3:-0}"
    
    INPUT_RESULT=""
    
    printf '\n%s%s%s%s:\n%s' "$MS_INDENT" "$FG_CYAN" "$prompt" "$RESET" "$MS_INDENT"
    
    while true; do
        cli_read_line "" "" "*"
        
        if [ $? -ne 0 ]; then
            INPUT_RESULT=""
            return 1
        fi
        
        result="$CLI_LINE_INPUT"
        
        # Validate required
        if [ "$required" = "true" ] && [ -z "$result" ]; then
            printf '%s%sPassword is required%s\n' "$MS_INDENT" "$FG_BRIGHT_RED" "$RESET"
            printf '%s' "$MS_INDENT"
            continue
        fi
        
        # Validate length
        if [ "$min_length" -gt 0 ] && [ ${#result} -lt "$min_length" ]; then
            printf '%s%sPassword must be at least %s characters%s\n' \
                "$MS_INDENT" "$FG_BRIGHT_RED" "$min_length" "$RESET"
            printf '%s' "$MS_INDENT"
            continue
        fi
        
        INPUT_RESULT="$result"
        return 0
    done
}

# ═══════════════════════════════════════════════════════════════
#                    NUMBER INPUT
# ═══════════════════════════════════════════════════════════════

# Read number input
# Usage: cli_input_number "prompt" [default] [min] [max]
# Result in INPUT_RESULT
cli_input_number() {
    prompt="${1:-Enter number}"
    default="${2:-0}"
    min="${3:-}"
    max="${4:-}"
    
    INPUT_RESULT=""
    
    # Build range hint
    range_hint=""
    if [ -n "$min" ] && [ -n "$max" ]; then
        range_hint=" (${min}-${max})"
    elif [ -n "$min" ]; then
        range_hint=" (min: ${min})"
    elif [ -n "$max" ]; then
        range_hint=" (max: ${max})"
    fi
    
    printf '\n%s%s%s%s%s%s%s\n' \
        "$MS_INDENT" "$FG_CYAN" "$prompt" "$RESET" \
        "$FG_GRAY" "$range_hint" "$RESET"
    
    if [ "$default" != "0" ]; then
        printf '%s%s(default: %s)%s\n' "$MS_INDENT" "$FG_GRAY" "$default" "$RESET"
    fi
    
    printf '%s' "$MS_INDENT"
    
    while true; do
        cli_read_line "" "$default"
        
        if [ $? -ne 0 ]; then
            INPUT_RESULT=""
            return 1
        fi
        
        result="$CLI_LINE_INPUT"
        
        # Use default if empty
        if [ -z "$result" ]; then
            result="$default"
        fi
        
        # Validate number
        case "$result" in
            ''|*[!0-9.-]*)
                printf '%s%sPlease enter a valid number%s\n' "$MS_INDENT" "$FG_BRIGHT_RED" "$RESET"
                printf '%s' "$MS_INDENT"
                continue
                ;;
        esac
        
        # Validate range
        if [ -n "$min" ]; then
            if [ "$result" -lt "$min" ] 2>/dev/null; then
                printf '%s%sValue must be at least %s%s\n' "$MS_INDENT" "$FG_BRIGHT_RED" "$min" "$RESET"
                printf '%s' "$MS_INDENT"
                continue
            fi
        fi
        
        if [ -n "$max" ]; then
            if [ "$result" -gt "$max" ] 2>/dev/null; then
                printf '%s%sValue must be at most %s%s\n' "$MS_INDENT" "$FG_BRIGHT_RED" "$max" "$RESET"
                printf '%s' "$MS_INDENT"
                continue
            fi
        fi
        
        INPUT_RESULT="$result"
        return 0
    done
}

# ═══════════════════════════════════════════════════════════════
#                    CONFIRMATION
# ═══════════════════════════════════════════════════════════════

# Show yes/no confirmation
# Usage: cli_confirm "message" [default_yes]
# Returns: 0 for yes, 1 for no, 2 for cancel
cli_confirm() {
    message="${1:-Confirm?}"
    default_yes="${2:-false}"
    
    # Highlight default
    if [ "$default_yes" = "true" ]; then
        yes_hint="${STYLE_BOLD}Y${RESET}"
        no_hint="n"
    else
        yes_hint="y"
        no_hint="${STYLE_BOLD}N${RESET}"
    fi
    
    printf '\n%s%s%s%s [%s/%s] ' "$MS_INDENT" "$FG_YELLOW" "$message" "$RESET" "$yes_hint" "$no_hint"
    
    cli_read_confirm "$default_yes"
    result=$?
    
    case $result in
        0)
            printf '%s%sYes%s\n' "" "$FG_GREEN" "$RESET"
            return 0
            ;;
        1)
            printf '%s%sNo%s\n' "" "$FG_BRIGHT_RED" "$RESET"
            return 1
            ;;
        *)
            printf '%s(cancelled)%s\n' "$FG_GRAY" "$RESET"
            return 2
            ;;
    esac
}

# Danger confirmation requiring typed text
# Usage: cli_danger_confirm "message" [confirm_text]
# Returns: 0 for confirmed, 1 for cancelled
cli_danger_confirm() {
    message="${1:-This action cannot be undone}"
    confirm_text="${2:-DELETE}"
    
    printf '\n%s%s⚠ WARNING%s\n' "$MS_INDENT" "$FG_BRIGHT_RED" "$RESET"
    printf '%s%s\n\n' "$MS_INDENT" "$message"
    printf '%sType %s%s%s to confirm: ' "$MS_INDENT" "$STYLE_BOLD" "$confirm_text" "$RESET"
    
    cli_read_line
    
    if [ "$CLI_LINE_INPUT" = "$confirm_text" ]; then
        printf '%s%sConfirmed%s\n' "$MS_INDENT" "$FG_GREEN" "$RESET"
        return 0
    else
        printf '%s%sCancelled%s\n' "$MS_INDENT" "$FG_YELLOW" "$RESET"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
#                    CHOICE INPUT
# ═══════════════════════════════════════════════════════════════

# Single-character choice
# Usage: cli_choice "prompt" "A:Add" "E:Edit" "D:Delete"
# Result in CHOICE_RESULT
cli_choice() {
    prompt="$1"
    shift
    
    CHOICE_RESULT=""
    
    printf '\n%s%s%s%s\n' "$MS_INDENT" "$FG_CYAN" "$prompt" "$RESET"
    
    allowed_chars=""
    default_char=""
    
    # Display choices
    for choice in "$@"; do
        key="${choice%%:*}"
        desc="${choice#*:}"
        
        # Check for default (uppercase = default)
        case "$key" in
            [A-Z])
                default_char="$key"
                printf '%s  %s%s[%s]%s %s\n' "$MS_INDENT" "$STYLE_BOLD" "$FG_YELLOW" "$key" "$RESET" "$desc"
                ;;
            *)
                printf '%s  %s[%s]%s %s\n' "$MS_INDENT" "$FG_YELLOW" "$key" "$RESET" "$desc"
                ;;
        esac
        
        key_lower=$(echo "$key" | tr '[:upper:]' '[:lower:]')
        allowed_chars="${allowed_chars}${key_lower}"
    done
    
    printf '\n%sChoice: ' "$MS_INDENT"
    
    while true; do
        cli_read_key
        
        char_lower=$(echo "$CLI_KEY_NAME" | tr '[:upper:]' '[:lower:]')
        
        # Check Enter for default
        if [ "$CLI_KEY_NAME" = "enter" ] && [ -n "$default_char" ]; then
            printf '%s%s%s\n' "$FG_YELLOW" "$default_char" "$RESET"
            CHOICE_RESULT="$default_char"
            return 0
        fi
        
        # Check Escape
        if [ "$CLI_KEY_NAME" = "escape" ]; then
            printf '%s(cancelled)%s\n' "$FG_GRAY" "$RESET"
            return 1
        fi
        
        # Check if valid choice
        case "$allowed_chars" in
            *"$char_lower"*)
                char_upper=$(echo "$char_lower" | tr '[:lower:]' '[:upper:]')
                printf '%s%s%s\n' "$FG_YELLOW" "$char_upper" "$RESET"
                CHOICE_RESULT="$char_upper"
                return 0
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════
#                    PATH INPUT
# ═══════════════════════════════════════════════════════════════

# Read path input
# Usage: cli_input_path "prompt" [default] [must_exist] [type]
# type: file, directory, any
# Result in INPUT_RESULT
cli_input_path() {
    prompt="${1:-Enter path}"
    default="${2:-}"
    must_exist="${3:-false}"
    path_type="${4:-any}"
    
    INPUT_RESULT=""
    
    printf '\n%s%s%s%s\n' "$MS_INDENT" "$FG_CYAN" "$prompt" "$RESET"
    
    if [ -n "$default" ]; then
        printf '%s%s(default: %s)%s\n' "$MS_INDENT" "$FG_GRAY" "$default" "$RESET"
    fi
    
    printf '%s' "$MS_INDENT"
    
    while true; do
        cli_read_line "" "$default"
        
        if [ $? -ne 0 ]; then
            INPUT_RESULT=""
            return 1
        fi
        
        result="$CLI_LINE_INPUT"
        
        # Use default if empty
        if [ -z "$result" ] && [ -n "$default" ]; then
            result="$default"
        fi
        
        if [ -z "$result" ]; then
            INPUT_RESULT=""
            return 0
        fi
        
        # Validate existence
        if [ "$must_exist" = "true" ]; then
            if [ ! -e "$result" ]; then
                printf '%s%sPath does not exist%s\n' "$MS_INDENT" "$FG_BRIGHT_RED" "$RESET"
                printf '%s' "$MS_INDENT"
                continue
            fi
            
            # Validate type
            case "$path_type" in
                file)
                    if [ ! -f "$result" ]; then
                        printf '%s%sPath must be a file%s\n' "$MS_INDENT" "$FG_BRIGHT_RED" "$RESET"
                        printf '%s' "$MS_INDENT"
                        continue
                    fi
                    ;;
                directory)
                    if [ ! -d "$result" ]; then
                        printf '%s%sPath must be a directory%s\n' "$MS_INDENT" "$FG_BRIGHT_RED" "$RESET"
                        printf '%s' "$MS_INDENT"
                        continue
                    fi
                    ;;
            esac
        fi
        
        INPUT_RESULT="$result"
        return 0
    done
}

# ═══════════════════════════════════════════════════════════════
#                    MESSAGES
# ═══════════════════════════════════════════════════════════════

# Show info message
cli_msg_info() {
    printf '%s%sℹ%s %s\n' "$MS_INDENT" "$FG_CYAN" "$RESET" "$1"
}

# Show success message
cli_msg_success() {
    printf '%s%s✓%s %s\n' "$MS_INDENT" "$FG_GREEN" "$RESET" "$1"
}

# Show warning message
cli_msg_warning() {
    printf '%s%s⚠%s %s\n' "$MS_INDENT" "$FG_YELLOW" "$RESET" "$1"
}

# Show error message
cli_msg_error() {
    printf '%s%s✗%s %s\n' "$MS_INDENT" "$FG_BRIGHT_RED" "$RESET" "$1"
}

# ═══════════════════════════════════════════════════════════════
#                    PROGRESS
# ═══════════════════════════════════════════════════════════════

# Show progress bar
# Usage: cli_progress current total [label] [width]
cli_progress() {
    current="$1"
    total="$2"
    label="${3:-}"
    width="${4:-40}"
    
    if [ "$total" -gt 0 ]; then
        percent=$((current * 100 / total))
    else
        percent=0
    fi
    
    filled=$((percent * width / 100))
    empty=$((width - filled))
    
    bar="${FG_GREEN}"
    i=0
    while [ $i -lt "$filled" ]; do
        bar="${bar}█"
        i=$((i + 1))
    done
    bar="${bar}${FG_GRAY}"
    i=0
    while [ $i -lt "$empty" ]; do
        bar="${bar}░"
        i=$((i + 1))
    done
    bar="${bar}${RESET}"
    
    printf '\r%s2K' "$CSI"
    
    if [ -n "$label" ]; then
        printf '%s%s ' "$MS_INDENT" "$label"
    fi
    
    printf '[%s] %s%s%%%s (%s/%s)' "$bar" "$FG_YELLOW" "$percent" "$RESET" "$current" "$total"
}

# Complete progress
cli_progress_done() {
    message="${1:-Done}"
    printf '\r%s2K%s%s✓%s %s\n' "$CSI" "$MS_INDENT" "$FG_GREEN" "$RESET" "$message"
}

# ═══════════════════════════════════════════════════════════════
#                    SPINNER
# ═══════════════════════════════════════════════════════════════

SPINNER_FRAMES='⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏'
SPINNER_INDEX=0

# Show spinner frame
# Usage: cli_spinner "message"
cli_spinner() {
    message="${1:-Loading...}"
    
    # Get current frame
    SPINNER_INDEX=$((SPINNER_INDEX + 1))
    count=$(echo "$SPINNER_FRAMES" | wc -w)
    idx=$((SPINNER_INDEX % count + 1))
    frame=$(echo "$SPINNER_FRAMES" | cut -d' ' -f"$idx")
    
    printf '\r%s2K%s%s%s%s %s' "$CSI" "$MS_INDENT" "$FG_CYAN" "$frame" "$RESET" "$message"
}

# Complete spinner
cli_spinner_done() {
    message="${1:-Done}"
    success="${2:-true}"
    
    printf '\r%s2K' "$CSI"
    
    if [ "$success" = "true" ]; then
        printf '%s%s✓%s %s\n' "$MS_INDENT" "$FG_GREEN" "$RESET" "$message"
    else
        printf '%s%s✗%s %s\n' "$MS_INDENT" "$FG_BRIGHT_RED" "$RESET" "$message"
    fi
}
