#!/usr/bin/env bash
# Environment Loader - Schema-driven .env validation and loading
# This file contains all environment-related functions

ENV_FILE=".env"

# ================================
# CORE ENV FUNCTIONS
# ================================

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

check_env_file_exists() {
    if [ ! -f "$ENV_FILE" ]; then
        log_fatal ".env file not found at $ENV_FILE. Aborting."
        exit 1
    fi
}

# ================================
# SCHEMA-DRIVEN VALIDATION
# ================================

# Global arrays to store schema data
REQUIRED_VARS=()
OPTIONAL_VARS=()
LOCAL_REQUIRED_VARS=()
LOCAL_OPTIONAL_VARS=()
LOCAL_SECRET_VARS=()
ENV_REQUIRED_VARS=()
ENV_OPTIONAL_VARS=()
REPO_SECRET_VARS=()
ENV_SECRET_VARS=()
EXCLUDED_VARS=()
ENV_EXCLUDED_VARS=()

# Parse .env.schema and populate required/optional arrays
parse_env_schema() {
    local silent_mode="${1:-false}"
    local schema_file="$(dirname "$0")/lib/.env.schema"
    if [ ! -f "$schema_file" ]; then
        log_error "Schema file not found at $schema_file"
        exit 1
    fi
    
    # Clear arrays
    REQUIRED_VARS=()
    OPTIONAL_VARS=()
    LOCAL_REQUIRED_VARS=()
    LOCAL_OPTIONAL_VARS=()
    LOCAL_SECRET_VARS=()
    ENV_REQUIRED_VARS=()
    ENV_OPTIONAL_VARS=()
    REPO_SECRET_VARS=()
    ENV_SECRET_VARS=()
    EXCLUDED_VARS=()
    ENV_EXCLUDED_VARS=()
    
    # Helper function to add variable to appropriate array
    add_to_array() {
        local var="$1"
        local status="$2"
        local var_type="${3:-repo}"  # repo, local, local_secret, env, env_secret, excluded, env_excluded
        
        case "$var_type" in
            "excluded")
                EXCLUDED_VARS+=("$var")
                ;;
            "env_excluded")
                ENV_EXCLUDED_VARS+=("$var")
                ;;
            "repo_secret")
                REPO_SECRET_VARS+=("$var")
                ;;
            "local_secret")
                LOCAL_SECRET_VARS+=("$var")
                ;;
            "env_secret")
                ENV_SECRET_VARS+=("$var")
                ;;
            "local")
                if [ "$status" = "required" ]; then
                    LOCAL_REQUIRED_VARS+=("$var")
                elif [ "$status" = "optional" ]; then
                    LOCAL_OPTIONAL_VARS+=("$var")
                fi
                ;;
            "env")
                if [ "$status" = "required" ]; then
                    ENV_REQUIRED_VARS+=("$var")
                elif [ "$status" = "optional" ]; then
                    ENV_OPTIONAL_VARS+=("$var")
                fi
                ;;
            "repo")
                if [ "$status" = "required" ]; then
                    REQUIRED_VARS+=("$var")
                elif [ "$status" = "optional" ]; then
                    OPTIONAL_VARS+=("$var")
                fi
                ;;
        esac
    }
    
    while IFS=':' read -r var status; do
        # Skip comments and empty lines
        [[ "$var" =~ ^#.*$ ]] && continue
        [[ -z "$var" ]] && continue
        
        local clean_var="$var"
        local var_type="repo"  # Default: repository variable
        
        # Handle exclusion prefix !
        if [[ "$var" =~ ^!(.+)$ ]]; then
            var_type="excluded"
            clean_var="${BASH_REMATCH[1]}"
        # Handle local secret +@
        elif [[ "$var" =~ ^\+@(.+)$ ]]; then
            var_type="local_secret"
            clean_var="${BASH_REMATCH[1]}"
        # Handle local variable +
        elif [[ "$var" =~ ^\+(.+)$ ]]; then
            var_type="local"
            clean_var="${BASH_REMATCH[1]}"
        # Handle repository secret @
        elif [[ "$var" =~ ^@(.+)$ ]]; then
            var_type="repo_secret"
            clean_var="${BASH_REMATCH[1]}"
        # Handle environment variables *_
        elif [[ "$var" =~ ^\*_(.+)$ ]]; then
            clean_var="${BASH_REMATCH[1]}"
            
            # Check for environment exclusion *_!VAR
            if [[ "$clean_var" =~ ^!(.+)$ ]]; then
                var_type="env_excluded"
                clean_var="${BASH_REMATCH[1]}"
            # Check for environment secret *_@VAR
            elif [[ "$clean_var" =~ ^@(.+)$ ]]; then
                var_type="env_secret"
                clean_var="${BASH_REMATCH[1]}"
            else
                var_type="env"
            fi
        fi
        
        add_to_array "$clean_var" "$status" "$var_type"
    done < "$schema_file"
    
    if [ "$silent_mode" = "false" ]; then
        log_ok ".env schema parsed successfully"
    fi
}

# Check if variable contains placeholder values
has_placeholder_value() {
    local value="$1"
    local placeholders=(
        "your-github-username-or-org"
        "your-repo-name"
        "your-github-personal-access-token"
        "your-ssh-host"
        "your-ssh-user"
        "yourdomain.com"
        "/your/deploy/path"
        "example_user"
        "example_db"
        "password1234"
    )
    
    for placeholder in "${placeholders[@]}"; do
        if [[ "$value" == *"$placeholder"* ]]; then
            return 0
        fi
    done
    return 1
}

# Display configuration status tables
display_config_tables() {
    # Show base variables table
    log_info "Base variables"
    printf "%-25s %s\n" "Variable" "Status"
    printf "%-25s %s\n" "$(printf '%.0s─' {1..25})" "$(printf '%.0s─' {1..20})"
    
    # Helper function to print base variable status
    print_base_var_status() {
        local var="$1"
        local is_optional="${2:-false}"
        local value=$(get_env_var "" "$var" "$ENV_FILE")
        
        printf "%-25s" "$var"
        if [ -z "$value" ]; then
            if [ "$is_optional" = "true" ]; then
                echo -e "${SYM_NOT_SET_COLOR}"
            else
                echo -e "$SYM_ERROR_COLOR"
            fi
        elif has_placeholder_value "$value"; then
            echo -e "${SYM_WARNING_COLOR}"
        else
            echo -e "${SYM_OK_COLOR}"
        fi
    }
    
    # Required base variables
    log_info "Required:"
    for var in "${REQUIRED_VARS[@]}"; do
        print_base_var_status "$var" "false"
    done
    
    # Optional base variables
    echo
    log_info "Optional:"
    for var in "${OPTIONAL_VARS[@]}"; do
        print_base_var_status "$var" "true"
    done
    
    # Show environment variables matrix
    local environments=$(get_env_environments)
    if [ -n "$environments" ]; then
        echo
        log_info "Environment variables"

        # Create header
        printf "%-20s" "Variable"
        for env in $environments; do
            printf "%-12s" "$env"
        done
        echo
        
        # Create separator
        printf "%-20s" "$(printf '%.0s─' {1..20})"
        for env in $environments; do
            printf "%-15s" "$(printf '%.0s─' {1..15})"
        done
        echo
        
        # Helper function to print environment variable status
        print_env_status() {
            local env="$1"
            local var="$2"
            local is_optional="${3:-false}"
            local env_var="${env}_${var}"
            local value=$(get_env_var "" "$env_var" "$ENV_FILE")
            
            if [ -n "$value" ]; then
                if has_placeholder_value "$value"; then
                    printf "%-12s" "$SYM_WARNING"
                else
                    printf "%-12s" "$SYM_OK"
                fi
            else
                if [ "$is_optional" = "true" ]; then
                    printf "%-12s" "$SYM_NOT_SET"
                else
                    printf "%-12s" "$SYM_ERROR"
                fi
            fi
        }
        
        # Required variables
        log_info "Required:"
        for var in "${ENV_REQUIRED_VARS[@]}"; do
            printf "%-20s" "$var"
            for env in $environments; do
                print_env_status "$env" "$var" "false"
            done
            echo
        done
        
        # Optional variables
        if [ ${#ENV_OPTIONAL_VARS[@]} -gt 0 ]; then
            echo
            log_info "Optional:"
            for var in "${ENV_OPTIONAL_VARS[@]}"; do
                printf "%-20s" "$var"
                for env in $environments; do
                    print_env_status "$env" "$var" "true"
                done
                echo
            done
        fi
    fi
    
    echo
    log_info "Legend: $SYM_OK = configured, $SYM_ERROR = missing (required), $SYM_NOT_SET = not set (optional), $SYM_WARNING = placeholder value"
    echo
}

# Validate .env against schema
validate_env_against_schema() {
    local silent_mode="${1:-false}"
    local validation_errors=0
    local missing_vars=()
    
    # Helper function to validate a variable
    validate_var() {
        local var="$1"
        local value=$(get_env_var "" "$var" "$ENV_FILE")
        
        if [ -z "$value" ]; then
            log_error "Required variable $var is missing from $ENV_FILE"
            validation_errors=$((validation_errors + 1))
            missing_vars+=("$var")
        elif has_placeholder_value "$value"; then
            log_error "Variable $var still has placeholder value: $value"
            validation_errors=$((validation_errors + 1))
        fi
    }
    
    # Check required base variables
    for var in "${REQUIRED_VARS[@]}"; do
        validate_var "$var"
    done
    
    # Check environment-specific variables
    local environments=$(get_env_environments)
    if [ -n "$environments" ]; then
        for env in $environments; do
            for var in "${ENV_REQUIRED_VARS[@]}"; do
                validate_var "${env}_${var}"
            done
        done
    fi
    
    # If there are validation errors, exit
    if [ $validation_errors -gt 0 ]; then
        log_fatal "Found $validation_errors validation error(s). Please fix your .env file before continuing."
        exit 1
    else
        if [ "$silent_mode" = "false" ]; then
            log_success "All required .env variables are set and valid"
        fi
    fi
}

# Unified loader function - replaces all load_*_vars functions
validate_and_load_env() {
    local env_arg="${1:-}"
    local debug_flag="${2:-}"
    local debug_mode="false"
    local silent_mode="false"
    
    # Check for debug flag or environment variable
    if [ "$debug_flag" = "--debug" ] || [ "${DEBUG_ENV_LOADER:-false}" = "true" ]; then
        debug_mode="true"
    fi
    
    # Check for silent flag
    if [ "$debug_flag" = "--silent" ]; then
        silent_mode="true"
    fi
    
    if [ "$silent_mode" = "false" ]; then
        log_info "Checking .env file:"
    fi
    
    # Step 1: Check .env file exists
    check_env_file_exists
    if [ "$silent_mode" = "false" ]; then
        log_ok "Found .env file at $ENV_FILE"
    fi
    
    # Step 2: Parse schema and validate
    parse_env_schema "$silent_mode"
    
    if [ "$debug_mode" = "true" ]; then
        echo
        # Show tables
        display_config_tables
    fi
    
    validate_env_against_schema "$silent_mode"
    
    # Step 3: Load environment resolution (skip if requested)
    if [ "$env_arg" = "SKIP_ENV_SELECTION" ]; then
        if [ "$silent_mode" = "false" ]; then
            log_ok "Environment selection skipped (local development mode)"
        fi
        # Just load base variables without environment-specific ones
        for var in "${REQUIRED_VARS[@]}" "${OPTIONAL_VARS[@]}"; do
            local value=$(get_env_var "" "$var" "$ENV_FILE")
            declare -g "$var"="$value"
        done
        return
    fi
    
    ENVIRONMENTS=$(get_env_environments)
    if [ -z "$ENVIRONMENTS" ]; then
        log_error "No ENVIRONMENTS variable found in $ENV_FILE"
        exit 1
    fi
    resolve_environment "$env_arg" "$ENVIRONMENTS"
    ENV="$SELECTED_ENV"
    PREFIX="${ENV}_"
    
    # Load all variables from schema
    for var in "${REQUIRED_VARS[@]}" "${OPTIONAL_VARS[@]}"; do
        local value=$(get_env_var "" "$var" "$ENV_FILE")
        declare -g "$var"="$value"
    done
    
    # Load environment-specific variables for ALL environments
    local environments=$(get_env_environments)
    for env in $environments; do
        for var in "${ENV_REQUIRED_VARS[@]}" "${ENV_OPTIONAL_VARS[@]}"; do
            local env_var="${env}_${var}"
            local value=$(get_env_var "" "$env_var" "$ENV_FILE")
            declare -g "$env_var"="$value"
        done
    done
    
    # Set up convenience variables for backward compatibility
    SSH_KEY_NAME="${SSH_KEY:-id_github}"
    SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
    local ssh_user_var="${PREFIX}SSH_USER"
    local ssh_host_var="${PREFIX}SSH_HOST"
    local path_var="${PREFIX}PATH"
    REMOTE_USER="${!ssh_user_var:-}"
    REMOTE_HOST="${!ssh_host_var:-}"
    REMOTE_PATH="${!path_var:-}"
    SERVER="$REMOTE_USER@$REMOTE_HOST"
    REMOTE_USER_HOST="$REMOTE_USER@$REMOTE_HOST"
    REPO_FULL="$REPO_OWNER/$REPO_NAME"
}