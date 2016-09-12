#!/bin/bash

# ----------------------------------------------------------------------------
# Print functions
# ----------------------------------------------------------------------------

function type_str {
    local str="$@"
    for ((i=0; i<${#str}; i++)); do
        echo -n "${str:$i:1}" 1>&2
        sleep 0.05
    done
    echo 1>&2
}

function type_msg {
    echo -ne "\n\n" 1>&2
    for line in "$@"; do
        echo -n "### " 1>&2
        type_str "$line"
    done
}

function type_cmd {
    echo 1>&2
    echo -n "$ " 1>&2
    type_str "$@"
}

function run_cmd {
    type_cmd "$@"
    eval $@
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

