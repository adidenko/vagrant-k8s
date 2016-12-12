#!/bin/bash

set -xe

CUSTOM_YAML="${CUSTOM_YAML:-custom.yaml}"

INVENTORY="${INVENTORY:-nodes_to_inv.py}"

echo "Installing requirements on nodes..."
export ANSIBLE_LOG_PATH="/var/log/ansible_bootstrap.log"
ansible-playbook -i $INVENTORY playbooks/bootstrap-nodes.yaml

echo "Running deployment..."
export ANSIBLE_LOG_PATH="/var/log/kargo.log"
ansible-playbook -i $INVENTORY /root/kargo/cluster.yml -e @${CUSTOM_YAML}
deploy_res=$?

if [ "$deploy_res" -eq "0" ]; then
  echo "Setting up resolv.conf ..."
  export ANSIBLE_LOG_PATH="/var/log/ansible_resolv.log"
  ansible-playbook -i $INVENTORY playbooks/resolv_conf.yaml
fi
