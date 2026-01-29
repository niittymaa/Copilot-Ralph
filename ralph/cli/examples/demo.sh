#!/bin/sh
# ═══════════════════════════════════════════════════════════════
# POSIX Shell CLI Framework - Demo & Examples
# ═══════════════════════════════════════════════════════════════
#
# Demonstrates all features of the CLI framework:
# - Single-select menus
# - Multi-select menus
# - Text input
# - Confirmations
# - Progress bars
# - Messages
#
# Run this script to see all features in action.
# Part of the Ralph CLI Framework
# ═══════════════════════════════════════════════════════════════

# Load the CLI framework
SCRIPT_DIR=$(dirname "$0")
CLI_PATH="$SCRIPT_DIR/../sh/api.sh"
. "$CLI_PATH"

# ═══════════════════════════════════════════════════════════════
#                    DEMO FUNCTIONS
# ═══════════════════════════════════════════════════════════════

demo_banner() {
    cli_api_banner "CLI Framework Demo" "POSIX Shell Edition" "double"
}

demo_single_select() {
    printf '\n%s--- Single-Select Menu Demo ---%s\n' "$FG_CYAN" "$RESET"
    
    # Simple menu
    cli_api_menu "Choose a color" "Red" "Green" "Blue" "Yellow"
    
    if [ -n "$MENU_RESULT" ]; then
        cli_msg_success "You selected: $MENU_RESULT"
    else
        cli_msg_warning "Selection cancelled"
    fi
    
    # Menu with hotkeys
    cli_menu_clear
    cli_menu_add "Create new project" "create" "item" "C"
    cli_menu_add "Open existing project" "open" "item" "O"
    cli_menu_add "Import from template" "import" "item" "I"
    cli_menu_separator
    cli_menu_add "Exit" "exit" "item" "Q"
    
    cli_show_menu "Select an action"
    
    if [ -n "$MENU_RESULT" ]; then
        cli_msg_info "Action: $MENU_RESULT"
    fi
}

demo_multi_select() {
    printf '\n%s--- Multi-Select Menu Demo ---%s\n' "$FG_CYAN" "$RESET"
    
    cli_ms_clear
    cli_ms_add "Authentication" "auth" "true"
    cli_ms_add "Database ORM" "orm" "true"
    cli_ms_add "REST API" "api"
    cli_ms_add "GraphQL" "graphql"
    cli_ms_add "WebSocket support" "websocket"
    cli_ms_add "File uploads" "uploads"
    cli_ms_add "Email service" "email"
    cli_ms_add "Caching (Redis)" "cache"
    
    cli_show_multiselect "Select features to install"
    
    if [ -n "$MS_RESULT" ]; then
        cli_msg_success "Selected features: $MS_RESULT"
    else
        cli_msg_warning "No features selected"
    fi
}

