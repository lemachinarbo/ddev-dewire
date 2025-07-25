#!/usr/bin/env bash
# GitHub Uploader Library
# Single responsibility: Upload variables and secrets to GitHub

# Source guard
[[ -n "${GITHUB_UPLOADER_LOADED:-}" ]] && return 0
GITHUB_UPLOADER_LOADED=1

# Source required dependencies  
source "$(dirname "${BASH_SOURCE[0]}")/schema-parser.sh"
source "$(dirname "${BASH_SOURCE[0]}")/env-validator.sh"

# Upload a secret to GitHub
upload_secret() {
  local var="$1" value="$2" scope="${3:-repo}"
  local cmd
  
  if [[ "$scope" == "repo" ]]; then
    cmd="gh secret set '$var' --body '$value' --repo '$REPO_FULL'"
  else
    cmd="gh secret set '$var' --env '$scope' --body '$value' --repo '$REPO_FULL'"
  fi
  
  if eval "$cmd" >/dev/null 2>&1; then
    debug "Uploaded secret: $var ($scope)"
    return 0
  else
    log_error "Failed to upload secret: $var"
    return 1
  fi
}

# Upload variables to GitHub (repository or environment scope)
upload_variables() {
  local scope="$1"
  shift
  local vars=("$@")
  local changed=0 errors=0
  
  debug "Uploading variables to $scope: ${vars[*]}"
  
  for var in "${vars[@]}"; do
    local value
    if [[ "$scope" == "repo" ]]; then
      value=$(get_env_var "" "$var" "$ENV_FILE" 2>/dev/null || echo "")
    else
      value=$(get_env_var "" "${scope}_${var}" "$ENV_FILE" 2>/dev/null || echo "")
    fi
    
    if [[ -n "$value" ]]; then
      local cmd
      if [[ "$scope" == "repo" ]]; then
        cmd="gh variable set '$var' --body '$value' --repo '$REPO_FULL'"
      else
        cmd="gh variable set '$var' --env '$scope' --body '$value' --repo '$REPO_FULL'"
      fi
      
      if eval "$cmd" >/dev/null 2>&1; then
        ((changed++))
        debug "Uploaded: $var"
      else
        log_error "Failed to upload: $var"
        ((errors++))
      fi
    fi
  done
  
  [[ $changed -gt 0 ]] && log_ok "$changed variables uploaded to $scope"
  [[ $errors -gt 0 ]] && log_error "$errors upload failures"
  
  return $errors
}

# Verify GitHub CLI prerequisites
verify_github_cli() {
  # Check GitHub CLI installation
  if ! command -v gh >/dev/null; then
    log_error "GitHub CLI not found. Please install it: https://cli.github.com/"
    return 1
  fi
  
  # Check authentication
  if ! gh auth status >/dev/null 2>&1; then
    log_error "GitHub CLI not authenticated. Run: gh auth login"
    return 1
  fi
  
  # Check repository access
  if ! gh repo view "$REPO_FULL" >/dev/null 2>&1; then
    log_error "Cannot access repository $REPO_FULL. Check permissions."
    return 1
  fi
  
  return 0
}

# Upload all data to GitHub (main function)
upload_github_data() {
  local errors=0
  
  log_info "Uploading to GitHub..."
  
  # Verify prerequisites
  if ! verify_github_cli; then
    return 1
  fi
  
  # Repository variables
  upload_variables "repo" "${REQUIRED_VARS[@]}" "${OPTIONAL_VARS[@]}" || ((errors++))
  
  # Repository secrets
  for var in "${REPO_SECRET_VARS[@]}"; do
    local value
    value=$(get_env_var "" "$var" "$ENV_FILE" 2>/dev/null || echo "")
    [[ -n "$value" ]] && upload_secret "$var" "$value" "repo" || ((errors++))
  done
  
  # Environment-specific data
  local environments
  environments=$(get_env_environments "$ENV_FILE" 2>/dev/null || echo "")
  environments=$(echo "$environments" | sed 's/[",]/ /g' | xargs)
  
  for env in LOCAL $environments; do
    # Create environment
    gh api --method PUT -H "Accept: application/vnd.github+json" "/repos/$REPO_OWNER/$REPO_NAME/environments/$env" >/dev/null 2>&1 || true
    
    # Upload variables and secrets
    if [[ "$env" == "LOCAL" ]]; then
      upload_variables "$env" "${LOCAL_REQUIRED_VARS[@]}" "${LOCAL_OPTIONAL_VARS[@]}" || ((errors++))
      
      for var in "${LOCAL_SECRET_VARS[@]}"; do
        local value
        value=$(get_env_var "" "$var" "$ENV_FILE" 2>/dev/null || echo "")
        [[ -n "$value" ]] && upload_secret "$var" "$value" "$env" || ((errors++))
      done
    else
      upload_variables "$env" "${ENV_REQUIRED_VARS[@]}" "${ENV_OPTIONAL_VARS[@]}" || ((errors++))
      
      for var in "${ENV_SECRET_VARS[@]}"; do
        local value
        value=$(get_env_var "" "${env}_${var}" "$ENV_FILE" 2>/dev/null || echo "")
        [[ -n "$value" ]] && upload_secret "$var" "$value" "$env" || ((errors++))
      done
      
      # SSH key upload
      local ssh_key_path="$HOME/.ssh/${SSH_KEY:-id_github}"
      if [[ -f "$ssh_key_path" ]]; then
        upload_secret "SSH_KEY" "$(cat "$ssh_key_path")" "$env" || ((errors++))
      fi
      
      # Known hosts
      local ssh_host_var="${env}_SSH_HOST"
      local ssh_host="${!ssh_host_var:-}"
      if [[ -n "$ssh_host" ]]; then
        local known_hosts
        known_hosts=$(ssh-keyscan "$ssh_host" 2>/dev/null || echo "")
        if [[ -n "$known_hosts" ]]; then
          gh variable set "KNOWN_HOSTS" --env "$env" --body "$known_hosts" --repo "$REPO_FULL" >/dev/null 2>&1 || true
        fi
      fi
    fi
  done
  
  if [[ $errors -eq 0 ]]; then
    log_ok "GitHub upload completed successfully"
  else
    log_error "Upload completed with $errors errors"
    return 1
  fi
  
  return 0
}
