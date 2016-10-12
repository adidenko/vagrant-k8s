#!/bin/bash

set -o errexit
set -o nounset

readonly BASE_DIR=$(realpath "$(dirname "${BASH_SOURCE}[0]")")
readonly CREDENTIALS="./data/credentials"

# Debug mode
# DEMO_NO_TYPE=true

source "$(realpath "$BASE_DIR")/functions.sh"

msg "Starting docker container to use OpenStack CLI utilities."

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

msg "Creating two Kubernetes namespaces"

run kubectl create namespace ns1
run kubectl create namespace ns2

msg "Set default K8S namespace policy to DefaultDeny"

run kubectl annotate namespace ns1 \
    '"net.beta.kubernetes.io/network-policy={\"ingress\": {\"isolation\": \"DefaultDeny\"}}"'
run kubectl annotate namespace ns2 \
    '"net.beta.kubernetes.io/network-policy={\"ingress\": {\"isolation\": \"DefaultDeny\"}}"'

msg "Starting two Kubernetes pods with Nginx web server"

run kubectl run nginx01 --image=nginx --namespace=ns1
run kubectl run nginx02 --image=nginx --namespace=ns2

sleep 10

run 'kubectl get pods -o wide --all-namespaces 2>/dev/null | grep nginx'

pod01_ipaddr=$(kubectl get pods -o wide --namespace=ns1 2>/dev/null |
    grep nginx01 |tr -s ' ' | cut -d ' ' -f 6)
pod02_ipaddr=$(kubectl get pods -o wide --namespace=ns2 2>/dev/null |
    grep nginx02 |tr -s ' ' | cut -d ' ' -f 6)

export SSHPASS="cubswin:)"

msg "With k8s-policy extension K8S endpoints by default have" \
    " namespace specific security profiles with applied network policy" \
    " (for ns1 and ns2 it is 'DefaultDeny')."

# ---- Check connectivity ----------------------------------------------------

msg "VMs should not have network connectivity to K8S pods. Checking..."

run sshpass -e ssh cirros@$vm01_ipaddr ping -c 3 -W 3 $pod01_ipaddr || true
run sshpass -e ssh cirros@$vm02_ipaddr ping -c 3 -W 3 $pod02_ipaddr || true

# ----  Apply policies -------------------------------------------------------

msg "Creating tier 'k8s-openstack'"

run etcdctl mkdir /calico/v1/policy/tier/k8s-openstack/policy

run etcdctl set /calico/v1/policy/tier/k8s-openstack/metadata '"{\"order\": 900}"'

msg "Default policy shuould passthrough all packets to the next tier"

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

# ---- Check connectivity ----------------------------------------------------

msg "Now tenant 'sg01' should have access only to pod 'nginx01'."
msg "Checking connectivity between 'vm01' and 'nginx01'..."
run sshpass -e ssh cirros@$vm01_ipaddr ping -c 3 $pod01_ipaddr
msg "And there should be no connectivity between 'vm01' and 'nginx02'..."
run sshpass -e ssh cirros@$vm01_ipaddr ping -c 3 $pod02_ipaddr || true

msg "Same rules work for tenant 'sg02'."
msg "Checking connectivity between 'vm02' and 'nginx02'..."
run sshpass -e ssh cirros@$vm02_ipaddr ping -c 3 $pod02_ipaddr
msg "No connectivity between 'vm02' and 'nginx01'..."
run sshpass -e ssh cirros@$vm02_ipaddr ping -c 3 $pod01_ipaddr || true

