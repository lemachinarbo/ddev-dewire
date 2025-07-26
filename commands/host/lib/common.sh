
# shellcheck shell=bash
#ddev-generated
# shellcheck shell=bash

APP_DIR="dewire"
APP_PATH="$DDEV_APPROOT/.ddev/$APP_DIR"
: "${LAZY_MODE:=false}"

export APP_PATH


# ================================

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
MAGENTA='\033[1;35m'
NC='\033[0m' # No Color

# Status symbols
SYM_OK="✓"
SYM_ERROR="☓"
SYM_NOT_SET="○"
SYM_WARNING="!"

# Colored status symbols
SYM_OK_COLOR="${GREEN}${SYM_OK}${NC}"
SYM_ERROR_COLOR="${RED}${SYM_ERROR}${NC}"
# shellcheck disable=SC2034
SYM_NOT_SET_COLOR="${YELLOW}${SYM_NOT_SET}${NC}"
SYM_WARNING_COLOR="${YELLOW}${SYM_WARNING}${NC}"

# Logging helpers
log_hr() { echo -e "${YELLOW}----------------------------------------${NC}"; }
log_warn() { echo -e "${SYM_WARNING_COLOR} $*"; }
log_error() { echo -e "${SYM_ERROR_COLOR} $*"; }
log_ok() { echo -e "${SYM_OK_COLOR} $*"; }
log_success() { echo -e "${GREEN}$*"; }
log_info() { echo -e "${NC}$*"; }
log_header() {
    echo
    echo -e "${YELLOW}$*${NC}"
    log_hr
}
log_ask() {
    # Usage: log_ask "Prompt text [default]: "
    local prompt="$*"
    local yellow
    yellow="$(printf '\033[1;33m')"
    local nc
    nc="$(printf '\033[0m')"
    # Colorize anything inside [ ] in yellow using ANSI codes directly
    prompt=$(echo "$prompt" | sed -E "s/\[([^]]+)\]/${yellow}[\1]${nc}/g")
    printf "%b" "$prompt"
}
log_fatal() { echo -e "\n${RED}$*${NC}\n"; }
log_option() {
    # Usage: log_option <number> <label>
    local number="$1"
    local label="$2"
    local yellow="\033[1;33m"
    local white="\033[1;37m"
    local nc="\033[0m"
    printf "    ${yellow}%d)${nc} ${white}%s${nc}\n" "$number" "$label"
}

log_step() {
  echo -e "${MAGENTA}"
  echo "========================================"
  echo " $* "
  echo "========================================"
  echo -e "${NC}"
}


# Usage: select_environment [env_arg] [environments_var]
select_environment() {
    local env_arg="$1"
    local allowed_envs="$2"
    local envs
    IFS=' ' read -r -a envs <<< "$allowed_envs"
    if [ -n "$env_arg" ]; then
        for env in "${envs[@]}"; do
            if [ "$env" = "$env_arg" ]; then
                SELECTED_ENV="$env"
                return 0
            fi
        done
        log_error "Invalid environment: $env_arg. Allowed: $allowed_envs"
        exit 1
    fi
    log_header "Which environment do you want to setup?"
    local i=1
    for env in "${envs[@]}"; do
        log_option "$i" "$env"
        i=$((i + 1))
    done
    local selection
    while true; do
        log_ask "Select environment number [1]: "
    read -r selection
        selection=${selection:-1}
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#envs[@]}" ]; then
            env="${envs[$((selection - 1))]}"
            SELECTED_ENV="$env"
            return 0
        else
            log_warn "Invalid selection. Please choose a valid number."
        fi
    done
}

# Usage: resolve_environment <env_arg> <allowed_envs>
resolve_environment() {
    local env_arg="$1"
    local allowed_envs="$2"
    if [[ "$env_arg" =~ ^--(.+) ]]; then
        SELECTED_ENV="${BASH_REMATCH[1]}"
        # log_info "Selected environment: $SELECTED_ENV"
    elif [ -n "$env_arg" ]; then
        SELECTED_ENV="$env_arg"
        # log_info "Selected environment: $SELECTED_ENV"
    else
        SELECTED_ENV=""
        select_environment "" "$allowed_envs"
        if [ -z "$SELECTED_ENV" ]; then
            log_error "No environment selected. Exiting."
            exit 1
        fi
        # log_info "Selected environment: $SELECTED_ENV"
    fi
}

ask_user() {
  local prompt="$1"
  local critical="${2:-false}"
  if [ "$LAZY_MODE" = true ] && [ "$critical" = false ]; then
    reply="y"
    log_ask "$prompt y (auto)"
    echo  # Add newline after auto response
  else
    log_ask "$prompt"
    read -r reply
    reply=${reply:-y}
  fi
  REPLY="$reply"
}

# Compatibility helper functions for cross-platform support

# OS detection
is_macos() { [[ "$OSTYPE" == "darwin"* ]]; }

# Compatible sed in-place editing
sed_inplace() {
    local pattern="$1" file="$2"
    if is_macos; then 
        sed -i '' "$pattern" "$file"
    else 
        sed -i "$pattern" "$file"
    fi
}

# Compatible lowercase conversion
to_lower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

# Comprehensive argument parser for scripts that need multiple flags
# Usage: parse_script_args "$@"
# Supports: --lazy, --silent, --debug, --local
# Sets global variables: LAZY_MODE, SILENT_FLAG, DEBUG_MODE, LOCAL_FLAG, PARSED_ARGS
# Example:
#   parse_script_args "$@"
#   validate_and_load_env "${PARSED_ARGS[0]:-}" "$SILENT_FLAG"
parse_script_args() {
    LAZY_MODE=false
    SILENT_FLAG=""
    DEBUG_MODE=false
    LOCAL_FLAG=""
    PARSED_ARGS=()
    
    for arg in "$@"; do
        case "$arg" in
            --lazy)
                LAZY_MODE=true
                ;;
            --silent)
                SILENT_FLAG="--silent"
                ;;
            --debug)
                DEBUG_MODE=true
                ;;
            --local)
                # shellcheck disable=SC2034
                LOCAL_FLAG="--local"
                ;;
            *)
                PARSED_ARGS+=("$arg")
                ;;
        esac
    done
    
    # Export debug mode for use in functions
    export DEBUG_MODE
}

# Lightweight parser for scripts that only need --silent flag
# Usage: parse_silent_flag "$@"
# Sets global variables: SILENT_FLAG, SILENT_ARGS
# Example:
#   parse_silent_flag "$@"
#   validate_and_load_env "${SILENT_ARGS[0]:-}" "$SILENT_FLAG"
parse_silent_flag() {
    SILENT_FLAG=""
    SILENT_ARGS=()
    
    for arg in "$@"; do
        if [[ "$arg" == "--silent" ]]; then
            # shellcheck disable=SC2034
            SILENT_FLAG="--silent"
        else
            SILENT_ARGS+=("$arg")
        fi
    done
}

# ================================
# LOAD ENVIRONMENT FUNCTIONS
# ================================

# Source the environment loader module
# For backward compatibility, provide access to the new simplified loader
# shellcheck source=./env-loader-simple.sh
source "$(dirname "${BASH_SOURCE[0]}")/env-loader-simple.sh"

# Backward compatibility alias
validate_and_load_env() {
  load_environment "$@"
}