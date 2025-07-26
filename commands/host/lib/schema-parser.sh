#!/usr/bin/env bash
# shellcheck shell=bash
# Schema Parser Library
# Single responsibility: Parse .env.schema and provide schema metadata

# Source guard
[[ -n "${SCHEMA_PARSER_LOADED:-}" ]] && return 0
readonly SCHEMA_PARSER_LOADED=1

# Ensure logging functions are available
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Global arrays to store schema data
declare -a REQUIRED_VARS=()
declare -a OPTIONAL_VARS=()
declare -a LOCAL_REQUIRED_VARS=()
declare -a LOCAL_OPTIONAL_VARS=()
declare -a LOCAL_SECRET_VARS=()
declare -a ENV_REQUIRED_VARS=()
declare -a ENV_OPTIONAL_VARS=()
declare -a REPO_SECRET_VARS=()
declare -a ENV_SECRET_VARS=()
declare -a EXCLUDED_VARS=()
declare -a ENV_EXCLUDED_VARS=()

# Global associative arrays for schema metadata
declare -A SCHEMA_DEFAULTS=()
declare -A SCHEMA_CONTEXTS=()

parse_env_schema() {
  local silent_mode="${1:-false}"
  local schema_file
  schema_file="$(dirname "${BASH_SOURCE[0]}")/.env.schema"
  if [[ ! -f "$schema_file" ]]; then
    log_error "Schema file not found at $schema_file"
    exit 1
  fi
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
  SCHEMA_DEFAULTS=()
  SCHEMA_CONTEXTS=()
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    IFS='|' read -r var status default_part context_part <<<"$line"
    [[ -z "$var" || -z "$status" ]] && continue
    local clean_var="$var"
    local var_type="repo"
    local default_value=""
    if [[ "$default_part" =~ ^default=(.*)$ ]]; then
      default_value="${BASH_REMATCH[1]}"
    elif [[ -n "$default_part" && "$default_part" != "" ]]; then
      default_value="$default_part"
    fi
    local context_value=""
    if [[ "$context_part" =~ ^context=(.*)$ ]]; then
      context_value="${BASH_REMATCH[1]}"
    elif [[ -n "$context_part" && "$context_part" != "" ]]; then
      context_value="$context_part"
    fi
    if [[ "$var" =~ ^!(.+)$ ]]; then
      clean_var="${BASH_REMATCH[1]}"
      var_type="excluded"
    elif [[ "$var" =~ ^\+@(.+)$ ]]; then
      clean_var="${BASH_REMATCH[1]}"
      var_type="local_secret"
    elif [[ "$var" =~ ^\+(.+)$ ]]; then
      clean_var="${BASH_REMATCH[1]}"
      var_type="local"
    elif [[ "$var" =~ ^@(.+)$ ]]; then
      clean_var="${BASH_REMATCH[1]}"
      var_type="repo_secret"
    elif [[ "$var" =~ ^\*_@(.+)$ ]]; then
      clean_var="${BASH_REMATCH[1]}"
      var_type="env_secret"
    elif [[ "$var" =~ ^\*_!(.+)$ ]]; then
      clean_var="${BASH_REMATCH[1]}"
      var_type="env_excluded"
    elif [[ "$var" =~ ^\*_(.+)$ ]]; then
      clean_var="${BASH_REMATCH[1]}"
      var_type="env"
    fi
    [[ -n "$default_value" ]] && SCHEMA_DEFAULTS["$clean_var"]="$default_value"
    [[ -n "$context_value" ]] && SCHEMA_CONTEXTS["$clean_var"]="$context_value"
    case "$var_type" in
    "repo")
      if [[ "$status" == "required" ]]; then
        REQUIRED_VARS+=("$clean_var")
      else
        OPTIONAL_VARS+=("$clean_var")
      fi
      ;;
    "repo_secret")
      REPO_SECRET_VARS+=("$clean_var")
      if [[ "$status" == "required" ]]; then
        REQUIRED_VARS+=("$clean_var")
      else
        OPTIONAL_VARS+=("$clean_var")
      fi
      ;;
    "local")
      if [[ "$status" == "required" ]]; then
        LOCAL_REQUIRED_VARS+=("$clean_var")
      else
        LOCAL_OPTIONAL_VARS+=("$clean_var")
      fi
      ;;
    "local_secret")
      LOCAL_SECRET_VARS+=("$clean_var")
      if [[ "$status" == "required" ]]; then
        LOCAL_REQUIRED_VARS+=("$clean_var")
      else
        LOCAL_OPTIONAL_VARS+=("$clean_var")
      fi
      ;;
    "env")
      if [[ "$status" == "required" ]]; then
        ENV_REQUIRED_VARS+=("$clean_var")
      else
        ENV_OPTIONAL_VARS+=("$clean_var")
      fi
      ;;
    "env_secret")
      ENV_SECRET_VARS+=("$clean_var")
      if [[ "$status" == "required" ]]; then
        ENV_REQUIRED_VARS+=("$clean_var")
      else
        ENV_OPTIONAL_VARS+=("$clean_var")
      fi
      ;;
    "excluded")
      EXCLUDED_VARS+=("$clean_var")
      ;;
    "env_excluded")
      ENV_EXCLUDED_VARS+=("$clean_var")
      ;;
    esac
  done <"$schema_file"
  [[ "$silent_mode" == "false" ]] && log_verbose ".env schema parsed successfully"
}

get_schema_default() {
  local var="$1"
  if [[ -n "${SCHEMA_DEFAULTS[$var]:-}" ]]; then
    echo "${SCHEMA_DEFAULTS[$var]}"
    return
  fi
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
  if [[ -n "${SCHEMA_CONTEXTS[$var]:-}" ]]; then
    echo "${SCHEMA_CONTEXTS[$var]}"
    return
  fi
  if [[ "$var" =~ ^[A-Z]+_(.+)$ ]]; then
    local base_var="${BASH_REMATCH[1]}"
    if [[ -n "${SCHEMA_CONTEXTS[$base_var]:-}" ]]; then
      echo "${SCHEMA_CONTEXTS[$base_var]}"
      return
    fi
    echo "env"
    return
  fi
  echo "runtime"
}

has_context() {
  local var="$1"
  local context="$2"
  local var_context
  var_context=$(get_schema_context "$var")
  [[ "$var_context" == "$context" ]]
}

filter_vars_by_context() {
  local context="$1"
  shift
  local vars=("$@")
  local filtered=()
  for var in "${vars[@]}"; do
    local var_context
    var_context=$(get_schema_context "$var")
    if [[ "$var_context" == "$context" ]] || [[ -z "$var_context" ]] || [[ "$var_context" == "runtime" ]]; then
      filtered+=("$var")
    fi
  done
  printf '%s\n' "${filtered[@]}"
}
