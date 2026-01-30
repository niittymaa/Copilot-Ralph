#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Interrupt Handler Module for Ralph Loop - Bash Implementation
# ═══════════════════════════════════════════════════════════════
#
# Provides centralized interrupt handling with:
# - Three-option interrupt menu (Cancel/Finish Then Stop/Continue)
# - Global interrupt state management
# - Integration with build loop and Copilot execution
#
# Part of the Ralph CLI Framework
# ═══════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════
#                    INTERRUPT STATE
# ═══════════════════════════════════════════════════════════════

# Interrupt state: 'none', 'stop-after-iteration', 'cancel-requested'
INTERRUPT_STATE="none"

# Track if interrupt menu is currently showing (prevent re-entry)
INTERRUPT_MENU_ACTIVE=false

# ═══════════════════════════════════════════════════════════════
#                    COLORS (if not already defined)
# ═══════════════════════════════════════════════════════════════

: ${RED:='\033[0;31m'}
: ${GREEN:='\033[0;32m'}
: ${YELLOW:='\033[0;33m'}
: ${CYAN:='\033[0;36m'}
: ${GRAY:='\033[0;90m'}
: ${DARK_CYAN:='\033[0;36m'}
: ${WHITE:='\033[1;37m'}
: ${NC:='\033[0m'}

# ═══════════════════════════════════════════════════════════════
#                    STATE MANAGEMENT
# ═══════════════════════════════════════════════════════════════

# Get the current interrupt state
# Returns: 'none', 'stop-after-iteration', or 'cancel-requested'
get_interrupt_state() {
    echo "$INTERRUPT_STATE"
}

# Set the interrupt state
# Usage: set_interrupt_state "none"|"stop-after-iteration"|"cancel-requested"
set_interrupt_state() {
    local state="$1"
    case "$state" in
        none|stop-after-iteration|cancel-requested)
            INTERRUPT_STATE="$state"
            ;;
        *)
            echo "Invalid interrupt state: $state" >&2
            ;;
    esac
}

# Reset interrupt state to 'none'
reset_interrupt_state() {
    INTERRUPT_STATE="none"
}

# Check if loop should stop after current iteration
# Returns: 0 (true) if stop-after-iteration, 1 (false) otherwise
test_stop_after_iteration() {
    [[ "$INTERRUPT_STATE" == "stop-after-iteration" ]]
}

# Check if immediate cancel was requested
# Returns: 0 (true) if cancel-requested, 1 (false) otherwise
test_cancel_requested() {
    [[ "$INTERRUPT_STATE" == "cancel-requested" ]]
}

# Check if interrupt menu is currently active
# Returns: 0 (true) if active, 1 (false) otherwise
test_interrupt_menu_active() {
    [[ "$INTERRUPT_MENU_ACTIVE" == "true" ]]
}

# ═══════════════════════════════════════════════════════════════
#                    INTERRUPT MENU
# ═══════════════════════════════════════════════════════════════

