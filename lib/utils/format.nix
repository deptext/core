# Formatting Utilities
#
# This module provides shell script functions for formatting durations and
# file sizes in human-readable formats.
#
# WHAT THIS MODULE DOES:
# - format_duration: Converts milliseconds to "Xm Y.ZZs" format
# - format_size: Converts bytes to "X.XX MB/KB/B" format
#
# These functions are designed to be used within Nix derivation build phases.
# They are sourced as shell script snippets, not called as Nix functions.
#
# USAGE IN A DERIVATION:
#   buildPhase = ''
#     ${formatUtils.formatDurationFn}
#     ${formatUtils.formatSizeFn}
#
#     duration=$(format_duration 12345)
#     size=$(format_size 1048576)
#   '';

{ lib }:

{
  # formatDurationFn: Shell function to format milliseconds to human-readable duration
  #
  # WHAT THIS DOES:
  # Converts a duration in milliseconds to a human-readable string.
  # - Under 1 minute: "X.XXs" (e.g., "45.23s")
  # - 1-60 minutes: "Xm Y.ZZs" (e.g., "4m 11.76s")
  # - Over 1 hour: "Xh Ym Z.ZZs" (e.g., "1h 23m 45.67s")
  #
  # INPUT: An integer representing milliseconds
  # OUTPUT: A formatted string printed to stdout
  #
  # EXAMPLE:
  #   format_duration 251755  # outputs "4m 11.75s"
  #   format_duration 45230   # outputs "45.23s"
  formatDurationFn = ''
    # format_duration: Convert milliseconds to human-readable duration
    # Input: milliseconds (integer)
    # Output: "Xh Ym Z.ZZs" or "Ym Z.ZZs" or "Z.ZZs"
    format_duration() {
      local ms=$1

      # Handle missing or invalid input
      if [ -z "$ms" ] || [ "$ms" = "null" ]; then
        echo "-"
        return
      fi

      # Calculate time components
      # "local" creates a variable only visible inside this function
      local seconds=$((ms / 1000))
      local millis=$((ms % 1000))
      local minutes=$((seconds / 60))
      local secs=$((seconds % 60))
      local hours=$((minutes / 60))
      local mins=$((minutes % 60))

      # Format with centiseconds (2 decimal places)
      # We divide millis by 10 to get centiseconds (hundredths of a second)
      local centis=$((millis / 10))

      # Choose output format based on magnitude
      # printf formats the output nicely with leading zeros where needed
      if [ $hours -gt 0 ]; then
        # Hours, minutes, and seconds
        printf "%dh %dm %d.%02ds" $hours $mins $secs $centis
      elif [ $minutes -gt 0 ]; then
        # Minutes and seconds
        printf "%dm %d.%02ds" $mins $secs $centis
      else
        # Just seconds
        printf "%d.%02ds" $secs $centis
      fi
    }
  '';

  # formatSizeFn: Shell function to format bytes to human-readable size
  #
  # WHAT THIS DOES:
  # Converts a size in bytes to a human-readable string with appropriate units.
  # - Under 1 KB: "X B" (e.g., "512 B")
  # - 1 KB - 1 MB: "X.XX KB" (e.g., "47.19 KB")
  # - Over 1 MB: "X.XX MB" (e.g., "1.50 MB")
  #
  # INPUT: An integer representing bytes
  # OUTPUT: A formatted string printed to stdout
  #
  # EXAMPLE:
  #   format_size 48320   # outputs "47.18 KB"
  #   format_size 1572864 # outputs "1.50 MB"
  formatSizeFn = ''
    # format_size: Convert bytes to human-readable size
    # Input: bytes (integer)
    # Output: "X.XX MB", "X.XX KB", or "X B"
    format_size() {
      local bytes=$1

      # Handle missing or invalid input
      if [ -z "$bytes" ] || [ "$bytes" = "null" ]; then
        echo "-"
        return
      fi

      # Handle zero bytes
      if [ "$bytes" -eq 0 ]; then
        echo "0 B"
        return
      fi

      # 1 MB = 1048576 bytes (1024 * 1024)
      # 1 KB = 1024 bytes
      if [ $bytes -ge 1048576 ]; then
        # Calculate MB with 2 decimal places
        # We multiply by 100 first, then divide, to preserve decimal precision
        # without needing floating-point arithmetic
        local mb=$((bytes * 100 / 1048576))
        printf "%d.%02d MB" $((mb / 100)) $((mb % 100))
      elif [ $bytes -ge 1024 ]; then
        # Calculate KB with 2 decimal places
        local kb=$((bytes * 100 / 1024))
        printf "%d.%02d KB" $((kb / 100)) $((kb % 100))
      else
        # Plain bytes
        printf "%d B" $bytes
      fi
    }
  '';
}
