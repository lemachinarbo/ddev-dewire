#!/usr/bin/env bash
# shellcheck shell=bash
# Environment Loader - Compatibility Bridge
# This file provides backward compatibility by sourcing the new modular libraries

# Source guard
[[ -n "${ENV_LOADER_LOADED:-}" ]] && return 0
ENV_LOADER_LOADED=1

# Source all the new modular libraries
source "$(dirname "${BASH_SOURCE[0]}")/env-loader-simple.sh"

# Backward compatibility: expose the old function name
validate_and_load_env() {
  load_environment "$@"
}

# Re-export key functions that scripts might expect
# (They're already defined in the libraries, this just ensures they're available)