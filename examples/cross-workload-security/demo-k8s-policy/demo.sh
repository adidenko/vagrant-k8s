#!/bin/bash

set -o errexit
set -o nounset

readonly BASE_DIR=$(realpath "$(dirname "${BASH_SOURCE}[0]")")
readonly CREDENTIALS="./data/credentials"

export SSHPASS="cubswin:)"

source "$(realpath "$BASE_DIR")/functions.sh"

# =============================================================================
# Introduction
# =============================================================================

print_hr

msg \
    "This is the demo of cross workload security in OpenStack and Kubernetes" \
    "environment. We are running Kubernetes with Calico and OpenStack" \
    "Containerized Control Plane (fuel-ccp) on top of it with" \
    "neutron + networking-calico ML2 plugin."

print_hr
msg "Additional configuration is done:" \
    "  - Kubernetes extension 'networkpolicies' is enabled."

run 'cat /etc/kubernetes/manifests/kube-apiserver.manifest |grep runtime-config'

msg "  - CNI plugin configured to work with k8s policies."

run cat /etc/cni/net.d/10-calico.conf

msg "  - Calico's policy controller (k8s-policy) pod is running, please see:" \
    "    https://git.io/vPXZz"

print_hr
sleep 4

run kubectl get nodes
sleep 4
run kubectl get pods -o wide --namespace=kube-system
sleep 8
run kubectl get pods -o wide --namespace=ccp
sleep 8

run cat ./data/credentials
run docker run -ti --rm \
    --env-file=./data/credentials \
    -v "$BASE_DIR":/demo -w /demo \
    127.0.0.1:31500/ccp/nova-base \
    /bin/bash ./stack/demo.sh

vm01_ipaddr=$(<./data/vm01-ipaddr)
vm02_ipaddr=$(<./data/vm02-ipaddr)

sg01_id=$(<./data/sg01-id)
sg02_id=$(<./data/sg02-id)

# =============================================================================
# Creating environment
# =============================================================================

msg "Creating two Kubernetes namespaces"

run kubectl create namespace ns1
run kubectl create namespace ns2

msg "With configured network policies in K8S and Calico, endpoints for " \
    "K8S PODs are created with namespace specific security profile" \
    "(e.g. k8s_ns.<namespace>). Default namespace isolation policy" \
    "can be configured by using namespace annotation." \
    "" \
    "We are setting default K8S namespace policy to 'DefaultDeny'."

run kubectl annotate namespace ns1 \
    '"net.beta.kubernetes.io/network-policy={\"ingress\": {\"isolation\": \"DefaultDeny\"}}"'
run kubectl annotate namespace ns2 \
    '"net.beta.kubernetes.io/network-policy={\"ingress\": {\"isolation\": \"DefaultDeny\"}}"'

msg "Starting two Kubernetes pods with Nginx web server"

run kubectl run nginx01 --image=nginx --namespace=ns1
run kubectl run nginx02 --image=nginx --namespace=ns2

sleep 10

run 'kubectl get pods -o wide --all-namespaces 2>/dev/null | grep nginx'

pod01_name=$(kubectl get pods -o wide --namespace=ns1 2>/dev/null |
    grep nginx01 | tr -s ' ' | cut -d ' ' -f 1)
pod02_name=$(kubectl get pods -o wide --namespace=ns1 2>/dev/null |
    grep nginx02 | tr -s ' ' | cut -d ' ' -f 1)
pod01_ipaddr=$(kubectl get pods -o wide --namespace=ns1 2>/dev/null |
    grep nginx01 | tr -s ' ' | cut -d ' ' -f 6)
pod02_ipaddr=$(kubectl get pods -o wide --namespace=ns2 2>/dev/null |
    grep nginx02 | tr -s ' ' | cut -d ' ' -f 6)

# =============================================================================
# First connectivity check
# =============================================================================

msg "Since we set default isolation policty to 'DefaultDeny', K8S pods" \
    "in namespaces 'ns1' and 'ns2' should not have network connectivity'" \
    "whithin namespace or between namespaces."

run kubectl --namespace=ns1 \
    exec $pod01_name -- ping -c 3 -W 3 $pod02_ipaddr || true

msg "VMs also should not have network connectivity to K8S pods. Checking..."

run sshpass -e ssh cirros@$vm01_ipaddr ping -c 3 -W 3 $pod01_ipaddr || true
run sshpass -e ssh cirros@$vm02_ipaddr ping -c 3 -W 3 $pod02_ipaddr || true

# =============================================================================
# Applying policies
# =============================================================================

