#!/bin/bash

set -o errexit
set -o nounset

# Debug mode
# DEMO_NO_TYPE=true

readonly BASE_DIR=$(realpath "$(dirname "${BASH_SOURCE}[0]")/..")

source "$BASE_DIR/functions.sh"

msg "We prepared environment with 2 tenants: proj01 and proj02."

run "openstack project list | grep 'proj'"

msg "Each tenant has a security group that was configured" \
     "to allow ingress connections within security group" \
     "and from the host machine (to execute commands on VM remotely)."

run "neutron security-group-list | grep sg -A 3"

msg "Each tenant has an instance running."

run nova list --all-tenants

msg "Security group 'sg01' is assigned to an instance 'vm01'."

run export OS_TENANT_NAME=proj01
run nova list-secgroup vm01

msg "Security group 'sg02' is assigned to an instance 'vm02'."

run export OS_TENANT_NAME=proj02
run nova list-secgroup vm02

msg "Exiting from docker container."
