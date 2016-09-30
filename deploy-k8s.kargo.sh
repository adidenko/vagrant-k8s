#!/bin/bash

set -xe

CUSTOM="${1:-custom.yaml}"

INVENTORY="nodes_to_inv.py"

echo "Installing requirements on nodes..."
ansible-playbook -i $INVENTORY playbooks/bootstrap-nodes.yaml

echo "Running deployment..."
ansible-playbook -i $INVENTORY /root/kargo/cluster.yml -e @${CUSTOM}
deploy_res=$?

if [ "$deploy_res" -eq "0" ]; then
  echo "Setting up ip route work-around for DNS clusterIP availability..."
  ansible-playbook -i $INVENTORY playbooks/ipro_for_cluster_ips.yaml
fi