msg "Calico provides flexible mechanisms for network policy configuration." \
    "In addition to directly-referenced security profiles, Calico supports" \
    "security model called 'tiered policy'." \
    "" \
    "We are using tiered policies to configure policies between OpenStack" \
    "security groups and K8S namespaces." \
    "" \
    "First we are creating tier named 'k8s-openstack':"

run etcdctl mkdir /calico/v1/policy/tier/k8s-openstack/policy

run etcdctl set /calico/v1/policy/tier/k8s-openstack/metadata '"{\"order\": 900}"'

msg "Default policy should passthrough all packets to the next tier"

run etcdctl set /calico/v1/policy/tier/k8s-openstack/policy/no-match \
    '"$(< data/policy-no-match.json)"'

msg "Creating policies that allow connectivity between Kubernetes namespaces" \
    " and OpenStack security groups"

# Render sg1_to_ns1 policy
K8S_NAMESPACE=ns1 SECGROUP_ID=$sg01_id \
    render_template data/policy.json.template > data/sg1_to_ns1.json

run etcdctl set /calico/v1/policy/tier/k8s-openstack/policy/sg1_ns1 \
    '"$(< data/sg1_to_ns1.json)"'

# Render sg2_to_ns2 policy
K8S_NAMESPACE=ns2 SECGROUP_ID=$sg02_id \
    render_template data/policy.json.template > data/sg2_to_ns2.json

run etcdctl set /calico/v1/policy/tier/k8s-openstack/policy/sg2_ns2 \
    '"$(< data/sg2_to_ns2.json)"'

sleep 10

# =============================================================================
# Second connectivity check
# =============================================================================

msg "Now VMs with security group 'sg01' should have access" \
    "to PODs in namespace 'ns1'." \
    "Checking connectivity between 'vm01' and 'nginx01' ..."
run sshpass -e ssh cirros@$vm01_ipaddr ping -c 3 $pod01_ipaddr
msg "There should be no connectivity between 'vm01' and 'nginx02' ..."
run sshpass -e ssh cirros@$vm01_ipaddr ping -c 3 $pod02_ipaddr || true

msg "Similar rules apply for VMs with security group 'sg02' and PODs" \
    "in namespace 'ns2'." \
    "Checking connectivity between 'vm02' and 'nginx02'..."
run sshpass -e ssh cirros@$vm02_ipaddr ping -c 3 $pod02_ipaddr
msg "No connectivity between 'vm02' and 'nginx01'..."
run sshpass -e ssh cirros@$vm02_ipaddr ping -c 3 $pod01_ipaddr || true

# =============================================================================
# Create more PODs
# =============================================================================

msg "Now let's create one more POD in namespace 'ns2' to show that rules" \
    "rules apply on the namespace level."
run kubectl run nginx03 --image=nginx --namespace=ns2

sleep 5

run kubectl get pods -o wide --namespace=ns2 |grep nginx03
pod03_ipaddr=$(kubectl get pods -o wide --namespace=ns2 2>/dev/null |
    grep nginx03 |tr -s ' ' | cut -d ' ' -f 6)

# =============================================================================
# Third connectivity check
# =============================================================================

msg "Checking connectivity between 'vm02' and 'nginx03'..."
run sshpass -e ssh cirros@$vm02_ipaddr ping -c 3 $pod03_ipaddr
msg "No connectivity between 'vm01' and 'nginx03'..."
run sshpass -e ssh cirros@$vm01_ipaddr ping -c 3 $pod03_ipaddr || true

print_hr
DEMO_NO_TYPE=true msg                                               \
    "That's it. Thank you for watching."                            \
    ""                                                              \
    "Proof of concept by:"                                          \
    "  - Alexander Didenko <adidenko@mirantis.com>"                 \
    "  - Alexander Saprykin <asaprykin@mirantis.com>"               \
    ""                                                              \
    "Big thanks to:"                                                \
    "  - Neil Jerram <neil@tigera.io>"                              \
    ""                                                              \
    "Slack:"                                                        \
    "  - https://slack.projectcalico.org/"                          \
    ""                                                              \
    "Scripts to reproduce the PoC:"                                 \
    "  - https://github.com/adidenko/vagrant-k8s"                   \
    ""                                                              \
    "References:"                                                   \
    "  - http://docs.projectcalico.org/"                            \
    "  - https://github.com/projectcalico/k8s-policy"               \
    "  - http://fuel-ccp.readthedocs.io/en/latest/"                 \
    "  - http://fuel-ccp-installer.readthedocs.io/en/latest/"
