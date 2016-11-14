#!/bin/bash

set -e
set -x

# Canal support has been merged to upstream
export KARGO_COMMIT="calico_mtu"
export KARGO_REPO="https://github.com/adidenko/kargo"

git clone https://github.com/adidenko/vagrant-k8s ~/mcp

cd ~/mcp
./bootstrap-master.sh

export INVENTORY=`pwd`/nodes_to_inv.py
export K8S_NODES_FILE=`pwd`/nodes

cat nodes
ansible all -m ping -i $INVENTORY

cat << EOF >> custom.yaml
calico_mtu: 1200
EOF

./deploy-k8s.kargo.sh &> /var/log/kargo.log
