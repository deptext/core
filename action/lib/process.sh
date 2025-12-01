#!/usr/bin/env bash
# action/lib/process.sh - Bloom processing and artifact handling
#
# This module handles running the bloom tool and copying artifacts
# to the appropriate location.

# get_seed_directory() - Extract the directory containing a seed file
#
# Arguments:
#   $1 = Full path to a seed.nix file
#
# Returns: The directory path
#
# Example:
#   get_seed_directory "examples/rust/serde/seed.nix"
#   # Returns: examples/rust/serde
get_seed_directory() {
    dirname "$1"
}

# run_bloom() - Execute the deptext bloom tool on a seed file
#
# Arguments:
#   $1 = Path to the seed.nix file to process
#
# The bloom tool reads the seed.nix, downloads the package, analyzes it,
# and outputs results to a "result" symlink.
#
# Requires: ACTION_PATH environment variable pointing to deptext/core repo
run_bloom() {
    local seed_path="$1"
    log "Running bloom on $seed_path..."
    "$ACTION_PATH/bin/bloom" "$seed_path"
    log_success "Bloom completed"
}

# copy_artifacts() - Move bloom results to the seed directory
#
# Arguments:
#   $1 = Path to the seed directory
#
# Copies everything from ./result/ to the seed's directory so artifacts
# live alongside the seed.nix file.
copy_artifacts() {
    local seed_dir="$1"
    log "Copying artifacts to $seed_dir..."

    # Check if result directory exists and has contents
    if [[ ! -d "result" ]] || [[ -z "$(ls -A result 2>/dev/null)" ]]; then
        log "No artifacts produced by bloom"
        return 0
    fi

    # Copy all files, dereferencing symlinks
    for item in result/*; do
        if [[ -e "$item" ]]; then
            local name
            name=$(basename "$item")
            cp -rL "$item" "$seed_dir/$name"
        fi
    done

    log_success "Artifacts copied to $seed_dir"
}

# process_seed() - Run bloom and copy artifacts for a seed
#
# Arguments:
#   $1 = Path to the seed.nix file
#
# Convenience function combining run_bloom and copy_artifacts.
process_seed() {
    local seed_path="$1"
    local seed_dir
    seed_dir=$(get_seed_directory "$seed_path")

    run_bloom "$seed_path"
    copy_artifacts "$seed_dir"
}
