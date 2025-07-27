#!/usr/bin/env bash
# Environment Wizard Library
# Single responsibility: Interactive prompting and .env file generation/fixing

# Source guard
[[ -n "${ENV_WIZARD_LOADED:-}" ]] && return 0
readonly ENV_WIZARD_LOADED=1

# Source required dependencies
source "$(dirname "${BASH_SOURCE[0]}")/schema-parser.sh"
source "$(dirname "${BASH_SOURCE[0]}")/env-validator.sh"

# Check if value has placeholder content
has_placeholder() {
  local value="$1"
  [[ "$value" == *"your-"* || "$value" == *"password1234"* || "$value" == *"yourdomain"* || "$value" == *"/your/"* || "$value" == "example_user" || "$value" == "example_db" ]]
}

# Validate user input based on variable type
is_valid_input() {
  local var="$1" value="$2"
  case "$var" in
  *EMAIL) [[ "$value" =~ ^[^@]+@[^@]+\.[^@]+$ ]] ;;
  *_HOST) [[ -n "$value" ]] ;;
  *PORT) [[ "$value" =~ ^[0-9]+$ ]] ;;
  *) [[ -n "$value" ]] ;;
  esac
}

# Prompt for a single missing variable with validation
prompt_missing_var() {
  local var="$1" env_file="$2"
  local default="" suggested="" user_input="" final_value=""
  default=$(get_schema_default "$var" 2>/dev/null || echo "")
  suggested="$default"
  if [[ -n "${WIZARD_MODE:-}" && -n "$suggested" ]]; then
    if has_placeholder "$suggested"; then
      suggested=""
    fi
  fi
  while true; do
    local prompt="Enter $var"
    [[ -n "$suggested" ]] && prompt="$prompt [$suggested]"
    prompt="$prompt: "
    log_ask "$prompt"
    read -r user_input
    final_value="${user_input:-$suggested}"
    if [[ -n "$final_value" ]] && is_valid_input "$var" "$final_value"; then
      if grep -q "^${var}=" "$env_file" 2>/dev/null; then
        sed -i "s|^${var}=.*|${var}=${final_value}|" "$env_file"
      else
        echo "${var}=${final_value}" >>"$env_file"
      fi
      debug "Set $var=$final_value"
      break
    else
      if [[ -z "$final_value" ]]; then
        log_error "Variable $var cannot be empty. Please provide a value."
      else
        log_error "Invalid input for $var. Please try again."
      fi
    fi
  done
}

# Prompt for variable during initial setup
prompt_variable() {
  local var="$1" requirement="$2" env_file="$3"
  local existing="" default="" suggested=""

  # First check if variable already exists in the target env file
  existing=$(get_env_var "" "$var" "$env_file" 2>/dev/null || echo "")

  # If not found in main env file, check .env.setup as fallback
  if [[ -z "$existing" && -z "${WIZARD_MODE:-}" && -f ".env.setup" ]]; then
    existing=$(get_env_var "" "$var" ".env.setup" 2>/dev/null || echo "")
  fi

  # Skip prompting if variable already exists and has a valid (non-placeholder) value
  if [[ -n "$existing" ]] && ! has_placeholder "$existing"; then
    debug "Skipping $var: already exists with value '$existing'"
    return 0
  fi

  default=$(get_schema_default "$var" 2>/dev/null || echo "")
  suggested="${existing:-$default}"
  debug "Processing $var: existing='$existing', default='$default', suggested='$suggested'"
  if [[ -n "$suggested" ]]; then
    if has_placeholder "$suggested"; then
      log_warn "Variable $var has placeholder value - please provide real value"
      suggested=""
    fi
  fi
  local prompt="Enter $var"
  [[ -n "$suggested" ]] && prompt="$prompt [$suggested]"
  [[ "$requirement" == "optional" ]] && prompt="$prompt (optional)"
  prompt="$prompt: "
  local user_input
  log_ask "$prompt"
  read -r user_input
  local final_value="${user_input:-$suggested}"
  if [[ -n "$final_value" ]]; then
    # Check if variable already exists and update it, otherwise append
    if grep -q "^${var}=" "$env_file" 2>/dev/null; then
      debug "Variable $var already exists in $env_file, updating..."
      sed -i "s|^${var}=.*|${var}=${final_value}|" "$env_file"
      debug "Updated $var=$final_value"
    else
      debug "Variable $var does not exist in $env_file, appending..."
      echo "$var=$final_value" >>"$env_file"
      debug "Set $var=$final_value"
    fi
  elif [[ "$requirement" == "required" ]]; then
    log_error "Required variable $var cannot be empty"
    prompt_variable "$var" "$requirement" "$env_file"
  fi
}

