# shellcheck shell=bash
# Environment selection and resolution helpers

# Usage: select_environment [env_arg] [environments_var]
select_environment() {
    local env_arg="$1"
    local allowed_envs="$2"
    local envs
    IFS=' ' read -r -a envs <<<"$allowed_envs"
    if [[ -n "$env_arg" ]]; then
        for env in "${envs[@]}"; do
            if [[ "$env" == "$env_arg" ]]; then
                SELECTED_ENV="$env"
                return 0
            fi
        done
        log_error "Invalid environment: $env_arg. Allowed: $allowed_envs"
        exit 1
    fi
    log_header "Which environment do you want to setup?"
    local i=1
    for env in "${envs[@]}"; do
        log_option "$i" "$env"
        i=$((i + 1))
    done
    local selection
    while true; do
        log_ask "Select environment number [1]: "
        read -r selection
        selection=${selection:-1}
        if [[ "$selection" =~ ^[0-9]+$ ]] && ((selection >= 1 && selection <= ${#envs[@]})); then
            env="${envs[$((selection - 1))]}"
            SELECTED_ENV="$env"
            return 0
        else
            log_warn "Invalid selection. Please choose a valid number."
        fi
    done
}

resolve_environment() {
    local env_arg="$1"
    local allowed_envs="$2"
    if [[ "$env_arg" =~ ^--(.+) ]]; then
        SELECTED_ENV="${BASH_REMATCH[1]}"
    elif [[ -n "$env_arg" ]]; then
        SELECTED_ENV="$env_arg"
    else
        SELECTED_ENV=""
        select_environment "" "$allowed_envs"
        if [[ -z "$SELECTED_ENV" ]]; then
            log_error "No environment selected. Exiting."
            exit 1
        fi
    fi
}

# Defensive: default reply to 'n' in ask_user
ask_user() {
    local prompt="$1"
    local critical="${2:-false}"
    if [[ "$LAZY_MODE" == true && "$critical" == false ]]; then
        reply="y"
        log_ask "$prompt y (auto)"
        echo
    else
        log_ask "$prompt"
        read -r reply
        reply=${reply:-n}
    fi
    REPLY="$reply"
}
