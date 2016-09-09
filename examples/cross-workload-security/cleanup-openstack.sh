#!/bin/bash

set -o xtrace
set -o nounset

nova delete --all-tenants vm01
nova delete --all-tenants vm02

neutron security-group-delete allowhost01
neutron security-group-delete allowhost02

neutron security-group-delete $(<./data/proj01-sg-default-id)
neutron security-group-delete $(<./data/proj02-sg-default-id)

openstack project delete proj01
openstack project delete proj02

neutron net-delete net1



