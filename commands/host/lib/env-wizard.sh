#!/usr/bin/env bash
# Environment Wizard Library  
# Single responsibility: Interactive prompting and .env file generation/fixing

# Source guard
[[ -n "${ENV_WIZARD_LOADED:-}" ]] && return 0
ENV_WIZARD_LOADED=1

# Source required dependencies
source "$(dirname "${BASH_SOURCE[0]}")/schema-parser.sh"
source "$(dirname "${BASH_SOURCE[0]}")/env-validator.sh"

# Check if value has placeholder content
has_placeholder() {
  local value="$1"
  # Check for specific placeholder patterns, not broad matches like "example"
  [[ "$value" == *"your-"* || "$value" == *"password1234"* || "$value" == *"yourdomain"* || "$value" == *"/your/"* || "$value" == "example_user" || "$value" == "example_db" ]]
}

# Validate user input based on variable type
is_valid_input() {
  local var="$1" value="$2"
  
  # Basic validation rules
  case "$var" in
    *EMAIL) [[ "$value" =~ ^[^@]+@[^@]+\.[^@]+$ ]] ;;
    *_HOST) [[ -n "$value" ]] ;;  # Allow localhost for database hosts
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
  
  # Skip placeholders in wizard mode
  if [[ -n "${WIZARD_MODE:-}" && -n "$suggested" ]] && has_placeholder "$suggested"; then
    suggested=""
  fi
  
  while true; do
    local prompt="Enter $var"
    [[ -n "$suggested" ]] && prompt="$prompt [$suggested]"
    prompt="$prompt: "
    
    log_ask "$prompt"
    read -r user_input
    
    final_value="${user_input:-$suggested}"
    
    # Validate that we have a non-empty value and it passes validation
    if [[ -n "$final_value" ]] && is_valid_input "$var" "$final_value"; then
      # Update or append to .env file
      if grep -q "^${var}=" "$env_file" 2>/dev/null; then
        sed -i "s|^${var}=.*|${var}=${final_value}|" "$env_file"
      else
        echo "${var}=${final_value}" >> "$env_file"
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
  
  # Only use .env.setup values if WIZARD_MODE is not set
  if [[ -z "${WIZARD_MODE:-}" && -f ".env.setup" ]]; then
    existing=$(get_env_var "" "$var" ".env.setup" 2>/dev/null || echo "")
  fi
  
  default=$(get_schema_default "$var" 2>/dev/null || echo "")
  suggested="${existing:-$default}"
  
  debug "Processing $var: existing='$existing', default='$default', suggested='$suggested'"
  
  # Handle placeholder values
  if [[ -n "$suggested" ]] && has_placeholder "$suggested"; then
    log_warn "Variable $var has placeholder value - please provide real value"
    suggested=""
  fi
  
  # Interactive prompt
  local prompt="Enter $var"
  [[ -n "$suggested" ]] && prompt="$prompt [$suggested]"
  [[ "$requirement" == "optional" ]] && prompt="$prompt (optional)"
  prompt="$prompt: "
  
  local user_input
  log_ask "$prompt"
  read -r user_input
  
  local final_value="${user_input:-$suggested}"
  
  if [[ -n "$final_value" ]]; then
    echo "$var=$final_value" >> "$env_file"
    debug "Set $var=$final_value"
  elif [[ "$requirement" == "required" ]]; then
    log_error "Required variable $var cannot be empty"
    prompt_variable "$var" "$requirement" "$env_file"
  fi
}

# Fix incomplete .env file by prompting for missing variables
fix_incomplete_env() {
  local env_file="${1:-${ENV_FILE:-.env}}"
  local missing_vars=()
  
  [[ ! -f "$env_file" ]] && { log_error ".env file not found"; return 1; }
  
  debug "fix_incomplete_env: SETUP_MODE=${SETUP_MODE:-unset} - scanning for missing variables"
  
  # Get missing variables from validator
  mapfile -t missing_vars < <(check_missing_variables "$env_file")
  
  # Filter out empty variables
  local filtered_vars=()
  for var in "${missing_vars[@]}"; do
    [[ -n "$var" ]] && filtered_vars+=("$var")
  done
  missing_vars=("${filtered_vars[@]}")
  
  debug "fix_incomplete_env: Found ${#missing_vars[@]} missing variables: ${missing_vars[*]}"
  debug "Missing variables list: ${missing_vars[*]}"
  
  # Prompt for missing variables
  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    log_info "Found ${#missing_vars[@]} missing required variable(s)"
  debug "About to prompt for variables: ${missing_vars[*]}"
    for var in "${missing_vars[@]}"; do
      # Skip empty variable names
      [[ -z "$var" ]] && continue
  debug "Prompting for variable: $var"
      prompt_missing_var "$var" "$env_file"
    done
    log_ok "Updated $env_file with missing variables"
  else
  debug "No missing variables found, but fix_incomplete_env was called"
  fi
}

