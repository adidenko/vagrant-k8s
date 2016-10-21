#!/bin/bash

set -o errexit
set -o nounset

source "./functions.sh"


type_msg "Starting docker container to use OpenStack CLI utilities."

run_cmd cat ./credentials
run_cmd sudo docker run -ti --rm \
    --env-file=credentials \
    -v $(pwd):/demo -w /demo\
    127.0.0.1:31500/ccp/nova-base \
    /bin/bash ./demo-stack.sh

vm01_ipaddr=$(<./data/vm01-ipaddr)
vm02_ipaddr=$(<./data/vm02-ipaddr)

sg01_id=$(<./data/proj01-sg-default-id)
sg02_id=$(<./data/proj02-sg-default-id)

type_msg "Starting two Kubernetes pods with Nginx web server"

run_cmd kubectl run nginx01 --image nginx
run_cmd kubectl run nginx02 --image nginx

sleep 10

run_cmd "kubectl get pods -o wide | grep nginx"

pod01_ipaddr=$(sudo kubectl get pods -o wide |grep nginx01 |tr -s ' ' | cut -d ' ' -f 6)
pod02_ipaddr=$(sudo kubectl get pods -o wide |grep nginx02 |tr -s ' ' | cut -d ' ' -f 6)

pod01_endpoint=$(get_calico_endpoint "nginx01")
pod02_endpoint=$(get_calico_endpoint "nginx02")

export SSHPASS="cubswin:)"

type_msg "K8S endpoints have default security profile 'calico-k8s-network'" \
         "which allows all inbound and outbound traffic."

run_cmd "sudo calicoctl endpoint show --detailed | grep nginx"
run_cmd sudo calicoctl endpoint $pod01_endpoint profile show

type_msg "VM 'vm01' should have network connectivity to K8S pods. Checking..."

run_cmd sshpass -e ssh cirros@$vm01_ipaddr ping -c 3 $pod01_ipaddr
run_cmd sshpass -e ssh cirros@$vm01_ipaddr ping -c 3 $pod02_ipaddr

type_msg "VM 'vm01' does not have connectivity to 'vm02' since access outside tenant is prohibited."

run_cmd sshpass -e ssh cirros@$vm01_ipaddr ping -c 3 $vm02_ipaddr || true

type_msg "To limit connectivity between tenant 'sg01' and pod 'nginx01'" \
         "first the default profile should be removed from pods endpoints."

run_cmd sudo calicoctl endpoint $pod01_endpoint profile remove calico-k8s-network
run_cmd sudo calicoctl endpoint $pod02_endpoint profile remove calico-k8s-network

type_msg "Creating new calico security profiles to perform isolation between " \
    "OpenStack tenant and K8S pods."

run_cmd sudo calicoctl profile add proj01-profile
run_cmd sudo calicoctl profile proj01-profile tag add "$sg01_id"

type_msg "New profile will share the same tag '$sg01_id' with openstack's security group profile"
run_cmd sudo calicoctl profile proj01-profile rule add inbound allow from tag "$sg01_id"

type_msg "Adding created profile to 'nginx01' endpoint..."
run_cmd sudo calicoctl endpoint $pod01_endpoint profile append proj01-profile


type_msg "Configuring security profile for second pod..."
run_cmd sudo calicoctl profile add proj02-profile
run_cmd sudo calicoctl profile proj02-profile tag add "$sg02_id"
run_cmd sudo calicoctl profile proj02-profile rule add inbound allow from tag "$sg02_id"
run_cmd sudo calicoctl endpoint $pod02_endpoint profile append proj02-profile

type_msg "Now tenant 'sg01' should have access only to pod 'nginx01'."
type_msg "Checking connectivity between 'vm01' and 'nginx01'..."
run_cmd sshpass -e ssh cirros@$vm01_ipaddr ping -c 3 $pod01_ipaddr
type_msg "And there should be no connectivity between 'vm01' and 'nginx02'..."
run_cmd sshpass -e ssh cirros@$vm01_ipaddr ping -c 3 $pod02_ipaddr || true

type_msg "Same rules work for tenant 'sg02'."
type_msg "Checking connectivity between 'vm02' and 'nginx02'..."
run_cmd sshpass -e ssh cirros@$vm02_ipaddr ping -c 3 $pod02_ipaddr
type_msg "No connectivity between 'vm02' and 'nginx01'..."
run_cmd sshpass -e ssh cirros@$vm02_ipaddr ping -c 3 $pod01_ipaddr || true

type_msg "Calico profiles with assigned security group ID tag allow to implement" \
         "cross workload security between OpenStack and Kubernetes."

