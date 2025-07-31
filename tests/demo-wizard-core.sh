#!/bin/bash

# Demo script for GitHub Wizard Core Module
# Shows the core navigation system in action

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# Source the core module
source "$LIB_DIR/wizard-core.sh"

# Demo function
demo_core_navigation() {
    echo "========================================"
    echo "  GitHub Wizard Core Navigation Demo"
    echo "========================================"
    echo
    
    # Initialize the core
    init_wizard_core
    
    echo "1. Core module initialized successfully"
    echo "   Current menu: $(get_current_menu)"
    echo "   Wizard running: $(get_wizard_status)"
    echo
    
    # Demonstrate menu state management
    echo "2. Demonstrating menu state management:"
    echo "   Adding 'main' to history and navigating to 'status'"
    MENU_HISTORY+=("main")
    CURRENT_MENU="status"
    echo "   Current menu: $(get_current_menu)"
    echo "   Menu history: $(get_menu_history | tr '\n' ' ')"
    echo
    
    # Demonstrate input validation
    echo "3. Demonstrating input validation:"
    
    local test_inputs=("1" "3" "5" "0" "6" "abc" "")
    for input in "${test_inputs[@]}"; do
        if [[ -z "$input" ]]; then
            input_display="(empty)"
        else
            input_display="'$input'"
        fi
        
        if handle_user_input "$input" "1-5" "main" 2>/dev/null; then
            echo "   Input $input_display: ✅ Valid"
        else
            echo "   Input $input_display: ❌ Invalid"
        fi
    done
    echo
    
    # Demonstrate menu options
    echo "4. Available menu options:"
    echo "   Main Menu Options:"
    for key in $(printf '%s\n' "${!MAIN_MENU_OPTIONS[@]}" | sort -n); do
        echo "     $key. ${MAIN_MENU_OPTIONS[$key]}"
    done
    echo
    
    echo "   Status Menu Options:"
    for key in $(printf '%s\n' "${!STATUS_MENU_OPTIONS[@]}" | sort -n); do
        echo "     $key. ${STATUS_MENU_OPTIONS[$key]}"
    done
    echo
    
    # Demonstrate return to main
    echo "5. Demonstrating return to main:"
    local before_history=$(get_menu_history)
    local before_count=0
    if [[ -n "$before_history" ]]; then
        before_count=$(echo "$before_history" | wc -l)
    fi
    echo "   Before: Current menu = $(get_current_menu), History = $before_count items"
    MENU_HISTORY=()
    CURRENT_MENU="main"
    local after_history=$(get_menu_history)
    local after_count=0
    if [[ -n "$after_history" ]]; then
        after_count=$(echo "$after_history" | wc -l)
    fi
    echo "   After:  Current menu = $(get_current_menu), History = $after_count items"
    echo
    
    # Cleanup
    echo "6. Cleaning up:"
    cleanup_wizard_core
    echo "   Wizard running: $(get_wizard_status)"
    echo
    
    echo "✅ Demo completed successfully!"
}

# Run demo if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    demo_core_navigation
fi