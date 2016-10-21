#!/bin/bash

set -o xtrace
set -o nounset

OS_TENANT_NAME=proj01 nova delete vm01
OS_TENANT_NAME=proj02 nova delete vm02

neutron security-group-delete sg01
neutron security-group-delete sg02

openstack project delete proj01
openstack project delete proj02

neutron net-delete net1

