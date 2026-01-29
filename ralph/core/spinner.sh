#!/usr/bin/env bash
# Animated spinner and progress indicator for Ralph Loop
#
# Provides visual feedback during long-running operations:
# - Animated spinner for "working" state
# - Progress dots for ongoing operations
# - Braille animation patterns
# - Status line updates without scrolling

# ═══════════════════════════════════════════════════════════════
#                    SPINNER CONFIGURATION
# ═══════════════════════════════════════════════════════════════

SPINNER_PID=""
SPINNER_ACTIVE=false
SPINNER_MESSAGE=""
SPINNER_START_TIME=0

# Spinner animation frames (multiple styles available)
declare -A SPINNER_STYLES
SPINNER_STYLES[dots]="⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏"
SPINNER_STYLES[line]="| / - \\"
SPINNER_STYLES[circle]="◐ ◓ ◑ ◒"
SPINNER_STYLES[arrows]="← ↖ ↑ ↗ → ↘ ↓ ↙"
SPINNER_STYLES[bounce]="⠁ ⠂ ⠄ ⠂"
SPINNER_STYLES[grow]="▁ ▂ ▃ ▄ ▅ ▆ ▇ █ ▇ ▆ ▅ ▄ ▃ ▂"
SPINNER_STYLES[pulse]="█ ▓ ▒ ░ ▒ ▓"

# Default style - convert to array
SPINNER_STYLE="dots"
read -ra SPINNER_FRAMES <<< "${SPINNER_STYLES[$SPINNER_STYLE]}"

# Colors
SPINNER_CYAN='\033[36m'
SPINNER_GREEN='\033[32m'
SPINNER_RED='\033[31m'
SPINNER_YELLOW='\033[33m'
SPINNER_GRAY='\033[90m'
SPINNER_RESET='\033[0m'

# ═══════════════════════════════════════════════════════════════
#                    SPINNER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

set_spinner_style() {
    # Sets the spinner animation style
    # Usage: set_spinner_style dots|line|circle|arrows|bounce|grow|pulse
    local style="${1:-dots}"
    SPINNER_STYLE="$style"
    read -ra SPINNER_FRAMES <<< "${SPINNER_STYLES[$style]}"
}