# Show the interrupt options menu
# Usage: show_interrupt_menu [context]
# Returns: 'cancel', 'stop-after', or 'continue' via INTERRUPT_RESULT
show_interrupt_menu() {
    local context="${1:-Operation in progress}"
    INTERRUPT_RESULT=""
    
    # Prevent re-entry
    if [[ "$INTERRUPT_MENU_ACTIVE" == "true" ]]; then
        INTERRUPT_RESULT="continue"
        return
    fi
    
    INTERRUPT_MENU_ACTIVE=true
    
    # Show cursor
    printf '\033[?25h'
    
    # Clear any pending input
    read -t 0.1 -n 10000 discard 2>/dev/null || true
    
    echo ""
    echo -e "  ${YELLOW}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "  ${YELLOW}│             INTERRUPT DETECTED                  │${NC}"
    echo -e "  ${YELLOW}├─────────────────────────────────────────────────┤${NC}"
    printf "  ${YELLOW}│${NC}  ${GRAY}%-45s${NC}${YELLOW}│${NC}\n" "$context"
    echo -e "  ${YELLOW}└─────────────────────────────────────────────────┘${NC}"
    echo ""
    
    local selected=2  # Default to "Continue" (0-indexed: 2)
    
    # Menu options
    local -a labels=("Cancel Instantly" "Finish This Iteration, Then Stop" "Continue")
    local -a descs=("Kill process, exit loop now" "Complete current task, then stop" "Resume without interruption")
    local -a values=("cancel" "stop-after" "continue")
    
    # Function to render menu
    render_interrupt_menu() {
        # Move cursor up to redraw (6 lines for 3 options with descriptions)
        printf '\033[6A'
        
        for i in 0 1 2; do
            local prefix="   "
            local color="${GRAY}"
            local desc_color="\033[0;90m"
            
            if [[ $i -eq $selected ]]; then
                prefix="  ►"
                color="${CYAN}"
                desc_color="\033[0;36m"
            fi
            
            # Clear line and print option
            printf '\033[2K'
            echo -e "${prefix} ${color}[$((i+1))] ${labels[$i]}${NC}"
            printf '\033[2K'
            echo -e "       ${desc_color}${descs[$i]}${NC}"
        done
    }
    
    # Initial render (print placeholder lines first)
    echo ""  # Option 1
    echo ""  # Desc 1
    echo ""  # Option 2
    echo ""  # Desc 2
    echo ""  # Option 3
    echo ""  # Desc 3
    
    render_interrupt_menu
    
    echo ""
    echo -e "  ${GRAY}Use ↑/↓ arrows and Enter to select, or press 1/2/3${NC}"
    
    # Save terminal settings and set raw mode
    local old_stty
    old_stty=$(stty -g 2>/dev/null)
    stty -echo -icanon min 1 time 0 2>/dev/null
    
    # Read input loop
    while true; do
        local char
        char=$(dd bs=1 count=1 2>/dev/null)
        
        case "$char" in
            $'\x1b')
                # Escape sequence - read more
                stty -echo -icanon min 0 time 1 2>/dev/null
                local seq
                seq=$(dd bs=2 count=1 2>/dev/null)
                stty -echo -icanon min 1 time 0 2>/dev/null
                
                case "$seq" in
                    "[A")  # Up arrow
                        if [[ $selected -gt 0 ]]; then
                            ((selected--))
                            render_interrupt_menu
                        fi
                        ;;
                    "[B")  # Down arrow
                        if [[ $selected -lt 2 ]]; then
                            ((selected++))
                            render_interrupt_menu
                        fi
                        ;;
                    "")
                        # Just Escape - treat as continue
                        INTERRUPT_RESULT="continue"
                        break
                        ;;
                esac
                ;;
            $'\n'|$'\r')
                # Enter - select current option
                INTERRUPT_RESULT="${values[$selected]}"
                break
                ;;
            "1")
                INTERRUPT_RESULT="cancel"
                break
                ;;
            "2")
                INTERRUPT_RESULT="stop-after"
                break
                ;;
            "3")
                INTERRUPT_RESULT="continue"
                break
                ;;
        esac
    done
    
    # Restore terminal
    stty "$old_stty" 2>/dev/null
    
    # Show result message
    echo ""
    case "$INTERRUPT_RESULT" in
        cancel)
            echo -e "  ${YELLOW}→ Selected: Cancel Instantly${NC}"
            INTERRUPT_STATE="cancel-requested"
            ;;
        stop-after)
            echo -e "  ${CYAN}→ Selected: Finish This Iteration, Then Stop${NC}"
            INTERRUPT_STATE="stop-after-iteration"
            ;;
        continue)
            echo -e "  ${GREEN}→ Continuing...${NC}"
            ;;
    esac
    echo ""
    
    INTERRUPT_MENU_ACTIVE=false
}

# Show a banner indicating loop will stop after current iteration
show_stop_after_iteration_banner() {
    echo ""
    echo -e "  ${CYAN}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "  ${CYAN}│  ℹ️  Loop will stop after this iteration        │${NC}"
    echo -e "  ${DARK_CYAN}│     (Press ESC again to cancel immediately)     │${NC}"
    echo -e "  ${CYAN}└─────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
#                    EXPORT (for sourcing)
# ═══════════════════════════════════════════════════════════════

# Functions are automatically available when sourced
