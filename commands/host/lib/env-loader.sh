#!/usr/bin/env bash
# Environment Loader - Schema-driven .env validation and loading v2
# This file contains all environment-related functions

ENV_FILE=".env"

# ================================
# CORE ENV FUNCTIONS
# ================================

get_env_var() {
    local prefix="$1"
    local var="$2"
    local env_file="$3"
    if [ -f "$env_file" ]; then
        grep "^${prefix}${var}=" "$env_file" | cut -d'=' -f2-
    fi
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
    if [ -f "$env_file" ]; then
        grep '^ENVIRONMENTS=' "$env_file" | cut -d'=' -f2- | tr -d '"'
    fi
}

check_env_file_exists() {
    local permissive="${1:-false}"
    if [ ! -f "$ENV_FILE" ]; then
        if [ "$permissive" = "true" ]; then
            return 1
        else
            log_fatal ".env file not found at $ENV_FILE. Aborting."
            exit 1
        fi
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

# Global associative arrays for schema metadata (defaults, contexts)
declare -A SCHEMA_DEFAULTS=()
declare -A SCHEMA_CONTEXTS=()

# Parse .env.schema and populate required/optional arrays with enhanced format support
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
    
    # Clear associative arrays
    SCHEMA_DEFAULTS=()
    SCHEMA_CONTEXTS=()
    
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
    
    # Parse schema lines with enhanced format: VAR|required/optional|default=value|context=install/runtime/env
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        # Parse schema line: VAR|status|default|context
        IFS='|' read -r var status default_part context_part <<< "$line"
        
        # Skip if we don't have at least var and status
        [[ -z "$var" || -z "$status" ]] && continue
        
        local clean_var="$var"
        local var_type="repo"  # Default: repository variable
        
        # Parse default value (default=value or empty)
        local default_value=""
        if [[ "$default_part" =~ ^default=(.*)$ ]]; then
            default_value="${BASH_REMATCH[1]}"
        elif [[ -n "$default_part" && "$default_part" != "" ]]; then
            # Handle case where default is specified without prefix
            default_value="$default_part"
        fi
        
        # Parse context (context=install/runtime/env or empty)
        local context_value=""
        if [[ "$context_part" =~ ^context=(.*)$ ]]; then
            context_value="${BASH_REMATCH[1]}"
        elif [[ -n "$context_part" && "$context_part" != "" ]]; then
            # Handle case where context is specified without prefix
            context_value="$context_part"
        fi
        
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
        
        # Store metadata
        if [ -n "$default_value" ]; then
            SCHEMA_DEFAULTS["$clean_var"]="$default_value"
        fi
        if [ -n "$context_value" ]; then
            SCHEMA_CONTEXTS["$clean_var"]="$context_value"
        fi
        
        add_to_array "$clean_var" "$status" "$var_type"
    done < "$schema_file"
    
    if [ "$silent_mode" = "false" ]; then
        log_ok ".env schema parsed successfully"
    fi
}

# Helper functions for schema metadata
get_schema_default() {
    local var="$1"
    
    # Check direct match first
    if [[ -n "${SCHEMA_DEFAULTS[$var]:-}" ]]; then
        echo "${SCHEMA_DEFAULTS[$var]}"
        return
    fi
    
    # Check if this is an environment-specific variable (ENV_VAR format)
    if [[ "$var" =~ ^[A-Z]+_(.+)$ ]]; then
        local base_var="${BASH_REMATCH[1]}"
        if [[ -n "${SCHEMA_DEFAULTS[$base_var]:-}" ]]; then
            echo "${SCHEMA_DEFAULTS[$base_var]}"
            return
        fi
    fi
    
    echo ""
}

get_schema_context() {
    local var="$1"
    
    # Check if explicit context is specified in schema
    if [[ -n "${SCHEMA_CONTEXTS[$var]:-}" ]]; then
        echo "${SCHEMA_CONTEXTS[$var]}"
        return
    fi
    
    # Check if this is an environment-specific variable (ENV_VAR format)
    if [[ "$var" =~ ^[A-Z]+_(.+)$ ]]; then
        local base_var="${BASH_REMATCH[1]}"
        if [[ -n "${SCHEMA_CONTEXTS[$base_var]:-}" ]]; then
            echo "${SCHEMA_CONTEXTS[$base_var]}"
            return
        fi
        # If no explicit context, infer from environment prefix
        echo "env"
        return
    fi
    
    # Default to runtime for variables without explicit context
    echo "runtime"
}