_spinner_loop() {
    # Internal: background spinner loop
    local message="$1"
    local frame_idx=0
    local start_time=$(date +%s)
    
    # Hide cursor
    printf '\033[?25l'
    
    while true; do
        local frame="${SPINNER_FRAMES[$frame_idx]}"
        local now=$(date +%s)
        local elapsed=$((now - start_time))
        local mins=$((elapsed / 60))
        local secs=$((elapsed % 60))
        local time_str=$(printf "%02d:%02d" $mins $secs)
        
        # Write spinner on same line (carriage return)
        printf "\r  ${SPINNER_CYAN}%s${SPINNER_RESET} %s ${SPINNER_GRAY}[%s]${SPINNER_RESET}  " \
            "$frame" "$message" "$time_str"
        
        sleep 0.08
        frame_idx=$(( (frame_idx + 1) % ${#SPINNER_FRAMES[@]} ))
    done
}

start_spinner() {
    # Starts the animated spinner with an optional message
    # Usage: start_spinner "Working..."
    local message="${1:-Working...}"
    
    # Don't start if already running
    if [[ "$SPINNER_ACTIVE" == "true" ]]; then
        return
    fi
    
    SPINNER_MESSAGE="$message"
    SPINNER_ACTIVE=true
    SPINNER_START_TIME=$(date +%s)
    
    # Start spinner in background
    _spinner_loop "$message" &
    SPINNER_PID=$!
    
    # Ensure cleanup on script exit
    trap 'stop_spinner' EXIT
}

stop_spinner() {
    # Stops the spinner and optionally shows a completion message
    # Usage: stop_spinner ["Done" [true|false]]
    local final_message="${1:-}"
    local success="${2:-true}"
    
    if [[ "$SPINNER_ACTIVE" != "true" ]]; then
        return
    fi
    
    SPINNER_ACTIVE=false
    
    # Kill spinner process if running
    if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null || true
    fi
    SPINNER_PID=""
    
    # Clear the spinner line
    printf "\r%-80s\r" " "
    
    # Show cursor again
    printf '\033[?25h'
    
    if [[ -n "$final_message" ]]; then
        if [[ "$success" == "true" ]]; then
            printf "  ${SPINNER_GREEN}✓${SPINNER_RESET} %s\n" "$final_message"
        else
            printf "  ${SPINNER_RED}✗${SPINNER_RESET} %s\n" "$final_message"
        fi
    fi
}

write_spinner_frame() {
    # Writes a single spinner frame (for synchronous use)
    # Usage: write_spinner_frame
    [[ "$SPINNER_ACTIVE" != "true" ]] && return
    
    local frame_idx=${SPINNER_FRAME_IDX:-0}
    local frame="${SPINNER_FRAMES[$frame_idx]}"
    local now=$(date +%s)
    local elapsed=$((now - SPINNER_START_TIME))
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    local time_str=$(printf "%02d:%02d" $mins $secs)
    
    printf "\r  ${SPINNER_CYAN}%s${SPINNER_RESET} %s ${SPINNER_GRAY}[%s]${SPINNER_RESET}  " \
        "$frame" "$SPINNER_MESSAGE" "$time_str"
    
    SPINNER_FRAME_IDX=$(( (frame_idx + 1) % ${#SPINNER_FRAMES[@]} ))
}

# ═══════════════════════════════════════════════════════════════
#                    PROGRESS BAR FUNCTIONS
# ═══════════════════════════════════════════════════════════════

show_progress() {
    # Shows a progress bar with percentage
    # Usage: show_progress current total ["Message"]
    local current="$1"
    local total="$2"
    local message="${3:-}"
    
    local percent=0
    if [[ "$total" -gt 0 ]]; then
        percent=$(( (current * 100) / total ))
    fi
    
    local bar_width=30
    local filled=$(( (percent * bar_width) / 100 ))
    local empty=$((bar_width - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    printf "\r  ${SPINNER_CYAN}[%s]${SPINNER_RESET} %3d%% %s  " "$bar" "$percent" "$message"
}

complete_progress() {
    # Completes and clears the progress bar
    # Usage: complete_progress ["Done"]
    local message="${1:-Done}"
    
    printf "\r%-80s\r" " "
    printf "  ${SPINNER_GREEN}✓${SPINNER_RESET} %s\n" "$message"
}

# ═══════════════════════════════════════════════════════════════
#                    STATUS LINE FUNCTIONS
# ═══════════════════════════════════════════════════════════════

write_status_line() {
    # Writes a status line that can be updated in place
    # Usage: write_status_line "Message" [info|success|warning|working]
    local message="$1"
    local type="${2:-info}"
    
    local icon
    case "$type" in
        success) icon="${SPINNER_GREEN}✓${SPINNER_RESET}" ;;
        warning) icon="${SPINNER_YELLOW}!${SPINNER_RESET}" ;;
        working) icon="${SPINNER_CYAN}●${SPINNER_RESET}" ;;
        *)       icon="${SPINNER_GRAY}→${SPINNER_RESET}" ;;
    esac
    
    printf "\r%-80s\r  %b %s" " " "$icon" "$message"
    
    if [[ "$type" != "working" ]]; then
        echo ""  # New line for non-working status
    fi
}

clear_status_line() {
    # Clears the current status line
    printf "\r%-80s\r" " "
}

# ═══════════════════════════════════════════════════════════════
#                    ACTIVITY INDICATOR
# ═══════════════════════════════════════════════════════════════

ACTIVITY_DOTS=0
ACTIVITY_MAX=5

show_activity() {
    # Shows animated dots to indicate activity
    # Usage: show_activity "Working"
    local message="${1:-Working}"
    
    ACTIVITY_DOTS=$(( (ACTIVITY_DOTS + 1) % (ACTIVITY_MAX + 1) ))
    
    local dots=""
    local padding=""
    for ((i=0; i<ACTIVITY_DOTS; i++)); do dots+="."; done
    for ((i=ACTIVITY_DOTS; i<ACTIVITY_MAX; i++)); do padding+=" "; done
    
    printf "\r  ${SPINNER_CYAN}●${SPINNER_RESET} %s%s%s" "$message" "$dots" "$padding"
}

reset_activity() {
    # Resets the activity indicator
    ACTIVITY_DOTS=0
    clear_status_line
}

# ═══════════════════════════════════════════════════════════════
#                    LIVE OUTPUT WRAPPER
# ═══════════════════════════════════════════════════════════════

with_spinner() {
    # Executes a command while showing a spinner
    # Usage: with_spinner "Working..." "Done" "Failed" command args...
    local message="$1"
    local success_msg="$2"
    local fail_msg="$3"
    shift 3
    
    start_spinner "$message"
    
    if "$@"; then
        stop_spinner "$success_msg" true
        return 0
    else
        local exit_code=$?
        stop_spinner "$fail_msg" false
        return $exit_code
    fi
}

# Ensure spinner stops on script exit
cleanup_spinner() {
    if [[ "$SPINNER_ACTIVE" == "true" ]]; then
        stop_spinner
    fi
}
trap cleanup_spinner EXIT

# Export functions for subshells
export -f start_spinner stop_spinner write_spinner_frame 2>/dev/null || true
export -f show_progress complete_progress 2>/dev/null || true
export -f write_status_line clear_status_line 2>/dev/null || true
export -f show_activity reset_activity 2>/dev/null || true
export -f with_spinner set_spinner_style 2>/dev/null || true
