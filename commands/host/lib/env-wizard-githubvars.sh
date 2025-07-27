#!/usr/bin/env bash
# env-wizard-githubvars.sh: GitHub variable logic for environment wizard

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
