#!/bin/bash

set -o errexit
set -o nounset

source "./functions.sh"

type_msg "We prepared environment with 2 tenants: proj01 and proj02."

run_cmd "openstack project list | grep 'proj'"

type_msg "Each tenant has a security group that was configured" \
         "to allow ingress connections within security group" \
         "and from the host machine (to execute commands on VM remotely)."

run_cmd "neutron security-group-list | grep sg -A 3"

type_msg "Each tenant has an instance running."

run_cmd nova list --all-tenants

type_msg "Security group 'sg01' is assigned to an instance 'vm01'."

run_cmd export OS_TENANT_NAME=proj01
run_cmd nova list-secgroup vm01

type_msg "Security group 'sg02' is assigned to an instance 'vm02'."

run_cmd export OS_TENANT_NAME=proj02
run_cmd nova list-secgroup vm02

type_msg "Exiting from docker container."
