#!/bin/bash

# GitHub Wizard Display Module
# Provides visual formatting, colors, and user interface elements

# Color definitions (only set if not already defined)
if [ -z "${RED:-}" ]; then readonly RED='\033[0;31m'; fi
if [ -z "${GREEN:-}" ]; then readonly GREEN='\033[0;32m'; fi
if [ -z "${YELLOW:-}" ]; then readonly YELLOW='\033[1;33m'; fi
if [ -z "${BLUE:-}" ]; then readonly BLUE='\033[0;34m'; fi
if [ -z "${PURPLE:-}" ]; then readonly PURPLE='\033[0;35m'; fi
if [ -z "${CYAN:-}" ]; then readonly CYAN='\033[0;36m'; fi
if [ -z "${WHITE:-}" ]; then readonly WHITE='\033[1;37m'; fi
if [ -z "${BOLD:-}" ]; then readonly BOLD='\033[1m'; fi
if [ -z "${NC:-}" ]; then readonly NC='\033[0m'; fi # No Color

# Visual indicators (only set if not already defined)
if [ -z "${SUCCESS_ICON:-}" ]; then readonly SUCCESS_ICON="✅"; fi
if [ -z "${ERROR_ICON:-}" ]; then readonly ERROR_ICON="❌"; fi
if [ -z "${WARNING_ICON:-}" ]; then readonly WARNING_ICON="⚠️"; fi
if [ -z "${INFO_ICON:-}" ]; then readonly INFO_ICON="ℹ️"; fi
if [ -z "${PROGRESS_ICON:-}" ]; then readonly PROGRESS_ICON="⏳"; fi
if [ -z "${ARROW_ICON:-}" ]; then readonly ARROW_ICON="➤"; fi

# Print formatted section header
print_header() {
    local title="$1"
    local width=${2:-60}
    
    echo
    echo -e "${BOLD}${BLUE}$(printf '=%.0s' $(seq 1 $width))${NC}"
    echo -e "${BOLD}${WHITE}  $title${NC}"
    echo -e "${BOLD}${BLUE}$(printf '=%.0s' $(seq 1 $width))${NC}"
    echo
}

# Print styled menu option
print_menu_option() {
    local number="$1"
    local text="$2"
    local selected="${3:-false}"
    
    if [[ "$selected" == "true" ]]; then
        echo -e "${BOLD}${GREEN}${ARROW_ICON} $number. $text${NC}"
    else
        echo -e "  ${CYAN}$number.${NC} $text"
    fi
}

# Print status line with icon and formatting
print_status_line() {
    local status="$1"
    local message="$2"
    local details="${3:-}"
    
    case "$status" in
        "success")
            echo -e "${GREEN}${SUCCESS_ICON} $message${NC}"
            ;;
        "error")
            echo -e "${RED}${ERROR_ICON} $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}${WARNING_ICON} $message${NC}"
            ;;
        "info")
            echo -e "${BLUE}${INFO_ICON} $message${NC}"
            ;;
        "progress")
            echo -e "${PURPLE}${PROGRESS_ICON} $message${NC}"
            ;;
        *)
            echo -e "$message"
            ;;
    esac
    
    if [[ -n "$details" ]]; then
        echo -e "   ${details}"
    fi
}

# Print error message with formatting
print_error() {
    local message="$1"
    local details="${2:-}"
    
    echo
    echo -e "${RED}${BOLD}${ERROR_ICON} ERROR:${NC} ${RED}$message${NC}"
    if [[ -n "$details" ]]; then
        echo -e "${RED}   $details${NC}"
    fi
    echo
}

# Print success message with formatting
print_success() {
    local message="$1"
    local details="${2:-}"
    
    echo
    echo -e "${GREEN}${BOLD}${SUCCESS_ICON} SUCCESS:${NC} ${GREEN}$message${NC}"
    if [[ -n "$details" ]]; then
        echo -e "${GREEN}   $details${NC}"
    fi
    echo
}

# Print warning message with formatting
print_warning() {
    local message="$1"
    local details="${2:-}"
    
    echo
    echo -e "${YELLOW}${BOLD}${WARNING_ICON} WARNING:${NC} ${YELLOW}$message${NC}"
    if [[ -n "$details" ]]; then
        echo -e "${YELLOW}   $details${NC}"
    fi
    echo
}

# Print info message with formatting
print_info() {
    local message="$1"
    local details="${2:-}"
    
    echo
    echo -e "${BLUE}${BOLD}${INFO_ICON} INFO:${NC} ${BLUE}$message${NC}"
    if [[ -n "$details" ]]; then
        echo -e "${BLUE}   $details${NC}"
    fi
    echo
}

# Show progress indicator
show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Processing}"
    local width=${4:-30}
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${PURPLE}${PROGRESS_ICON} $message [${NC}"
    printf "${GREEN}%*s${NC}" $filled | tr ' ' '█'
    printf "%*s" $empty
    printf "${PURPLE}] ${percentage}%%${NC}"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Clear screen with optional header
clear_screen() {
    local keep_header="${1:-false}"
    
    if command -v clear >/dev/null 2>&1; then
        clear
    else
        printf '\033[2J\033[H'
    fi
    
    if [[ "$keep_header" == "true" ]]; then
        print_header "GitHub Issue Manager Wizard"
    fi
}

# Print separator line
print_separator() {
    local width=${1:-60}
    local char="${2:--}"
    
    echo -e "${BLUE}$(printf "%${width}s" | tr ' ' "$char")${NC}"
}

# Print centered text
print_centered() {
    local text="$1"
    local width=${2:-60}
    local padding=$(( (width - ${#text}) / 2 ))
    
    printf "%*s%s%*s\n" $padding "" "$text" $padding ""
}

# Print loading animation
show_loading() {
    local message="${1:-Loading}"
    local duration="${2:-3}"
    
    local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    while [[ $i -lt $duration ]]; do
        for (( j=0; j<${#spinner}; j++ )); do
            printf "\r${PURPLE}${spinner:$j:1} $message...${NC}"
            sleep 0.1
        done
        ((i++))
    done
    
    printf "\r${GREEN}${SUCCESS_ICON} $message complete!${NC}\n"
}

# Print key-value pair with formatting
print_key_value() {
    local key="$1"
    local value="$2"
    local key_width=${3:-20}
    
    printf "${CYAN}%-${key_width}s${NC}: %s\n" "$key" "$value"
}

# Print table header
print_table_header() {
    local -a headers=("$@")
    local total_width=0
    
    for header in "${headers[@]}"; do
        printf "${BOLD}${BLUE}%-15s${NC}" "$header"
        total_width=$((total_width + 15))
    done
    echo
    
    printf "${BLUE}%*s${NC}\n" $total_width | tr ' ' '-'
}

# Print table row
print_table_row() {
    local -a values=("$@")
    
    for value in "${values[@]}"; do
        printf "%-15s" "$value"
    done
    echo
}

# Print prompt for user input
print_prompt() {
    local message="$1"
    local default="${2:-}"
    
    if [[ -n "$default" ]]; then
        echo -e "${YELLOW}${ARROW_ICON} $message ${BLUE}[default: $default]${NC}: "
    else
        echo -e "${YELLOW}${ARROW_ICON} $message${NC}: "
    fi
}

# Print confirmation prompt
print_confirmation() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        echo -e "${YELLOW}${WARNING_ICON} $message ${BLUE}[Y/n]${NC}: "
    else
        echo -e "${YELLOW}${WARNING_ICON} $message ${BLUE}[y/N]${NC}: "
    fi
}