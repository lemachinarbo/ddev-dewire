#!/usr/bin/env bash
# env-wizard-configure.sh: Environment configuration logic for environment wizard

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
