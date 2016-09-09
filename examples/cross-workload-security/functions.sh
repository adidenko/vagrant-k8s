#!/bin/bash

function type_cmd {
    echo -n "$ " 1>&2
    local str="$@"
    for ((i=0; i<${#str}; i++)); do
        echo -n "${str:$i:1}" 1>&2
        sleep 0.05
    done
    echo 1>&2
}

function run_cmd {
    type_cmd $@
    eval $@
}

function get_tenant_id {
    local name="$1"
    openstack project list | grep "$name" | cut -d '|' -f 2 | tr -d ' ' 2>/dev/null
}

function get_vm_id {
    local name="$1"
    nova list --all-tenants \
        | grep "$name" \
        | cut -f 8 -d '|' \
        | cut -f 2 -d '=' 2>/dev/null
}

function get_secgroup_id {
    local tenant_id="$1"
    local sg_name="${2:-default}"

    neutron security-group-list -c id -c name -c tenant_id \
        | grep "$tenant_id" \
        | grep "$sg_name" \
        | cut -f 2 -d '|' 2>/dev/null
}

function wait_ssh {
    local host="$1"
    while ! sshpass -e ssh -q "cirros@$host" exit; do
        type_cmd 'Waiting 30 seconds...'
        sleep 30
        type_cmd 'Trying again...'
    done
    type_cmd "SSH on VM $host is available"
}

function get_calico_endpoint {
    local prefix=$1
    sudo calicoctl endpoint show --detailed \
        | grep "$prefix" \
        | cut -f 5 -d '|' \
        | tr -d ' ' 2>/dev/null
}