demo_inputs() {
    printf '\n%s--- Input Demo ---%s\n' "$FG_CYAN" "$RESET"
    
    # Text input
    cli_input_text "Enter your name" "" "true"
    if [ -n "$INPUT_RESULT" ]; then
        cli_msg_success "Hello, $INPUT_RESULT!"
    fi
    
    # Number input
    cli_input_number "Enter your age" "25" "1" "150"
    if [ -n "$INPUT_RESULT" ]; then
        cli_msg_info "Age recorded: $INPUT_RESULT"
    fi
    
    # Password input
    cli_input_password "Create a password" "true" "4"
    if [ -n "$INPUT_RESULT" ]; then
        len=${#INPUT_RESULT}
        cli_msg_success "Password set (length: $len)"
    fi
}

demo_confirmations() {
    printf '\n%s--- Confirmation Demo ---%s\n' "$FG_CYAN" "$RESET"
    
    # Simple confirmation
    cli_confirm "Do you want to continue?"
    result=$?
    
    if [ $result -eq 0 ]; then
        cli_msg_info "Continuing..."
    else
        cli_msg_warning "Stopped"
    fi
    
    # Danger confirmation
    cli_danger_confirm "This will delete all data. Are you sure?" "DELETE"
    result=$?
    
    if [ $result -eq 0 ]; then
        cli_msg_error "Deletion confirmed"
    else
        cli_msg_success "Deletion cancelled"
    fi
}

demo_progress() {
    printf '\n%s--- Progress Demo ---%s\n' "$FG_CYAN" "$RESET"
    
    # Progress bar
    i=0
    while [ $i -le 100 ]; do
        cli_progress "$i" 100 "Downloading"
        sleep 0.1
        i=$((i + 5))
    done
    cli_progress_done "Download complete!"
    
    # Spinner
    i=0
    while [ $i -lt 20 ]; do
        cli_spinner "Processing..."
        sleep 0.1
        i=$((i + 1))
    done
    cli_spinner_done "Processing complete!" "true"
}

demo_messages() {
    printf '\n%s--- Message Types Demo ---%s\n' "$FG_CYAN" "$RESET"
    
    cli_msg_info "This is an info message"
    cli_msg_success "This is a success message"
    cli_msg_warning "This is a warning message"
    cli_msg_error "This is an error message"
}

demo_table() {
    printf '\n%s--- Table Demo ---%s\n' "$FG_CYAN" "$RESET"
    
    cli_api_table "Name,Role,Status" \
        "Alice,Developer,Active" \
        "Bob,Designer,Active" \
        "Charlie,Manager,Away" \
        "Diana,DevOps,Active"
}

demo_choice() {
    printf '\n%s--- Choice Demo ---%s\n' "$FG_CYAN" "$RESET"
    
    cli_choice "What would you like to do?" "A:Add new item" "E:Edit existing" "D:Delete item" "q:Quit"
    
    if [ -n "$CHOICE_RESULT" ]; then
        cli_msg_info "You chose: $CHOICE_RESULT"
    fi
}

demo_colors() {
    printf '\n%s--- Color Demo ---%s\n' "$FG_CYAN" "$RESET"
    
    printf '\n  Basic Foreground Colors:\n  '
    printf '%sBlack%s ' "$FG_BLACK" "$RESET"
    printf '%sRed%s ' "$FG_RED" "$RESET"
    printf '%sGreen%s ' "$FG_GREEN" "$RESET"
    printf '%sYellow%s ' "$FG_YELLOW" "$RESET"
    printf '%sBlue%s ' "$FG_BLUE" "$RESET"
    printf '%sMagenta%s ' "$FG_MAGENTA" "$RESET"
    printf '%sCyan%s ' "$FG_CYAN" "$RESET"
    printf '%sWhite%s ' "$FG_WHITE" "$RESET"
    printf '\n'
    
    printf '\n  Bright Foreground Colors:\n  '
    printf '%sBrightBlack%s ' "$FG_BRIGHT_BLACK" "$RESET"
    printf '%sBrightRed%s ' "$FG_BRIGHT_RED" "$RESET"
    printf '%sBrightGreen%s ' "$FG_BRIGHT_GREEN" "$RESET"
    printf '%sBrightYellow%s ' "$FG_BRIGHT_YELLOW" "$RESET"
    printf '%sBrightBlue%s ' "$FG_BRIGHT_BLUE" "$RESET"
    printf '%sBrightMagenta%s ' "$FG_BRIGHT_MAGENTA" "$RESET"
    printf '%sBrightCyan%s ' "$FG_BRIGHT_CYAN" "$RESET"
    printf '%sBrightWhite%s ' "$FG_BRIGHT_WHITE" "$RESET"
    printf '\n'
    
    printf '\n  Text Styles:\n  '
    printf '%sBold%s ' "$STYLE_BOLD" "$RESET"
    printf '%sDim%s ' "$STYLE_DIM" "$RESET"
    printf '%sItalic%s ' "$STYLE_ITALIC" "$RESET"
    printf '%sUnderline%s ' "$STYLE_UNDERLINE" "$RESET"
    printf '%sStrikethrough%s ' "$STYLE_STRIKETHROUGH" "$RESET"
    printf '\n\n'
}

# ═══════════════════════════════════════════════════════════════
#                    MAIN DEMO
# ═══════════════════════════════════════════════════════════════

run_demo() {
    cli_clear_screen_reset
    demo_banner
    
    while true; do
        cli_menu_clear
        cli_menu_add "Single-Select Menu" "single"
        cli_menu_add "Multi-Select Menu" "multi"
        cli_menu_add "Input Fields" "input"
        cli_menu_add "Confirmations" "confirm"
        cli_menu_add "Progress & Spinners" "progress"
        cli_menu_add "Messages" "messages"
        cli_menu_add "Tables" "table"
        cli_menu_add "Choice Input" "choice"
        cli_menu_add "Colors & Styles" "colors"
        cli_menu_separator
        cli_menu_add "Run All Demos" "all" "item" "A"
        cli_menu_add "Exit" "exit" "item" "Q"
        
        cli_show_menu "Select a demo"
        
        case "$MENU_RESULT" in
            single)   demo_single_select ;;
            multi)    demo_multi_select ;;
            input)    demo_inputs ;;
            confirm)  demo_confirmations ;;
            progress) demo_progress ;;
            messages) demo_messages ;;
            table)    demo_table ;;
            choice)   demo_choice ;;
            colors)   demo_colors ;;
            all)
                demo_single_select
                demo_multi_select
                demo_inputs
                demo_confirmations
                demo_progress
                demo_messages
                demo_table
                demo_colors
                ;;
            exit)
                cli_msg_info "Goodbye!"
                exit 0
                ;;
            *)
                exit 0
                ;;
        esac
        
        printf '\n%sPress Enter to continue...%s' "$FG_GRAY" "$RESET"
        read -r _
    done
}

# Run the demo
run_demo
