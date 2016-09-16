#!/bin/bash

function type_str {
    local str="$@"
    for ((i=0; i<${#str}; i++)); do
        echo -n "${str:$i:1}" 1>&2
        sleep 0.05
    done
    echo 1>&2
}

function type_msg {
    echo -ne "\n\n" 1>&2
    for line in "$@"; do
        echo -n "### " 1>&2
        type_str "$line"
    done
}

function type_cmd {
    echo 1>&2
    echo -n "$ " 1>&2
    type_str "$@"
}

function run_cmd {
    type_cmd "$@"
    eval $@
}

type_msg "So we have a kubernetes cluster"
run_cmd kubectl get nodes

sleep 3

type_msg "And we have some pods running"
run_cmd kubectl --namespace=kube-system get pods -o wide

sleep 3

type_msg "Also we're running kubelet with CNI network-plugin"
run_cmd "ps afuxww | grep './hyperkube kubelet' | grep -v docker | grep --color cni"

sleep 3

type_msg "Here's the CNI config and plugins"
run_cmd cat /etc/cni/net.d/10-calico.conf
run_cmd ls -lA --color /opt/cni/bin/

sleep 3

type_msg "Checking calico status and IP pool"
run_cmd calicoctl status
run_cmd calicoctl pool show --ipv4

sleep 3

type_msg "So our pods with non host network got their IPs from Calico"
run_cmd "kubectl --namespace=kube-system get pods -o wide | grep --color 10.233."

IP=$(kubectl --namespace=kube-system get pods -o wide | grep 10.233. | grep node1 | awk '{print $6}')
run_cmd "grep --color $IP /var/log/calico/cni/cni.log"

sleep 3

type_msg "Bird handles PODs IP propagation (/26 subnets) via BGP protocol"
run_cmd "ip ro | grep 10.233 | grep via"

sleep 3

type_msg "Let's ping one of the pods hosted on the other node"
IP=$(kubectl --namespace=kube-system get pods -o wide | grep 10.233. | grep node2 | awk '{print $6}')
run_cmd "kubectl --namespace=kube-system get pods -o wide | grep 10.233. | grep --color node2"
sleep 1
run_cmd ip ro get $IP
sleep 1
run_cmd ping -c 3 $IP

sleep 2

type_msg "As we can see packets are simply routed to that POD via host node's IP"
echo
echo

sleep 5

