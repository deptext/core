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

# run_bloom() - Execute nix build on a seed file
#
# Arguments:
#   $1 = Path to the seed.nix file to process
#
# Creates a 'result' symlink pointing to the build output in the Nix store.
# This is the standard Nix way to access build outputs - no JSON parsing needed.
#
# Requires: ACTION_PATH environment variable pointing to deptext/core repo
run_bloom() {
    local seed_path="$1"
    local seed_dir
    seed_dir=$(dirname "$seed_path")
    local seed_abs_path
    seed_abs_path=$(cd "$seed_dir" && pwd)/$(basename "$seed_path")

    log "Running bloom on $seed_path..."

    # Build the seed, creating a 'result' symlink in the seed directory
    # Progress output goes to terminal (stderr), result symlink is our output
    if ! nix build \
        --impure \
        --out-link "$seed_dir/result" \
        --file "$ACTION_PATH/lib/eval-seed.nix" \
        --argstr seedPath "$seed_abs_path"; then
        log "ERROR: nix build failed"
        return 1
    fi

    log_success "Bloom completed: $seed_dir/result"
}

# copy_artifacts() - Copy bloom results from result symlink to seed directory
#
# Arguments:
#   $1 = Path to the seed directory (contains 'result' symlink)
#
# Copies everything from the result symlink to the seed directory,
# then removes the symlink (we don't want to commit it).
copy_artifacts() {
    local seed_dir="$1"
    local result_link="$seed_dir/result"

    log "Copying artifacts to $seed_dir..."

    # Check if result symlink exists
    if [[ ! -L "$result_link" ]]; then
        log "ERROR: Result symlink does not exist: $result_link"
        return 1
    fi

    # Show what we're copying
    log "Build output contents:"
    ls -la "$result_link"/ 2>&1 | while read -r line; do log "  $line"; done

    # Copy all files, dereferencing symlinks (-L follows the result symlink)
    for item in "$result_link"/*; do
        if [[ -e "$item" ]]; then
            local name
            name=$(basename "$item")
            log "  Copying: $name"
            cp -rL "$item" "$seed_dir/$name"
        fi
    done

    # Remove the result symlink (don't commit it to git)
    rm "$result_link"

    log_success "Artifacts copied to $seed_dir"
}

# process_seed() - Run bloom and copy artifacts for a seed
#
# Arguments:
#   $1 = Path to the seed.nix file
#
# Builds the seed (creating result symlink), copies artifacts, removes symlink.
process_seed() {
    local seed_path="$1"
    local seed_dir
    seed_dir=$(get_seed_directory "$seed_path")

    # Build the seed (creates result symlink in seed_dir)
    run_bloom "$seed_path"

    # Copy from result symlink to seed directory, then remove symlink
    copy_artifacts "$seed_dir"
}
