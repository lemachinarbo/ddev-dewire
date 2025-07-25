#!/usr/bin/env bash
# Environment Loader Library
# Single responsibility: Load and expose environment variables

# Source guard
[[ -n "${ENV_LOADER_SIMPLE_LOADED:-}" ]] && return 0
ENV_LOADER_SIMPLE_LOADED=1

# Source required dependencies
source "$(dirname "${BASH_SOURCE[0]}")/schema-parser.sh" 
source "$(dirname "${BASH_SOURCE[0]}")/env-validator.sh"

# Environment configuration
ENV_FILE=".env"

# Get default value for environment variable
get_env_default() {
  local var="$1"
  local default="$2"
  local value
  value=$(get_env_var "" "$var" "$ENV_FILE")
  echo "${value:-$default}"
}

# Check if .env file exists (with optional permissive mode)
check_env_file_exists() {
  local permissive="${1:-false}"
  if [[ ! -f "$ENV_FILE" ]]; then
    if [[ "$permissive" == "true" ]]; then
      return 1
    else
      log_error ".env file not found"
      exit 1
    fi
  fi
}

# Load all environment variables into global scope
load_env_variables() {
  echo "DEBUG: Entering load_env_variables" >&2
  local env_file="${1:-$ENV_FILE}"
  echo "DEBUG: env_file=$env_file" >&2
  debug "Starting load_env_variables with file: $env_file"
  
  [[ ! -f "$env_file" ]] && { debug "Env file not found: $env_file"; return 1; }
  echo "DEBUG: File check passed" >&2
  debug "Env file exists"
  
  debug "Loading variables from schema arrays"
  # Load all variables from schema arrays
  for var in "${REQUIRED_VARS[@]}" "${OPTIONAL_VARS[@]}" "${LOCAL_REQUIRED_VARS[@]}" "${LOCAL_OPTIONAL_VARS[@]}"; do
    [[ -z "$var" ]] && continue  # Skip empty variable names
    local value
    if value=$(get_env_var "" "$var" "$env_file" 2>/dev/null); then
      if [[ -n "$value" ]]; then
        declare -g "$var"="$value"
        debug "Loaded: $var=$value"
      fi
    fi
  done
  debug "Finished loading base variables"
  
  debug "Loading environment-specific variables"
  # Load environment-specific variables for ALL environments
  local environments
  environments=$(get_env_environments "$env_file")
  if [[ -n "$environments" ]]; then
    IFS=' ' read -ra env_array <<< "$environments"
    for env in "${env_array[@]}"; do
      env=$(echo "$env" | xargs | tr -d '"')
      debug "Loading variables for environment: $env"
      for var in "${ENV_REQUIRED_VARS[@]}" "${ENV_OPTIONAL_VARS[@]}"; do
        [[ -z "$var" ]] && continue  # Skip empty variable names
        local env_var="${env}_${var}"
        local value
        if value=$(get_env_var "" "$env_var" "$env_file" 2>/dev/null); then
          if [[ -n "$value" ]]; then
            declare -g "$env_var"="$value"
            debug "Loaded: $env_var=$value"
          fi
        fi
      done
    done
  fi
  debug "Finished loading all variables"
}

# Set up convenience variables for backward compatibility
setup_convenience_vars() {
  # Set up convenience variables
  export SSH_KEY_NAME="${SSH_KEY:-id_github}"
  export SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
  
  # Environment-specific convenience vars (requires SELECTED_ENV to be set)
  if [[ -n "${SELECTED_ENV:-}" ]]; then
    local prefix="${SELECTED_ENV}_"
    local ssh_user_var="${prefix}SSH_USER"
    local ssh_host_var="${prefix}SSH_HOST"
    local path_var="${prefix}PATH"
    
    export REMOTE_USER="${!ssh_user_var:-}"
    export REMOTE_HOST="${!ssh_host_var:-}"
    export REMOTE_PATH="${!path_var:-}"
    export SERVER="$REMOTE_USER@$REMOTE_HOST"
    export REMOTE_USER_HOST="$REMOTE_USER@$REMOTE_HOST"
    
    # Set up chmod permissions with defaults
    local chmod_dir_var="${prefix}CHMOD_DIR"
    local chmod_file_var="${prefix}CHMOD_FILE"
    export CHMOD_DIR="${!chmod_dir_var:-755}"
    export CHMOD_FILE="${!chmod_file_var:-644}"
  fi
  
  # Repository convenience vars
  export REPO_FULL="$REPO_OWNER/$REPO_NAME"
}

# Main unified loader function (replacement for validate_and_load_env)
load_environment() {
  local env_arg="${1:-}"
  local options="${2:-}"
  
  # Parse options
  local silent_mode="false"
  local permissive_mode="false"
  local local_mode="false"
  local skip_validation="false"
  
  case "$options" in
    *"--silent"*) silent_mode="true" ;;
  esac
  case "$options" in
    *"--no-env"*) permissive_mode="true" ;;
  esac
  case "$options" in
    *"--local"*) local_mode="true" ;;
  esac
  case "$options" in
    *"--skip-validation"*) skip_validation="true" ;;
  esac
  
  # Check for environment variables  
  [[ "${ALLOW_MISSING_ENV:-false}" == "true" ]] && permissive_mode="true"
  
  [[ "$silent_mode" == "false" ]] && log_info "Loading environment..."
  
  # Step 1: Parse schema
  parse_env_schema "$silent_mode"
  
  # Step 2: Check .env file exists
  if ! check_env_file_exists "$permissive_mode"; then
    [[ "$permissive_mode" == "true" ]] && return 0
    exit 1
  fi
  [[ "$silent_mode" == "false" ]] && log_ok "Found .env file at $ENV_FILE"
  
  # Step 3: Validate (unless skipped for wizard compatibility)
  if [[ "$skip_validation" == "false" ]]; then
    debug "Starting validation of $ENV_FILE with strict mode"
    if ! validate_env_file "$ENV_FILE" "true" "$silent_mode"; then
      debug "Validation failed - exiting"
      log_fatal "Found validation error(s). Please fix your .env file before continuing."
      exit 1
    fi
    debug "Validation passed successfully"
  fi
  
  # Step 4: Load variables
  debug "Loading environment variables from $ENV_FILE"
  load_env_variables "$ENV_FILE"
  debug "Variables loaded successfully"
  
  # Step 5: Environment selection (skip if local mode)
  if [[ "$local_mode" == "false" ]]; then
    debug "Resolving environment selection"
    local environments
    environments=$(get_env_environments)
    debug "Found environments: $environments"
    if [[ -z "$environments" ]]; then
      debug "No environments found - exiting"
      log_error "No environments defined in .env file"
      exit 1
    fi
    debug "Calling resolve_environment with env_arg='$env_arg' environments='$environments'"
    resolve_environment "$env_arg" "$environments"
    debug "Environment resolved: SELECTED_ENV=$SELECTED_ENV"
    export ENV="$SELECTED_ENV"
    export PREFIX="${ENV}_"
    debug "Environment variables set: ENV=$ENV PREFIX=$PREFIX"
  fi
  
  # Step 6: Setup convenience variables
  setup_convenience_vars
  
  [[ "$silent_mode" == "false" ]] && log_ok "Environment loaded successfully"
}
