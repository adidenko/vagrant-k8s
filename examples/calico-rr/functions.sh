#!/bin/bash

# ----------------------------------------------------------------------------
# Environment variables
# ----------------------------------------------------------------------------

# Run demo with no type emulation
# Default: false
DEMO_NO_TYPE=${DEMO_NO_TYPE:-false}

# Wait user input after each run
# Default: false
DEMO_RUN_WAIT=${DEMO_RUN_WAIT:-false}

# Do not execute commands
# Default: false
DEMO_DRY_RUN=${DEMO_DRY_RUN:-false}

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------

readonly TIMEOUT_TYPE=0.05
readonly TIMEOUT_POST_MSG=2
readonly TIMEOUT_POST_RUN=4

# ----------------------------------------------------------------------------
# Color constants
# ----------------------------------------------------------------------------

readonly FG_GREEN=$(tput setaf 2)
readonly FG_YELLOW=$(tput setaf 3)
readonly F_BOLD=$(tput bold)
readonly F_RESET=$(tput sgr0)

# ----------------------------------------------------------------------------
# Print functions
# ----------------------------------------------------------------------------

function _print_str {
  local string="$@"

  if $DEMO_NO_TYPE; then
    echo -n "$string"
  else
    for ((i=0; i<${#string}; i++)); do
      echo -n "${string:$i:1}"
      sleep $TIMEOUT_TYPE
    done
  fi
}

# Print message
function msg {
  echo -n "${F_BOLD}${FG_YELLOW}"
  for line in "$@"; do
    echo -n "# "
    _print_str "$line"
    echo
  done
  echo -n "${F_RESET}"

  sleep $(( $TIMEOUT_POST_MSG * $# ))
}

# Print command and execute it
function run {
  echo -n "${F_BOLD}${FG_GREEN}$ "
  _print_str "$@"
  echo -n "${F_RESET}"

  if $DEMO_RUN_WAIT; then
    read -s
  fi

  echo

  if ! $DEMO_DRY_RUN; then
    eval $@
  fi

  if ! $DEMO_NO_TYPE; then
    sleep $TIMEOUT_POST_RUN
  fi
}

# Print horizontal line
function print_hr {
    local size=${1:-77}
    local symbol=${2:-'='}
    echo -n "${F_BOLD}${FG_YELLOW}# "
    printf '%'${size}'s\n' | tr ' ' ${symbol}
    echo -n "${F_RESET}"
}

# ----------------------------------------------------------------------------
# Common functions
# ----------------------------------------------------------------------------

