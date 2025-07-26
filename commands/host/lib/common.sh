#ddev-generated
# shellcheck shell=bash

# Source guard
[[ -n "${COMMON_SH_LOADED:-}" ]] && return 0
COMMON_SH_LOADED=1

# Constants and exported variables
readonly APP_DIR="dewire"
APP_PATH="$DDEV_APPROOT/.ddev/$APP_DIR"
: "${LAZY_MODE:=false}"
export APP_PATH

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly MAGENTA='\033[1;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Status symbols
readonly SYM_OK="✓"
readonly SYM_ERROR="☓"
readonly SYM_NOT_SET="○"
readonly SYM_WARNING="!"

# Colored status symbols
readonly SYM_OK_COLOR="${GREEN}${SYM_OK}${NC}"
readonly SYM_ERROR_COLOR="${RED}${SYM_ERROR}${NC}"
# shellcheck disable=SC2034
readonly SYM_NOT_SET_COLOR="${YELLOW}${SYM_NOT_SET}${NC}"
readonly SYM_WARNING_COLOR="${YELLOW}${SYM_WARNING}${NC}"

# Logging helpers (2-space indent, grouped)
log_hr() {
    echo -e "${YELLOW}----------------------------------------${NC}"
}
log_warn() {
    echo -e "${SYM_WARNING_COLOR} $*"
}
log_error() {
    echo -e "${SYM_ERROR_COLOR} $*"
}
log_ok() {
    echo -e "${SYM_OK_COLOR} $*"
}
log_success() {
    log_ok "$@" # Alias to log_ok for DRY
}
log_info() {
    echo -e "${NC}$*"
}
log_header() {
    echo
    echo -e "${YELLOW}$*${NC}"
    log_hr
}
log_ask() {
    local prompt="$*"
    prompt="${prompt//\[/${YELLOW}[}"
    prompt="${prompt//\]/]${NC}}"
    echo -ne "$prompt"
}

log_fatal() {
    echo -e "\n${RED}$*${NC}\n"
}
log_option() {
    local number="$1"
    local label="$2"
    printf "    ${YELLOW}%d)${NC} %s\n" "$number" "$label"
}

log_step() {
    echo -e "${MAGENTA}"
    echo "========================================"
    echo " $* "
    echo "========================================"
    echo -e "${NC}"
}

debug() {
    if [[ "$DEBUG" == true ]]; then
        log_info "${CYAN}[DEBUG] $*${NC}"
    fi
}

log_verbose() {
    if [[ "${VERBOSE:-false}" == true ]]; then
        echo -e "${CYAN}[VERBOSE] $*${NC}"
    fi
}

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

to_lower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

# parse_script_args and parse_silent_flag left as is for compatibility

# Source the environment loader module
# For backward compatibility, provide access to the new simplified loader
if [[ -z "${ENV_LOADER_SIMPLE_LOADED:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/env-loader-simple.sh"
fi

# Backward compatibility alias
validate_and_load_env() {
    # Disable to see what breaks
    # load_environment "$@"
    debug "Nothing hill"
}

# Source environment selection helpers
source "$(dirname "${BASH_SOURCE[0]}")/env-selector.sh"
