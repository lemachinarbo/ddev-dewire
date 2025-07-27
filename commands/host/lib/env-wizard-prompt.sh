#!/usr/bin/env bash
# env-wizard-prompt.sh: User input and prompt logic for environment wizard

# Ensure .env backup is created only once per run before first write
ensure_env_backup() {
    local env_file="$1"
    if [[ "${ENV_FILE_EXISTED_BEFORE_WIZARD:-0}" == 1 && -z "${ENV_BACKUP_DONE:-}" && -f "$env_file" && -s "$env_file" ]]; then
        local timestamp
        timestamp=$(date +"%Y%m%d%H%M%S")
        cp "$env_file" "$env_file.backup.$timestamp"
        log_info "Backup of your $env_file saved as $env_file.backup.$timestamp"
        ENV_BACKUP_DONE=1
    fi
}

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
        ensure_env_backup "$env_file"
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

    ensure_env_backup "$env_file"

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
