#!/bin/bash

set -o errexit
set -o nounset

readonly BASE_DIR=$(realpath "$(dirname "${BASH_SOURCE}[0]")")
LONG=10
SHORT=5

source "$(realpath "$BASE_DIR")/functions.sh"

##############################################################################
# intro
print_hr

msg \
  "This is the demo of advanced BGP configuration for Calico networking" \
  "plugin for Kubernetes cluster. The main goal is to deploy Calico route" \
  "reflectors, disable full node-to-node mesh in Calico and peer all k8s" \
  "worker nodes via route reflectors." \
  "" \
  "This will allow us to greatly reduce number of BGP sessions in the cluster" \
  "and speed up calico-node container start/restart on a large scale." \
  "" \
  "Plese see the following link for details:" \
  "https://github.com/kubernetes-incubator/kargo/blob/master/docs/calico.md#optional--bgp-peering-with-route-reflectors"
print_hr
##############################################################################
# show deployment info
echo
msg "This cluster is deployed with Kargo, here's the inventory that was used:"
run cat /root/kargo/inventory/inventory.cfg
sleep $LONG

echo
msg \
  "So according to our inventory we should have two route reflectors: r1 and r2" \
  "And 3 k8s nodes: node3, node4, node5 which should be peered with r1 and r2"

echo
msg "Let's check kargo logs and see tasks related to BGP configuration"
echo
run "grep 'Calico | Configure peering with route reflectors' /var/log/kargo.log -A6"
echo
run "grep 'Calico | Disable node mesh' /var/log/kargo.log -A1"
echo
run "grep Calico-rr /var/log/kargo.log"
sleep $LONG

echo
msg "The list of kubernetes nodes"
run ssh node3 kubectl get nodes -o wide

##############################################################################
# route reflectors
echo
msg "Now let's check route reflector service on rr1"
run ssh rr1 docker ps
run ssh rr1 docker exec calico-rr birdc -s /etc/service/bird/bird.ctl sh pro
run ssh rr1 docker exec calico-rr birdc -s /etc/service/bird/bird.ctl sh ro
sleep $SHORT

echo
msg "And on rr2"
run ssh rr2 docker ps
run ssh rr2 docker exec calico-rr birdc -s /etc/service/bird/bird.ctl sh pro
run ssh rr2 docker exec calico-rr birdc -s /etc/service/bird/bird.ctl sh ro
sleep $SHORT
echo
msg \
  "As we can see both route reflectors are peered with each other" \
  "and with every k8s node"

sleep $SHORT
##############################################################################
# calico info
print_hr
echo
msg "Now let's check from the calico-node (k8w worker node) side"

echo
msg "Get AS number"
run ssh node3 calicoctl config get asNumber

echo
msg "List of Calico BGP peers"
run ssh node3 calicoctl get bgpPeers

msg "Let's check BGP peer info on every node"
run ssh node3 docker exec calico-node birdcl -s /var/run/calico/bird.ctl sh pro
run ssh node4 docker exec calico-node birdcl -s /var/run/calico/bird.ctl sh pro
run ssh node5 docker exec calico-node birdcl -s /var/run/calico/bird.ctl sh pro
sleep $SHORT

echo
msg "Now let's check routing tables on k8s worker nodes"
echo
run "ssh node3 ip ro | grep /26"
echo
run "ssh node4 ip ro | grep /26"
echo
run "ssh node5 ip ro | grep /26"

msg "And test connectivity to non local PODs"
run ssh node3 kubectl get pods -o wide
echo
ping_pods

sleep $SHORT

##############################################################################
echo
print_hr
msg \
  "As we can see each calico-node is peered with both calico route reflectors" \
  "and not directly with each other. So even if we had 1000 k8s worker nodes" \
  "each of them would have only 2 BGP sessions (assuming we have 2 'calico-rr'" \
  "nodes in kargo inventory) instead of 999."
echo
msg "Thank you for watching!"
sleep $LONG
