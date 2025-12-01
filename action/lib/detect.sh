#!/usr/bin/env bash
# action/lib/detect.sh - Seed file detection and validation
#
# This module handles finding seed.nix files in PR changes and validating
# that exactly one seed exists for processing.

# detect_seed_files() - Find all seed.nix files changed in the current PR
#
# Uses GitHub CLI to query the PR's changed files, then filters for files
# named exactly "seed.nix" (in any directory).
#
# Returns: Newline-separated list of seed.nix paths (may be empty)
#
# Example output:
#   examples/rust/serde/seed.nix
#   examples/python/requests/seed.nix
detect_seed_files() {
    gh pr view --json files --jq '
        .files[]
        | select(.path | endswith("/seed.nix") or . == "seed.nix")
        | .path
    '
}

# validate_seed_count() - Ensure exactly 0 or 1 seed files exist
#
# Arguments:
#   $1 = Newline-separated list of seed paths (from detect_seed_files)
#
# Returns (via stdout):
#   "skip" if 0 seeds (nothing to process)
#   The seed path if exactly 1 seed
#   Exits with code 1 if multiple seeds (error)
#
# This validation ensures clean, unambiguous processing - we refuse to
# guess which seed to process if multiple are present.
validate_seed_count() {
    local seeds="$1"

    # Count non-empty lines
    local count
    if [[ -z "$seeds" ]]; then
        count=0
    else
        count=$(echo "$seeds" | wc -l | tr -d ' ')
    fi

    case "$count" in
        0)
            log "No seed.nix files found in PR changes"
            log_success "Skipping - nothing to bloom"
            echo "skip"
            ;;
        1)
            local seed_path
            seed_path=$(echo "$seeds" | head -1)
            log_success "Found 1 seed: $seed_path"
            echo "$seed_path"
            ;;
        *)
            log_error "Multiple seed.nix files detected in PR:"
            echo "$seeds" | while read -r seed; do
                log_error "  - $seed"
            done
            log_error ""
            log_error "The bloom action processes one seed at a time."
            log_error "Please split your changes into separate PRs."
            exit 1
            ;;
    esac
}

# detect_and_validate() - Combined detection and validation
#
# Convenience function that detects seeds and validates count in one call.
#
# Returns (via stdout):
#   "skip" if no seeds
#   The seed path if exactly one seed
#   Exits with code 1 if multiple seeds
detect_and_validate() {
    local seeds
    seeds=$(detect_seed_files)
    validate_seed_count "$seeds"
}
