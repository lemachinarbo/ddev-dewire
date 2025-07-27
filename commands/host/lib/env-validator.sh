#!/usr/bin/env bash
# shellcheck shell=bash
# Environment Validator Library
# Single responsibility: Validate .env files against schema

# Source guard
[[ -n "${ENV_VALIDATOR_LOADED:-}" ]] && return 0
readonly ENV_VALIDATOR_LOADED=1

# Source required dependencies
source "$(dirname "${BASH_SOURCE[0]}")/schema-parser.sh"

# Get environment variable value from file
get_env_var() {
  local prefix="$1"
  local var="$2"
  local env_file="$3"
  if [[ -f "$env_file" ]]; then
    grep "^${prefix}${var}=" "$env_file" 2>/dev/null | cut -d'=' -f2-
  fi
}

# Get environments list from .env file
get_env_environments() {
  local env_file="${1:-$ENV_FILE}"
  if [[ -f "$env_file" ]]; then
    grep '^ENVIRONMENTS=' "$env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"'
  fi
}

# Check if value contains placeholder text
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

# Check if .env file has missing required variables
check_missing_variables() {
  local env_file="${1:-$ENV_FILE}"
  local exclude_context="${2:-}" # Optional context to exclude (e.g., "gh")
  local missing_vars=()
  [[ ! -f "$env_file" ]] && {
    echo "all"
    return 1
  }

  # Filter REQUIRED_VARS by context if needed
  local filtered_required_vars=()
  for var in "${REQUIRED_VARS[@]}"; do
    [[ -z "$var" ]] && continue
    if [[ -n "$exclude_context" ]] && has_context "$var" "$exclude_context"; then
      continue # Skip variables with excluded context
    fi
    filtered_required_vars+=("$var")
  done

  for var in "${filtered_required_vars[@]}"; do
    if ! grep -q "^${var}=" "$env_file" 2>/dev/null; then
      missing_vars+=("$var")
    fi
  done

  # Check local required variables (these don't have gh context)
  for var in "${LOCAL_REQUIRED_VARS[@]}"; do
    [[ -z "$var" ]] && continue
    if ! grep -q "^${var}=" "$env_file" 2>/dev/null; then
      missing_vars+=("$var")
    fi
  done

  # Check environment-specific variables if environments exist
  local environments
  environments=$(get_env_environments "$env_file" 2>/dev/null || echo "")
  if [[ -n "$environments" ]]; then
    IFS=' ' read -ra env_array <<<"$environments"
    for env in "${env_array[@]}"; do
      env=$(echo "$env" | xargs | tr -d '"')
      # Skip "local" environment as it uses LOCAL_REQUIRED_VARS instead of ENV_REQUIRED_VARS
      [[ "$env" == "local" ]] && continue
      for var in "${ENV_REQUIRED_VARS[@]}"; do
        [[ -z "$var" ]] && continue
        local env_var="${env}_${var}"
        if ! grep -q "^${env_var}=" "$env_file" 2>/dev/null; then
          missing_vars+=("$env_var")
        fi
      done
    done
  fi
  printf '%s\n' "${missing_vars[@]}"
}

# Validate individual variable
validate_var() {
  local var="$1"
  local env_file="${2:-$ENV_FILE}"
  local value
  value=$(get_env_var "" "$var" "$env_file")
  if [[ -z "$value" ]]; then
    echo "missing"
  elif has_placeholder_value "$value"; then
    echo "placeholder"
  else
    echo "valid"
  fi
}

