#!/usr/bin/env bash
# shellcheck shell=bash
# Environment Loader Library
# Single responsibility: Load and expose environment variables

# Source guard
[[ -n "${ENV_LOADER_SIMPLE_LOADED:-}" ]] && return 0
ENV_LOADER_SIMPLE_LOADED=1

# Source required dependencies
source "$(dirname "${BASH_SOURCE[0]}")/schema-parser.sh" 
source "$(dirname "${BASH_SOURCE[0]}")/env-validator.sh"

# Environment configuration
# ENV_FILE is set by the main script if needed

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

# Helper to load variables from a list, with optional prefix
_load_vars_from_list() {
  local env_file="$1"
  local prefix="$2"
  shift 2
  local var_list=("$@")
  for var in "${var_list[@]}"; do
    [[ -z "$var" ]] && { debug "Skipping empty variable"; continue; }
    local full_var="$var"
    [[ -n "$prefix" ]] && full_var="${prefix}_$var"
    local value
    if value=$(get_env_var "" "$full_var" "$env_file" 2>/dev/null); then
      if [[ -n "$value" ]]; then
        export "$full_var"="$value"
        debug "Loaded: $full_var=$value"
      else
        debug "Empty value for $full_var"
      fi
    else
      debug "Failed: $full_var"
    fi
  done
}

# Load all environment variables into global scope
load_env_variables() {
  local env_file="${1:-$ENV_FILE}"
  [[ ! -f "$env_file" ]] && { debug "Env file not found: $env_file"; return 1; }
  _load_vars_from_list "$env_file" "" "${REQUIRED_VARS[@]}" "${OPTIONAL_VARS[@]}" "${LOCAL_REQUIRED_VARS[@]}" "${LOCAL_OPTIONAL_VARS[@]}"
  local environments
  environments=$(get_env_environments "$env_file" 2>/dev/null)
  if [[ -z "$environments" ]]; then
    debug "get_env_environments failed or empty, skipping env-specific variables"
  else
    IFS=' ' read -r -a env_array <<< "$environments"
    for env in "${env_array[@]}"; do
      debug "Loading variables for environment: $env"
      _load_vars_from_list "$env_file" "$env" "${ENV_REQUIRED_VARS[@]}" "${ENV_OPTIONAL_VARS[@]}"
    done
  fi
  debug "Finished loading all variables"
}

# Set up convenience variables for backward compatibility
setup_convenience_vars() {
  export SSH_KEY_NAME="${SSH_KEY:-id_github}"
  export SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
  if [[ -n "${SELECTED_ENV:-}" ]]; then
    local prefix="${SELECTED_ENV}_"
    export PREFIX="$prefix"
    local ssh_user_var="${prefix}SSH_USER"
    local ssh_host_var="${prefix}SSH_HOST"
    local path_var="${prefix}PATH"
    export REMOTE_USER="${!ssh_user_var:-}"
    export REMOTE_HOST="${!ssh_host_var:-}"
    export REMOTE_PATH="${!path_var:-}"
    export SERVER="$REMOTE_USER@$REMOTE_HOST"
    export REMOTE_USER_HOST="$REMOTE_USER@$REMOTE_HOST"
    local chmod_dir_var="${prefix}CHMOD_DIR"
    local chmod_file_var="${prefix}CHMOD_FILE"
    export CHMOD_DIR="${!chmod_dir_var:-755}"
    export CHMOD_FILE="${!chmod_file_var:-644}"
  fi
  if [[ -n "${REPO_OWNER:-}" && -n "${REPO_NAME:-}" ]]; then
    export REPO_FULL="$REPO_OWNER/$REPO_NAME"
  else
    export REPO_FULL=""
    log_warn "REPO_OWNER or REPO_NAME is not set; REPO_FULL will be empty."
  fi
}

# Main unified loader function (replacement for validate_and_load_env)
load_environment() {
  local env_arg="${1:-}"
  local options="${2:-}"
  debug "load_environment called with env_arg='$env_arg' options='$options'"
  # Option parsing loop (DRY)
  local verbose_mode="false" permissive_mode="false" local_mode="false" skip_validation="false" skip_schema_parse="false"
  for opt in $options; do
    case "$opt" in
      --verbose) verbose_mode="true" ;;
      --no-env) permissive_mode="true" ;;
      --local) local_mode="true" ;;
      --skip-validation) skip_validation="true" ;;
      --skip-schema-parse) skip_schema_parse="true" ;;
    esac
  done
  [[ "${ALLOW_MISSING_ENV:-false}" == "true" ]] && permissive_mode="true"
  if [[ "$skip_schema_parse" != "true" ]]; then
    parse_env_schema "$verbose_mode"
  fi
  if ! check_env_file_exists "$permissive_mode"; then
    [[ "$permissive_mode" == "true" ]] && return 0
    exit 1
  fi
  log_verbose "Found .env file at $ENV_FILE"
  if [[ "$skip_validation" == "false" ]]; then
    debug "Starting validation of $ENV_FILE with strict mode"
    if ! validate_env_file "$ENV_FILE" "true" "$verbose_mode"; then
      debug "Validation failed - exiting"
      log_fatal "Found validation error(s). Please fix your .env file before continuing."
      exit 1
    fi
    debug "Validation passed successfully"
  fi
  load_env_variables "$ENV_FILE"
  debug "Checking environment selection: local_mode=$local_mode, SETUP_MODE=${SETUP_MODE:-unset}"
  if [[ "$local_mode" == "false" ]] && [[ "${SETUP_MODE:-}" != "local" ]]; then
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
    export ENV="$SELECTED_ENV"
    export PREFIX="${ENV}_"
    debug "Environment variables set: ENV=$ENV PREFIX=$PREFIX"
  else
    debug "Skipping environment selection due to local mode"
  fi
  log_verbose "Setting up convenience variables."
  setup_convenience_vars
  log_ok "Environment loaded successfully"
}
