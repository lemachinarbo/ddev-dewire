#!/usr/bin/env bash
# Environment Wizard Library
# Single responsibility: Main wizard flow and menu logic

# Source guard
[[ -n "${ENV_WIZARD_LOADED:-}" ]] && return 0
readonly ENV_WIZARD_LOADED=1

# Source required dependencies
source "$(dirname "${BASH_SOURCE[0]}")/schema-parser.sh"
source "$(dirname "${BASH_SOURCE[0]}")/env-validator.sh"
source "$(dirname "${BASH_SOURCE[0]}")/env-wizard-prompt.sh"
source "$(dirname "${BASH_SOURCE[0]}")/env-wizard-complete.sh"
source "$(dirname "${BASH_SOURCE[0]}")/env-wizard-configure.sh"
source "$(dirname "${BASH_SOURCE[0]}")/env-wizard-githubvars.sh"

# New deployment environment wizard with user-driven flow
deployment_environment_wizard() {
  # Track if .env existed and was non-empty before wizard starts
  if [[ -f "$ENV_FILE" && -s "$ENV_FILE" ]]; then
    export ENV_FILE_EXISTED_BEFORE_WIZARD=1
  else
    export ENV_FILE_EXISTED_BEFORE_WIZARD=0
  fi

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
  log_info "Enter a number or name from the list, or create an environment"
  log_info "by typing a new name (e.g. staging):"
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
    log_ask "Type a name or number [local]: "
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