# Validate .env file against schema (non-strict mode for wizard compatibility)
validate_env_file() {
  local env_file="${1:-$ENV_FILE}"
  local strict_mode="${2:-true}"
  local silent_mode="${3:-false}"
  local exclude_context="${4:-}" # Optional context to exclude (e.g., "gh")
  [[ ! -f "$env_file" ]] && {
    [[ "$silent_mode" == "false" ]] && log_warn "No .env file found"
    return 1
  }
  local validation_errors=0
  local missing_vars=()
  local placeholder_vars=()

  # Filter REQUIRED_VARS by context if needed
  local filtered_required_vars=()
  for var in "${REQUIRED_VARS[@]}"; do
    if [[ -n "$exclude_context" ]] && has_context "$var" "$exclude_context"; then
      continue # Skip variables with excluded context
    fi
    filtered_required_vars+=("$var")
  done

  for var in "${filtered_required_vars[@]}"; do
    local status
    status=$(validate_var "$var" "$env_file")
    case "$status" in
    "missing") missing_vars+=("$var") ;;
    "placeholder") placeholder_vars+=("$var") ;;
    esac
  done

  # Check local required variables
  for var in "${LOCAL_REQUIRED_VARS[@]}"; do
    local status
    status=$(validate_var "$var" "$env_file")
    case "$status" in
    "missing") missing_vars+=("$var") ;;
    "placeholder") placeholder_vars+=("$var") ;;
    esac
  done

  # Check environment-specific variables if environments exist
  local environments
  environments=$(get_env_environments "$env_file")
  if [[ -n "$environments" ]]; then
    IFS=' ' read -ra env_array <<<"$environments"
    for env in "${env_array[@]}"; do
      env=$(echo "$env" | xargs | tr -d '"')
      # Skip "local" environment as it uses LOCAL_REQUIRED_VARS instead of ENV_REQUIRED_VARS
      [[ "$env" == "local" ]] && continue
      for var in "${ENV_REQUIRED_VARS[@]}"; do
        local env_var="${env}_${var}"
        local status
        status=$(validate_var "$env_var" "$env_file")
        case "$status" in
        "missing") missing_vars+=("$env_var") ;;
        "placeholder") placeholder_vars+=("$env_var") ;;
        esac
      done
    done
  fi
  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    if [[ "$strict_mode" == "true" ]]; then
      [[ "$silent_mode" == "false" ]] && log_error "Required variable ${missing_vars[0]} is missing from .env"
      return 1
    else
      [[ "$silent_mode" == "false" ]] && log_info "Found ${#missing_vars[@]} missing variables"
    fi
  fi
  if [[ ${#placeholder_vars[@]} -gt 0 ]]; then
    validation_errors=${#placeholder_vars[@]}
    if [[ "$strict_mode" == "true" ]]; then
      [[ "$silent_mode" == "false" ]] && log_error "Found $validation_errors placeholder value(s)"
      return 1
    else
      [[ "$silent_mode" == "false" ]] && log_warn "Found $validation_errors placeholder value(s)"
    fi
  fi
  if [[ ${#missing_vars[@]} -eq 0 && ${#placeholder_vars[@]} -eq 0 ]]; then
    [[ "$silent_mode" == "false" ]] && log_ok "All required variables are set and valid"
  fi
  return 0
}

# Quick check if .env file exists and is complete (for other scripts)
is_env_complete() {
  local env_file="${1:-$ENV_FILE}"
  local exclude_context="${2:-}" # Optional context to exclude (e.g., "gh")
  [[ ! -f "$env_file" ]] && return 1
  if [[ ! -s "$env_file" ]]; then
    return 1
  fi
  local var_count
  if ! var_count=$(grep -c '=' "$env_file" 2>/dev/null); then
    var_count=0
  fi
  if [[ "$var_count" -lt 3 ]]; then
    return 1
  fi
  local missing_vars
  mapfile -t missing_vars < <(check_missing_variables "$env_file" "$exclude_context")
  local filtered_vars=()
  for var in "${missing_vars[@]}"; do
    [[ -n "$var" ]] && filtered_vars+=("$var")
  done
  missing_vars=("${filtered_vars[@]}")
  debug "is_env_complete - Array contents: '${missing_vars[*]}'"
  for i in "${!missing_vars[@]}"; do
    debug "is_env_complete - Element $i: '${missing_vars[$i]}'"
  done
  [[ ${#missing_vars[@]} -eq 0 ]]
}
