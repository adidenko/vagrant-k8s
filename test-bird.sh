#!/bin/bash

set -e
set -x

INVENTORY="nodes_to_inv.py"

git clone https://github.com/adidenko/vagrant-k8s ~/mcp
cd ~/mcp
./bootstrap-master.sh

export INVENTORY=`pwd`/nodes_to_inv.py
export K8S_NODES_FILE=`pwd`/nodes

ansible all -m ping -i $INVENTORY

echo "Installing requirements on nodes..."
ansible-playbook -i $INVENTORY playbooks/bootstrap-nodes.yaml

echo "Running deployment..."
ansible-playbook -i $INVENTORY /root/kargo/cluster.yml -e @bird.ipip.yaml &> /tmp/log1

