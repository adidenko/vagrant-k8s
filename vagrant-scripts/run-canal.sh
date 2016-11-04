#!/bin/bash

set -e
set -x

export KARGO_COMMIT="canal-support"
export KARGO_REPO="https://github.com/adidenko/kargo"

git clone https://github.com/adidenko/vagrant-k8s ~/mcp

cd ~/mcp
./bootstrap-master.sh

export INVENTORY=`pwd`/nodes_to_inv.py
export K8S_NODES_FILE=`pwd`/nodes

cat nodes
ansible all -m ping -i $INVENTORY

sed -e "/^kube_network_plugin:/d" -i custom.yaml
cat << EOF >> custom.yaml
kube_network_plugin: canal
canal_iface: "eth2"
EOF

./deploy-k8s.kargo.sh &> /var/log/kargo.log
