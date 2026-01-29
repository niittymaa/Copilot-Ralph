#!/bin/sh
# ═══════════════════════════════════════════════════════════════
# Key Reader for CLI Framework - POSIX Shell Implementation
# ═══════════════════════════════════════════════════════════════
#
# Provides keyboard input handling using:
# - stty for raw terminal input mode
# - Escape sequence parsing for arrow keys
# - Single keypress reading without Enter
#
# Part of the Ralph CLI Framework
# POSIX-compatible - no bash-specific features
# ═══════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════
#                    TERMINAL MODE MANAGEMENT
# ═══════════════════════════════════════════════════════════════

# Store original terminal settings
CLI_ORIGINAL_STTY=""

# Save current terminal settings
cli_save_term() {
    if [ -t 0 ]; then
        CLI_ORIGINAL_STTY=$(stty -g 2>/dev/null)
    fi
}

# Restore terminal settings
cli_restore_term() {
    if [ -n "$CLI_ORIGINAL_STTY" ] && [ -t 0 ]; then
        stty "$CLI_ORIGINAL_STTY" 2>/dev/null
    fi
}

# Set raw mode (no echo, no line buffering)
cli_raw_mode() {
    if [ -t 0 ]; then
        stty -echo -icanon min 1 time 0 2>/dev/null
    fi
}

# Set raw mode with timeout
# Usage: cli_raw_mode_timeout <deciseconds>
cli_raw_mode_timeout() {
    if [ -t 0 ]; then
        stty -echo -icanon min 0 time "${1:-1}" 2>/dev/null
    fi
}

# Trap handler to restore terminal on exit
cli_cleanup_term() {
    cli_restore_term
    cli_show_cursor
}

# ═══════════════════════════════════════════════════════════════
#                    KEY READING
# ═══════════════════════════════════════════════════════════════

# Read a single character
# Returns the character in CLI_KEY_CHAR
cli_read_char() {
    CLI_KEY_CHAR=""
    if [ -t 0 ]; then
        CLI_KEY_CHAR=$(dd bs=1 count=1 2>/dev/null)
    fi
}

# Read a single key, handling escape sequences
# Sets CLI_KEY_NAME to a friendly key name
# Returns: 0 on success, 1 on timeout/error
cli_read_key() {
    CLI_KEY_NAME=""
    CLI_KEY_CHAR=""
    
    # Save terminal and set raw mode
    cli_save_term
    cli_raw_mode
    
    # Read first character
    CLI_KEY_CHAR=$(dd bs=1 count=1 2>/dev/null)
    
    if [ -z "$CLI_KEY_CHAR" ]; then
        cli_restore_term
        return 1
    fi
    
    # Check for escape sequence
    case "$CLI_KEY_CHAR" in
        "$(printf '\033')")
            # Escape - could be start of sequence or standalone
            cli_raw_mode_timeout 1
            
            # Try to read more
            char2=$(dd bs=1 count=1 2>/dev/null)
            
            if [ -z "$char2" ]; then
                # Just Escape key
                CLI_KEY_NAME="escape"
            elif [ "$char2" = "[" ]; then
                # CSI sequence
                char3=$(dd bs=1 count=1 2>/dev/null)
                
                case "$char3" in
                    A) CLI_KEY_NAME="up" ;;
                    B) CLI_KEY_NAME="down" ;;
                    C) CLI_KEY_NAME="right" ;;
                    D) CLI_KEY_NAME="left" ;;
                    H) CLI_KEY_NAME="home" ;;
                    F) CLI_KEY_NAME="end" ;;
                    1|2|3|4|5|6)
                        # Extended sequence
                        char4=$(dd bs=1 count=1 2>/dev/null)
                        case "${char3}${char4}" in
                            "1~") CLI_KEY_NAME="home" ;;
                            "2~") CLI_KEY_NAME="insert" ;;
                            "3~") CLI_KEY_NAME="delete" ;;
                            "4~") CLI_KEY_NAME="end" ;;
                            "5~") CLI_KEY_NAME="pageup" ;;
                            "6~") CLI_KEY_NAME="pagedown" ;;
                            *)    CLI_KEY_NAME="unknown" ;;
                        esac
                        ;;
                    *) CLI_KEY_NAME="unknown" ;;
                esac
            elif [ "$char2" = "O" ]; then
                # SS3 sequence (function keys)
                char3=$(dd bs=1 count=1 2>/dev/null)
                case "$char3" in
                    P) CLI_KEY_NAME="f1" ;;
                    Q) CLI_KEY_NAME="f2" ;;
                    R) CLI_KEY_NAME="f3" ;;
                    S) CLI_KEY_NAME="f4" ;;
                    H) CLI_KEY_NAME="home" ;;
                    F) CLI_KEY_NAME="end" ;;
                    *) CLI_KEY_NAME="unknown" ;;
                esac
            else
                # Alt+key combination
                CLI_KEY_NAME="alt_${char2}"
            fi
            ;;
            
        "$(printf '\n')" | "$(printf '\r')")
            CLI_KEY_NAME="enter"
            ;;
            
        "$(printf '\t')")
            CLI_KEY_NAME="tab"
            ;;
            
        "$(printf '\177')" | "$(printf '\b')")
            CLI_KEY_NAME="backspace"
            ;;
            
        " ")
            CLI_KEY_NAME="space"
            ;;
            
        "$(printf '\003')")
            # Ctrl+C
            CLI_KEY_NAME="ctrl_c"
            ;;
            
        "$(printf '\004')")
            # Ctrl+D
            CLI_KEY_NAME="ctrl_d"
            ;;
            
        *)
            # Regular character
            CLI_KEY_NAME="$CLI_KEY_CHAR"
            ;;
    esac
    
    cli_restore_term
    return 0
}

