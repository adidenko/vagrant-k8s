#!/bin/bash
set -xe

git clone https://github.com/adidenko/vagrant-k8s ~/mcp

pushd ~/mcp
# Step 1
bash -x ./bootstrap-master.sh

export INVENTORY=`pwd`/nodes_to_inv.py
export K8S_NODES_FILE=`pwd`/nodes

# Test connectivity
cat nodes
ansible all -m ping -i $INVENTORY

# Deploy cluster
bash -x deploy-k8s.kargo.sh

popd
