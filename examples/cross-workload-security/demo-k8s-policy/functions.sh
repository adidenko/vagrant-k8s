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

readonly TYPE_TIMEOUT=0.05

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
      sleep $TYPE_TIMEOUT
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
}

# ----------------------------------------------------------------------------
# Common functions
# ----------------------------------------------------------------------------

function get_field {
    local data field
    field=$(($1 + 1))
    while read data; do
        echo "$data" | cut -d '|' -f "$field" | tr -d ' '
    done
}

function get_tenant_id {
    local name="$1"
    openstack project list | grep "$name" | cut -d '|' -f 2 | tr -d ' ' 2>/dev/null
}

function get_vm_ipaddr {
    local name="$1"
    nova list \
        | grep "$name" \
        | get_field 6 \
        | cut -f 2 -d '=' 2>/dev/null
}

function get_secgroup_id {
    local tenant_id="$1"
    local sg_name="${2:-default}"

    neutron security-group-list -c id -c name -c tenant_id \
        | grep "$tenant_id" \
        | grep "$sg_name" \
        | get_field 1 2>/dev/null

}

function wait_ssh {
    local host="$1"
    while ! sshpass -e ssh -q "cirros@$host" exit; do
        echo 'Waiting 30 seconds...'
        sleep 30
        echo 'Trying again...'
    done
    echo "SSH on VM $host is available"
}

function get_calico_endpoint {
    local prefix=$1
    sudo calicoctl endpoint show --detailed \
        | grep "$prefix" \
        | cut -f 5 -d '|' \
        | tr -d ' ' 2>/dev/null
}

function render_template {
    local template=$1
    local lvalue=""
    local rvalue=""

    while IFS='' read -r line ; do
        while [[ "$line" =~ (\$\{[a-zA-Z_][a-zA-Z_0-9]*\}) ]] ; do
            lvalue=${BASH_REMATCH[1]}
            rvalue="$(eval echo "\"$lvalue\"")"
            line=${line//$lvalue/$rvalue}
        done
        echo "$line"
    done < $template
}