# Choose setup mode for initial wizard
choose_setup_mode() {
  log_info "Setup mode:"
  log_option 1 "Local environment only"
  log_option 2 "Deployment environments"
  log_option 3 "All (local + environments)"
  local selection
  while true; do
    log_ask "Select mode [3]: "
    read -r selection
    case "${selection:-3}" in
      1) SETUP_MODE="local"; break ;;
      2) SETUP_MODE="env";   break ;;
      3) SETUP_MODE="all";   break ;;
      *) log_warn "Invalid selection. Choose 1, 2, or 3." ;;
    esac
  done
  export SETUP_MODE
}

# Determine setup mode from existing .env file or prompt user
determine_setup_mode() {
  local env_file="${1:-${ENV_FILE:-.env}}"
  
  # Check what types of variables exist in the file
  local has_local=false
  local has_env=false
  
  if [[ -f "$env_file" ]]; then
    # Check for local variables (typically DB_HOST, ADMIN_NAME, etc.)
    if grep -q "^DB_HOST=" "$env_file" 2>/dev/null || grep -q "^ADMIN_NAME=" "$env_file" 2>/dev/null; then
      has_local=true
  debug "Found local variables in $env_file"
    fi
    
    # Check for repository variables
    if grep -q "^REPO_OWNER=" "$env_file" 2>/dev/null || grep -q "^REPO_NAME=" "$env_file" 2>/dev/null; then
  debug "Found repository variables in $env_file"
    fi
    
    # Check for environment variables (PROD_, STAGING_, etc.)
    if grep -q "^[A-Z]+_DB_HOST=" "$env_file" 2>/dev/null || grep -q "^[A-Z]+_HOST=" "$env_file" 2>/dev/null; then
      has_env=true
  debug "Found environment-specific variables in $env_file"
    fi
    
  debug "Variable detection: has_local=$has_local, has_env=$has_env"
  fi
  
  # Determine mode based on existing variables
  if [[ "$has_local" == true && "$has_env" == true ]]; then
    SETUP_MODE="all"
    debug "Auto-detected mode: all (found both local and environment variables)"
  elif [[ "$has_local" == true ]]; then
    SETUP_MODE="local"
    debug "Auto-detected mode: local (found local variables only)"
  elif [[ "$has_env" == true ]]; then
    SETUP_MODE="env"
    debug "Auto-detected mode: env (found environment variables only)"
  else
    # No clear mode detected, prompt user
    log_info "Cannot determine setup mode from existing .env file."
  choose_setup_mode
  fi
  
  export SETUP_MODE
}

# Generate new .env file with wizard prompting
generate_env() {
  local env_file=".env"
  local setup_mode="${SETUP_MODE:-all}"
  WIZARD_MODE=true  # Flag to indicate we're in wizard mode
  
  debug "Generating $env_file (mode: $setup_mode)"
  
  cat > "$env_file" << 'EOF'
# DeWire Environment Configuration
# Generated by dw-gh-env wizard

# DeWire behavior flags
DEWIRE_ALLOW_CUSTOM_VARS=true
DEWIRE_ASK_ON_CUSTOM_VARS=true

EOF
  
  case "$setup_mode" in
    local|all)
      echo "# Local Environment Variables" >> "$env_file"
      for var in "${LOCAL_REQUIRED_VARS[@]}"; do
        # Skip ENVIRONMENTS - it's handled specially in environment setup
        [[ "$var" == "ENVIRONMENTS" ]] && continue
        prompt_variable "$var" "required" "$env_file"
      done
      
      echo -e "\n# Repository Variables" >> "$env_file"
      for var in "${REQUIRED_VARS[@]}"; do
        prompt_variable "$var" "required" "$env_file"
      done
      ;;& # fallthrough
    env|all)
      if [[ "$setup_mode" == "env" ]] || [[ "$setup_mode" == "all" ]]; then
        # Ask for environment name(s) first
        log_ask "Enter environment name(s) [PROD]: "
        read -r environments
        environments="${environments:-PROD}"
        echo -e "\nENVIRONMENTS=$environments" >> "$env_file"
      fi
      
      echo "" >> "$env_file"
      IFS=' ' read -ra env_array <<< "$environments"
      
      for env in "${env_array[@]}"; do
        env=$(echo "$env" | xargs | tr -d '"')
        echo "# $env Environment Variables" >> "$env_file"
        
        for var in "${ENV_REQUIRED_VARS[@]}"; do
          prompt_variable "${env}_${var}" "required" "$env_file"
        done
        echo "" >> "$env_file"
      done
      ;;
  esac
  
  log_ok "Generated $env_file"
}
