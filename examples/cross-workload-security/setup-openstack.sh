#!/bin/bash

# set -o xtrace
set -o errexit
set -o nounset

source "./functions.sh"

type_msg "Creating neutron network..."

run_cmd neutron net-create --shared --provider:network_type local net1
run_cmd neutron subnet-create --gateway 10.65.0.1 --enable-dhcp \
    --ip-version 4 --name subnet1 net1 10.65.0.0/24

type_msg "Creating projects: proj01, proj02..."

run_cmd openstack project create proj01
run_cmd openstack role add --project proj01 --user admin admin
proj01_id=$(get_tenant_id proj01)
echo "$proj01_id" > ./data/proj01-id

run_cmd openstack project create proj02
run_cmd openstack role add --project proj02 --user admin admin
proj02_id=$(get_tenant_id proj02)
echo "$proj02_id" > ./data/proj02-id

type_msg "Boot first VM..."

run_cmd "export OS_TENANT_NAME=proj01"

run_cmd nova boot vm01 --image cirros --flavor demo --nic net-name=net1
run_cmd neutron security-group-create allowhost01
run_cmd neutron security-group-rule-create --direction ingress --remote-ip-prefix 10.80.1.11 allowhost01
run_cmd nova add-secgroup vm01 allowhost01

type_msg "Boot second VM..."

run_cmd "export OS_TENANT_NAME=proj02"

run_cmd nova boot vm02 --image cirros --flavor demo --nic net-name=net1
run_cmd neutron security-group-create allowhost02
run_cmd neutron security-group-rule-create --direction ingress --remote-ip-prefix 10.80.1.11 allowhost02
run_cmd nova add-secgroup vm02 allowhost02

type_msg "Waiting for VMs to boot..."
sleep 10

run_cmd nova list --all-tenants

get_vm_id vm01 > ./data/vm01-ipaddr
get_vm_id vm02 > ./data/vm02-ipaddr

get_secgroup_id $proj01_id > ./data/proj01-sg-default-id
get_secgroup_id $proj02_id > ./data/proj02-sg-default-id