# Fix incomplete .env file by prompting for missing variables
fix_incomplete_env() {
  local env_file="${1:-${ENV_FILE:-.env}}"
  local missing_vars=()
  [[ ! -f "$env_file" ]] && {
    log_error ".env file not found"
    return 1
  }
  debug "fix_incomplete_env: Scanning for missing variables in $env_file"
  mapfile -t missing_vars < <(check_missing_variables "$env_file")
  local filtered_vars=()
  for var in "${missing_vars[@]}"; do
    [[ -n "$var" ]] && filtered_vars+=("$var")
  done
  missing_vars=("${filtered_vars[@]}")
  debug "fix_incomplete_env: Found ${#missing_vars[@]} missing variables: ${missing_vars[*]}"
  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    log_info "Found ${#missing_vars[@]} missing required variable(s)"
    debug "About to prompt for variables: ${missing_vars[*]}"
    for var in "${missing_vars[@]}"; do
      [[ -z "$var" ]] && continue
      debug "Prompting for variable: $var"
      prompt_missing_var "$var" "$env_file"
    done
    log_ok "Updated $env_file with missing variables"
  else
    debug "No missing variables found, but fix_incomplete_env was called"
  fi
}

# New deployment environment wizard with user-driven flow
deployment_environment_wizard() {
  local continue_setup="y"

  while [[ "$continue_setup" == "y" || "$continue_setup" == "Y" ]]; do
    show_environment_menu
    local user_choice
    get_environment_choice user_choice

    # user_choice is guaranteed to be valid since get_environment_choice loops until valid input
    configure_single_environment "$user_choice"
    log_ok "Required values for \"$user_choice\" are configured."
    echo

    # Ask if they want to configure another environment
    log_ask "Do you want to configure another environment? [y/N]: "
    read -r continue_setup
    continue_setup="${continue_setup:-n}"
  done
}

# Show menu of detected environments plus option for new ones
show_environment_menu() {
  log_header "Choose the environment to configure"
  log_info "Type a number from the list, or enter a new name (e.g. staging):"
  echo

  # Always show local as option 1
  log_option 1 "local"

  # Show detected deployment environments (excluding local)
  local environments
  environments=$(get_env_environments 2>/dev/null || echo "")
  local env_count=2

  if [[ -n "$environments" ]]; then
    IFS=' ' read -r -a env_array <<<"$environments"
    for env in "${env_array[@]}"; do
      # Skip local since it's already shown as option 1
      if [[ "$env" != "local" ]]; then
        log_option "$env_count" "$env (detected in your .env)"
        env_count=$((env_count + 1))
      fi
    done
  fi

  echo
}

