#!/usr/bin/env bash
# Schema Parser Library
# Single responsibility: Parse .env.schema and provide schema metadata

# Source guard
[[ -n "${SCHEMA_PARSER_LOADED:-}" ]] && return 0
SCHEMA_PARSER_LOADED=1

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

# Global associative arrays for schema metadata
declare -A SCHEMA_DEFAULTS=()
declare -A SCHEMA_CONTEXTS=()

# Parse .env.schema and populate arrays
parse_env_schema() {
  local silent_mode="${1:-false}"
  local schema_file
  schema_file="$(dirname "${BASH_SOURCE[0]}")/.env.schema"
  
  if [[ ! -f "$schema_file" ]]; then
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
    
    # Parse default value
    local default_value=""
    if [[ "$default_part" =~ ^default=(.*)$ ]]; then
      default_value="${BASH_REMATCH[1]}"
    elif [[ -n "$default_part" && "$default_part" != "" ]]; then
      default_value="$default_part"
    fi
    
    # Parse context
    local context_value=""
    if [[ "$context_part" =~ ^context=(.*)$ ]]; then
      context_value="${BASH_REMATCH[1]}"
    elif [[ -n "$context_part" && "$context_part" != "" ]]; then
      context_value="$context_part"
    fi
    
    # Determine variable type and clean name from prefixes
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
    
    # Store metadata
    [[ -n "$default_value" ]] && SCHEMA_DEFAULTS["$clean_var"]="$default_value"
    [[ -n "$context_value" ]] && SCHEMA_CONTEXTS["$clean_var"]="$context_value"
    
    # Add to appropriate arrays
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
  done < "$schema_file"
  
  [[ "$silent_mode" == "false" ]] && log_ok "✓ .env schema parsed successfully"
}

# Get default value for a variable
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

# Get context for a variable
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
  local var_context
  var_context=$(get_schema_context "$var")
  [[ "$var_context" == "$context" ]]
}

# Filter variables by context
filter_vars_by_context() {
  local context="$1"
  shift
  local vars=("$@")
  local filtered=()
  
  for var in "${vars[@]}"; do
    local var_context
    var_context=$(get_schema_context "$var")
    # Include variable if it has the specified context, no context, or runtime context
    if [[ "$var_context" == "$context" ]] || [[ -z "$var_context" ]] || [[ "$var_context" == "runtime" ]]; then
      filtered+=("$var")
    fi
  done
  
  printf '%s\n' "${filtered[@]}"
}
