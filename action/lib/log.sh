#!/usr/bin/env bash
# action/lib/log.sh - Logging functions for the DepText Bloom Action
#
# This module provides simple logging functions with consistent formatting.
# All output goes to stderr so it doesn't interfere with function return values.

# log() - Print an informational message
#
# Arguments:
#   $1 = The message to print
#
# Example:
#   log "Starting bloom process"
#   # Output: [bloom] Starting bloom process
log() {
    echo "[bloom] $1" >&2
}

# log_success() - Print a success message with a checkmark
#
# Arguments:
#   $1 = The message to print
#
# Example:
#   log_success "Artifacts committed"
#   # Output: [bloom] ✓ Artifacts committed
log_success() {
    echo "[bloom] ✓ $1" >&2
}

# log_error() - Print an error message with an X mark
#
# Arguments:
#   $1 = The message to print
#
# Example:
#   log_error "Multiple seeds detected"
#   # Output: [bloom] ✗ Multiple seeds detected
log_error() {
    echo "[bloom] ✗ $1" >&2
}
