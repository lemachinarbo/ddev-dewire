#ddev-generated

APP_DIR="compwser"
APP_PATH="$DDEV_APPROOT/.ddev/$APP_DIR"
: "${LAZY_MODE:=false}"

export APP_PATH

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
MAGENTA='\033[1;35m'
NC='\033[0m' # No Color

# Logging helpers
log_hr() { echo -e "${YELLOW}----------------------------------------${NC}"; }
log_warn() { echo -e "${YELLOW}⚠ ${NC}$*"; }
log_error() { echo -e "${RED}✗ ${NC}$*"; }
log_ok() { echo -e "${GREEN}✓ ${NC}$*"; }
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
    local yellow="$(printf '\033[1;33m')"
    local nc="$(printf '\033[0m')"
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

get_env_var() {
    local prefix="$1"
    local var="$2"
    local env_file="$3"
    grep "^${prefix}${var}=" "$env_file" | cut -d'=' -f2-
}

# Usage: get_env_default <VAR> <DEFAULT>
get_env_default() {
    local var="$1"
    local default="$2"
    local value
    value=$(get_env_var "" "$var" "$ENV_FILE")
    echo "${value:-$default}"
}

get_env_environments() {
    local env_file="${1:-$ENV_FILE}"
    grep '^ENVIRONMENTS=' "$env_file" | cut -d'=' -f2- | tr -d '"'
}

ENV_FILE=".env"

check_env_file_exists() {
    if [ ! -f "$ENV_FILE" ]; then
        log_fatal ".env file not found at $ENV_FILE. Aborting."
        exit 1
    fi
    log_ok ".env file found at $ENV_FILE."
}

# Usage: select_environment [env_arg] [environments_var]
select_environment() {
    local env_arg="$1"
    local allowed_envs="$2"
    local envs=($allowed_envs)
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
        read selection
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
    read reply
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

# Standard environment variable loading functions

# Load basic environment resolution (used by all scripts)
load_standard_env_vars() {
    local env_arg="${1:-}"
    ENVIRONMENTS=$(get_env_environments)
    if [ -z "$ENVIRONMENTS" ]; then
        log_error "No ENVIRONMENTS variable found in $ENV_FILE"
        exit 1
    fi
    resolve_environment "$env_arg" "$ENVIRONMENTS"
    ENV="$SELECTED_ENV"
    PREFIX="${ENV}_"
}

# Load SSH connection variables
load_ssh_vars() {
    SSH_USER="$(get_env_var "$PREFIX" SSH_USER "$ENV_FILE")"
    SSH_HOST="$(get_env_var "$PREFIX" SSH_HOST "$ENV_FILE")"
    SSH_KEY_NAME="$(get_env_var "" SSH_KEY "$ENV_FILE")"
    if [ -z "$SSH_KEY_NAME" ]; then
        SSH_KEY_NAME="id_github"
    fi
    SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
    SERVER="$SSH_USER@$SSH_HOST"
    PW_ROOT="$(get_env_var "" PW_ROOT "$ENV_FILE")"
}

# Load remote deployment variables
load_remote_vars() {
    REMOTE_USER="$(get_env_var "$PREFIX" SSH_USER "$ENV_FILE")"
    REMOTE_HOST="$(get_env_var "$PREFIX" SSH_HOST "$ENV_FILE")"
    REMOTE_PATH="$(get_env_var "$PREFIX" PATH "$ENV_FILE")"
    REMOTE_USER_HOST="$REMOTE_USER@$REMOTE_HOST"
}

# Load GitHub repository variables
load_github_vars() {
    GITHUB_OWNER="$(get_env_var "" GITHUB_OWNER "$ENV_FILE")"
    GITHUB_REPO="$(get_env_var "" GITHUB_REPO "$ENV_FILE")"
    if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ]; then
        log_error "GITHUB_OWNER or GITHUB_REPO not set in .env."
        exit 1
    fi
    REPO_FULL="$GITHUB_OWNER/$GITHUB_REPO"
}

# Load database variables
load_db_vars() {
    DB_NAME="$(get_env_var "$PREFIX" DB_NAME "$ENV_FILE")"
    DB_USER="$(get_env_var "$PREFIX" DB_USER "$ENV_FILE")"
    DB_PASS="$(get_env_var "$PREFIX" DB_PASS "$ENV_FILE")"
    DB_HOST="$(get_env_var "$PREFIX" DB_HOST "$ENV_FILE")"
    DB_PORT="$(get_env_var "$PREFIX" DB_PORT "$ENV_FILE")"
}