# Read a navigation key, translating to action names
# Sets CLI_KEY_ACTION to: up, down, left, right, select, cancel, space, tab
# Or the lowercase character if it's in the allowed list
# Usage: cli_read_nav_key "qhy" (optional allowed chars)
cli_read_nav_key() {
    allowed_chars="${1:-}"
    CLI_KEY_ACTION=""
    
    if ! cli_read_key; then
        return 1
    fi
    
    case "$CLI_KEY_NAME" in
        up)       CLI_KEY_ACTION="up" ;;
        down)     CLI_KEY_ACTION="down" ;;
        left)     CLI_KEY_ACTION="left" ;;
        right)    CLI_KEY_ACTION="right" ;;
        enter)    CLI_KEY_ACTION="select" ;;
        escape)   CLI_KEY_ACTION="cancel" ;;
        ctrl_c)   CLI_KEY_ACTION="cancel" ;;
        space)    CLI_KEY_ACTION="space" ;;
        tab)      CLI_KEY_ACTION="tab" ;;
        home)     CLI_KEY_ACTION="home" ;;
        end)      CLI_KEY_ACTION="end" ;;
        pageup)   CLI_KEY_ACTION="pageup" ;;
        pagedown) CLI_KEY_ACTION="pagedown" ;;
        *)
            # Check if it's an allowed character
            if [ -n "$allowed_chars" ]; then
                lower_key=$(echo "$CLI_KEY_NAME" | tr '[:upper:]' '[:lower:]')
                case "$allowed_chars" in
                    *"$lower_key"*)
                        CLI_KEY_ACTION="$lower_key"
                        ;;
                esac
            fi
            ;;
    esac
    
    return 0
}

# Read yes/no confirmation
# Returns: 0 for yes, 1 for no, 2 for cancel
# Usage: cli_read_confirm [default_yes]
cli_read_confirm() {
    default_yes="${1:-false}"
    
    while true; do
        cli_read_key
        
        case "$CLI_KEY_NAME" in
            y|Y)
                return 0
                ;;
            n|N)
                return 1
                ;;
            enter)
                if [ "$default_yes" = "true" ]; then
                    return 0
                else
                    return 1
                fi
                ;;
            escape|ctrl_c)
                return 2
                ;;
        esac
    done
}

# Read line of text with editing
# Sets CLI_LINE_INPUT to the entered text
# Returns: 0 on success (Enter), 1 on cancel (Escape)
cli_read_line() {
    prompt="${1:-}"
    default="${2:-}"
    mask="${3:-}"
    
    CLI_LINE_INPUT="$default"
    
    if [ -n "$prompt" ]; then
        printf '%s' "$prompt"
    fi
    
    if [ -n "$default" ]; then
        if [ -n "$mask" ]; then
            printf '%s' "$(printf '%s' "$default" | sed "s/./${mask}/g")"
        else
            printf '%s' "$default"
        fi
    fi
    
    cli_save_term
    cli_raw_mode
    
    while true; do
        char=$(dd bs=1 count=1 2>/dev/null)
        
        case "$char" in
            "$(printf '\n')" | "$(printf '\r')")
                # Enter - done
                cli_restore_term
                printf '\n'
                return 0
                ;;
                
            "$(printf '\033')")
                # Escape
                cli_restore_term
                printf '\n'
                CLI_LINE_INPUT=""
                return 1
                ;;
                
            "$(printf '\177')" | "$(printf '\b')")
                # Backspace
                if [ -n "$CLI_LINE_INPUT" ]; then
                    CLI_LINE_INPUT="${CLI_LINE_INPUT%?}"
                    printf '\b \b'
                fi
                ;;
                
            "$(printf '\003')")
                # Ctrl+C
                cli_restore_term
                printf '\n'
                CLI_LINE_INPUT=""
                return 1
                ;;
                
            *)
                # Regular character
                CLI_LINE_INPUT="${CLI_LINE_INPUT}${char}"
                if [ -n "$mask" ]; then
                    printf '%s' "$mask"
                else
                    printf '%s' "$char"
                fi
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════
#                    INPUT BUFFER
# ═══════════════════════════════════════════════════════════════

# Clear any pending input
cli_clear_input() {
    if [ -t 0 ]; then
        stty -echo -icanon min 0 time 0 2>/dev/null
        while dd bs=1 count=1 2>/dev/null | head -c1 | grep -q .; do
            :
        done
        cli_restore_term
    fi
}

# Check if input is available (non-blocking)
# Returns: 0 if input available, 1 otherwise
cli_input_available() {
    if [ -t 0 ]; then
        cli_save_term
        stty -echo -icanon min 0 time 0 2>/dev/null
        char=$(dd bs=1 count=1 2>/dev/null)
        cli_restore_term
        
        if [ -n "$char" ]; then
            return 0
        fi
    fi
    return 1
}

# ═══════════════════════════════════════════════════════════════
#                    INITIALIZATION
# ═══════════════════════════════════════════════════════════════

# Set up cleanup trap
trap cli_cleanup_term EXIT INT TERM
