#!/bin/bash

set -o xtrace
set -o nounset

readonly BASE_DIR=$(realpath "$(dirname "${BASH_SOURCE}[0]")")

etcdctl rm -r /calico/v1/policy/tier/k8s-openstack

kubectl delete deployment nginx01 --namespace=ns1
kubectl delete deployment nginx02 --namespace=ns2

kubectl delete namespace ns1
kubectl delete namespace ns2

#docker run -ti --rm \
#  --env-file=data/credentials \
#  -v $BASE_DIR:/demo -w /demo \
#  127.0.0.1:31500/ccp/nova-base \
#  /bin/bash ./stack/clean.sh

#rm -f \
#    data/proj01-id
#    data/proj02-id
#    data/sg01-id
#    data/sg02-id
#    data/vm01-ipaddr
#    data/vm02-ipaddr
#    data/sg1_to_ns1.json
#    data/sg2_to_ns2.json

