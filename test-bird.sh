#!/bin/bash

set -e
set -x

INVENTORY="nodes_to_inv.py"

./bootstrap-master.sh

export INVENTORY=`pwd`/nodes_to_inv.py
export K8S_NODES_FILE=`pwd`/nodes

ansible all -m ping -i $INVENTORY

echo "Installing requirements on nodes..."
ansible-playbook -i $INVENTORY playbooks/bootstrap-nodes.yaml

echo "Running deployment..."
ansible-playbook -i $INVENTORY /root/kargo/cluster.yml -e @bird.ipip.yaml &> /tmp/log1

sleep 10

echo "Running tests"
ansible-playbook -i $INVENTORY playbooks/tests.yaml -e @bird.ipip.yaml

