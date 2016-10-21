#!/bin/bash

set -o xtrace
set -o errexit
set -o nounset

readonly BASE_DIR=$(realpath "$(dirname "${BASH_SOURCE}[0]")/..")
readonly HOST_IP="10.80.1.11"

source "$BASE_DIR/functions.sh"

neutron net-create --shared --provider:network_type local net1
neutron subnet-create --gateway 10.65.0.1 --enable-dhcp \
    --ip-version 4 --name subnet1 net1 10.65.0.0/24

# ---------- Create tenant ----------
proj01_id=$(openstack project create proj01 | grep " id " | get_field 2)
openstack role add --project "$proj01_id" --user admin admin
echo "$proj01_id" > ./data/proj01-id

# ---------- Create tenant ----------
proj02_id=$(openstack project create proj02 | grep " id " | get_field 2)
openstack role add --project "$proj02_id" --user admin admin
echo "$proj02_id" > ./data/proj02-id

export OS_TENANT_NAME=proj01

# ---------- Create security group ----------
sg01_id=$(neutron security-group-create sg01 | grep " id " | get_field 2)
echo "$sg01_id" > ./data/proj01-sg-default-id
neutron security-group-rule-create --remote-group-id "$sg01_id" "$sg01_id"
neutron security-group-rule-create --direction ingress --remote-ip-prefix "$HOST_IP" "$sg01_id"

# ---------- Create VM ----------
vm01_id=$(nova boot vm01 --image cirros --flavor demo --nic net-name=net1 \
    --security-groups "$sg01_id" | grep " id " | get_field 2)
sleep 30
get_vm_ipaddr "$vm01_id" > ./data/vm01-ipaddr

export OS_TENANT_NAME=proj02

# ---------- Create security group ----------
sg02_id=$(neutron security-group-create sg02 | grep " id " | get_field 2)
echo "$sg02_id" > ./data/proj02-sg-default-id
neutron security-group-rule-create --remote-group-id "$sg02_id" "$sg02_id"
neutron security-group-rule-create --direction ingress --remote-ip-prefix "$HOST_IP" "$sg02_id"

# ---------- Create VM ----------
vm02_id=$(nova boot vm02 --image cirros --flavor demo --nic net-name=net1 \
    --security-groups "$sg02_id" | grep " id " | get_field 2)
sleep 30
get_vm_ipaddr "$vm02_id" > ./data/vm02-ipaddr