# Get user's environment choice (number or name)
get_environment_choice() {
  local -n choice_ref=$1
  local user_input

  while true; do
    log_ask "Enter environment name or number: "
    read -r user_input

    if [[ "$user_input" =~ ^[0-9]+$ ]]; then
      # User entered a number
      case "$user_input" in
      1)
        choice_ref="local"
        return 0
        ;;
      *)
        # Map number to detected environment
        local environments
        environments=$(get_env_environments 2>/dev/null || echo "")
        if [[ -n "$environments" ]]; then
          IFS=' ' read -r -a env_array <<<"$environments"
          # Filter out local from the array for numbering
          local filtered_array=()
          for env in "${env_array[@]}"; do
            [[ "$env" != "local" ]] && filtered_array+=("$env")
          done
          local env_index=$((user_input - 2))
          if [[ $env_index -ge 0 && $env_index -lt ${#filtered_array[@]} ]]; then
            choice_ref="${filtered_array[$env_index]}"
            return 0
          else
            log_warn "Invalid number. Please try again."
          fi
        else
          log_warn "Invalid number. Please try again."
        fi
        ;;
      esac
    elif [[ -n "$user_input" ]]; then
      # User entered an environment name
      choice_ref="$user_input"
      return 0
    else
      # Default to local if user just presses Enter
      choice_ref="local"
      return 0
    fi
  done
}

# Configure a single environment
configure_single_environment() {
  local env_name="$1"

  if [[ "$env_name" == "local" ]]; then
    configure_local_environment
  else
    configure_deployment_environment "$env_name"
  fi
}

# Configure local environment variables
configure_local_environment() {
  log_info "Configuring local environment variables..."

  # Note: local environment doesn't get added to ENVIRONMENTS since it uses
  # base variables (DB_HOST) not prefixed ones (local_DB_HOST)

  # Configure local required variables
  for var in "${LOCAL_REQUIRED_VARS[@]}"; do
    prompt_variable "$var" "required" "$ENV_FILE"
  done
}

# Configure deployment environment variables
configure_deployment_environment() {
  local env_name="$1"
  local env_name_upper="${env_name^^}" # Convert to uppercase

  # Check if this is a new environment (not detected in .env)
  # Skip confirmation for 'local' since it's a special case that's always available
  if [[ "$env_name" != "local" ]]; then
    local environments
    environments=$(get_env_environments 2>/dev/null || echo "")
    if [[ -z "$environments" || ! "$environments" =~ (^|[[:space:]])$env_name_upper([[:space:]]|$) ]]; then
      # This is a new environment, ask for confirmation
      log_ask "Proceed creating the \`$env_name\` environment [Y/n]? "
      read -r confirm
      confirm="${confirm:-Y}"
      if [[ ! "$confirm" =~ ^[Yy] ]]; then
        log_info "Environment creation cancelled."
        return 1
      fi
    fi
  fi

  log_info "Configuring deployment environment: $env_name"

  # Add environment to ENVIRONMENTS list (use uppercase for consistency)
  add_environment_to_list "$env_name_upper"

  # Configure environment-specific variables (use uppercase for variable names)
  for var in "${ENV_REQUIRED_VARS[@]}"; do
    prompt_variable "${env_name_upper}_${var}" "required" "$ENV_FILE"
  done
}

# Add environment to ENVIRONMENTS list
add_environment_to_list() {
  local env_name="$1"
  local current_envs

  if grep -q "^ENVIRONMENTS=" "$ENV_FILE" 2>/dev/null; then
    current_envs=$(grep "^ENVIRONMENTS=" "$ENV_FILE" | cut -d'=' -f2-)
    # Check if environment is already in the list
    if [[ ! "$current_envs" =~ (^|[[:space:]])$env_name([[:space:]]|$) ]]; then
      # Add to existing list
      sed -i "s/^ENVIRONMENTS=.*/ENVIRONMENTS=$current_envs $env_name/" "$ENV_FILE"
    fi
  else
    # Create new ENVIRONMENTS line
    echo "ENVIRONMENTS=$env_name" >>"$ENV_FILE"
  fi
}

# Check if GitHub variables are complete
check_github_variables() {
  local env_file="${1:-$ENV_FILE}"
  local missing_gh_vars=()

  # Get only GitHub context variables
  for var in "${REQUIRED_VARS[@]}"; do
    if has_context "$var" "gh"; then
      if ! grep -q "^${var}=" "$env_file" 2>/dev/null; then
        missing_gh_vars+=("$var")
      fi
    fi
  done

  printf '%s\n' "${missing_gh_vars[@]}"
}

# Setup GitHub variables interactively
setup_github_variables() {
  local env_file="${1:-$ENV_FILE}"
  local missing_gh_vars=()

  log_header "GitHub Repository Setup"
  log_info "Now we'll configure GitHub repository settings for deployment."
  echo

  # Check for missing GitHub variables
  mapfile -t missing_gh_vars < <(check_github_variables "$env_file")

  # Filter out any empty entries
  local filtered_gh_vars=()
  for var in "${missing_gh_vars[@]}"; do
    [[ -n "$var" ]] && filtered_gh_vars+=("$var")
  done
  missing_gh_vars=("${filtered_gh_vars[@]}")

  # Debug: show what GitHub variables we're checking
  debug "GitHub variables check: REQUIRED_VARS with gh context"
  for var in "${REQUIRED_VARS[@]}"; do
    if has_context "$var" "gh"; then
      local exists="NOT FOUND"
      grep -q "^${var}=" "$env_file" 2>/dev/null && exists="FOUND"
      debug "  $var (gh context): $exists"
    fi
  done
  debug "Missing GitHub variables: ${missing_gh_vars[*]}"
  debug "Missing GitHub variables count: ${#missing_gh_vars[@]}"

  if [[ ${#missing_gh_vars[@]} -gt 0 ]]; then
    log_info "Found ${#missing_gh_vars[@]} missing GitHub variable(s)"
    debug "About to prompt for: ${missing_gh_vars[*]}"
    for var in "${missing_gh_vars[@]}"; do
      [[ -z "$var" ]] && continue
      prompt_missing_var "$var" "$env_file"
    done
    log_ok "GitHub variables configured"
  else
    log_ok "All GitHub variables are already configured"
  fi
}

# Check if environments are complete (excluding GitHub variables)
is_environments_complete() {
  local env_file="${1:-$ENV_FILE}"

  # Check if all non-GitHub variables are complete
  local missing_vars
  mapfile -t missing_vars < <(check_missing_variables "$env_file" "gh")
  local filtered_vars=()
  for var in "${missing_vars[@]}"; do
    [[ -n "$var" ]] && filtered_vars+=("$var")
  done
  missing_vars=("${filtered_vars[@]}")

  [[ ${#missing_vars[@]} -eq 0 ]]
}

# Interactive completion of incomplete environments
complete_incomplete_environments() {
  local env_file="${1:-$ENV_FILE}"
  local missing_vars
  mapfile -t missing_vars < <(check_missing_variables "$env_file" "gh")
  local filtered_vars=()
  for var in "${missing_vars[@]}"; do
    [[ -n "$var" ]] && filtered_vars+=("$var")
  done
  missing_vars=("${filtered_vars[@]}")

  if [[ ${#missing_vars[@]} -eq 0 ]]; then
    return 0 # All complete
  fi

  # Group missing variables by environment
  local incomplete_envs=()

  for var in "${missing_vars[@]}"; do
    # Extract environment name from variable (e.g., HOLA_PATH -> HOLA)
    if [[ "$var" =~ ^([^_]+)_ ]]; then
      local env_name="${BASH_REMATCH[1]}"
      if [[ ! " ${incomplete_envs[*]} " =~ " ${env_name} " ]]; then
        incomplete_envs+=("$env_name")
      fi
    fi
  done

  log_warn "Found incomplete environment(s): ${incomplete_envs[*]}"
  log_info "You need to complete these environments before proceeding to GitHub upload."
  echo

  log_ask "Would you like to complete the missing variables now? [Y/n]: "
  read -r complete_now
  complete_now="${complete_now:-Y}"

  if [[ ! "$complete_now" =~ ^[Yy] ]]; then
    log_error "Cannot proceed with incomplete environments. Please run this command again to complete them."
    return 1
  fi

  # Complete each incomplete environment
  for env in "${incomplete_envs[@]}"; do
    log_header "Completing environment: $env"

    # Get missing vars for this specific environment
    local env_missing_vars=()
    for var in "${missing_vars[@]}"; do
      if [[ "$var" =~ ^${env}_ ]]; then
        env_missing_vars+=("$var")
      fi
    done

    log_verbose "Missing variables for $env: ${env_missing_vars[*]}"
    for var in "${env_missing_vars[@]}"; do
      prompt_missing_var "$var" "$env_file"
    done

    log_ok "Environment $env completed"
    echo
  done

  return 0
}