# Check if variable has specific context
has_context() {
    local var="$1"
    local context="$2"
    local var_context=$(get_schema_context "$var")
    [[ "$var_context" == "$context" ]]
}

# Get inferred context based on variable prefix/type
get_inferred_context() {
    local var="$1"
    local var_type="$2"  # from parsing (repo, local, env, excluded, etc.)
    
    case "$var_type" in
        "excluded"|"env_excluded")
            echo "install"
            ;;
        "env"|"env_secret")
            echo "env"
            ;;
        *)
            echo "runtime"
            ;;
    esac
}

# Filter variables by context
filter_vars_by_context() {
    local context="$1"
    shift
    local vars=("$@")
    local filtered=()
    
    for var in "${vars[@]}"; do
        local var_context=$(get_schema_context "$var")
        # Include variable if:
        # 1. It has the specified context, OR
        # 2. It has no context (defaults to all contexts), OR  
        # 3. It has runtime context (which applies to most cases)
        if [ "$var_context" = "$context" ] || [ -z "$var_context" ] || [ "$var_context" = "runtime" ]; then
            filtered+=("$var")
        fi
    done
    
    printf '%s\n' "${filtered[@]}"
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
    
    # Skip validation if .env file doesn't exist
    if [ ! -f "$ENV_FILE" ]; then
        if [ "$silent_mode" = "false" ]; then
            log_warn "Skipping validation - .env file not found"
        fi
        return
    fi
    
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
    local permissive_mode="false"
    local local_mode="false"

    # Check for debug flag or environment variable
    if [ "$debug_flag" = "--debug" ] || [ "${DEBUG_ENV_LOADER:-false}" = "true" ]; then
        debug_mode="true"
    fi

    # Check for silent flag (use SILENT_FLAG if set, otherwise default to false)
    if [ "${SILENT_FLAG:-}" = "--silent" ]; then
        silent_mode="true"
    fi

    # Check for permissive mode (allow missing .env) via --no-env
    if [ "$debug_flag" = "--no-env" ] || [ "${ALLOW_MISSING_ENV:-false}" = "true" ]; then
        permissive_mode="true"
    fi

    # Check for local mode (skip environment selection)
    if [ "$debug_flag" = "--local" ]; then
        local_mode="true"
    fi

    if [ "$silent_mode" = "false" ]; then
        log_info "Checking .env file:"
    fi

    # Step 1: Parse schema first (needed for variable arrays)
    # In permissive mode with no .env file, parse schema silently
    local schema_silent_mode="$silent_mode"
    if [ "$permissive_mode" = "true" ] && [ ! -f "$ENV_FILE" ]; then
        schema_silent_mode="true"
    fi
    parse_env_schema "$schema_silent_mode"
    
    # Step 2: Check .env file exists
    if ! check_env_file_exists "$permissive_mode"; then
        if [ "$permissive_mode" = "true" ]; then
            if [ "$silent_mode" = "false" ]; then
                log_warn ".env file not found, using installer defaults."
            fi
            # Set defaults for required/optional vars
            for var in "${REQUIRED_VARS[@]}" "${OPTIONAL_VARS[@]}"; do
                declare -g "$var"=""
            done
            return
        else
            exit 1
        fi
    fi
    if [ "$silent_mode" = "false" ]; then
        log_ok "Found .env file at $ENV_FILE"
    fi
    
    if [ "$debug_mode" = "true" ]; then
        echo
        # Show tables
        display_config_tables
    fi
    
    # Only validate if .env file exists
    if [ -f "$ENV_FILE" ]; then
        validate_env_against_schema "$silent_mode"
    fi
    
    # Step 3: Environment selection skipped (local development mode)
    if [ "$local_mode" = "true" ]; then
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
        # Load regular environment variables
        for var in "${ENV_REQUIRED_VARS[@]}" "${ENV_OPTIONAL_VARS[@]}"; do
            local env_var="${env}_${var}"
            local value=$(get_env_var "" "$env_var" "$ENV_FILE")
            declare -g "$env_var"="$value"
        done
        
        # Load environment secret variables  
        for var in "${ENV_SECRET_VARS[@]}"; do
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
    
    # Set up chmod permissions with defaults
    local chmod_dir_var="${PREFIX}CHMOD_DIR"
    local chmod_file_var="${PREFIX}CHMOD_FILE"
    CHMOD_DIR="${!chmod_dir_var:-755}"
    CHMOD_FILE="${!chmod_file_var:-644}"
    
}