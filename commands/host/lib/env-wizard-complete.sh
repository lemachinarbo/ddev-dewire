#!/usr/bin/env bash
# env-wizard-complete.sh: Environment completion/repair logic for environment wizard

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
