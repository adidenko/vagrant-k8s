#!/bin/bash

set -o xtrace
set -o nounset

sudo calicoctl profile remove proj01-profile
sudo calicoctl profile remove proj02-profile

kubectl delete deployment nginx01
kubectl delete deployment nginx02

sudo docker run -ti --rm \
    --env-file=credentials \
    -v $(pwd):/demo -w /demo\
    127.0.0.1:31500/ccp/nova-base \
    /bin/bash ./cleanup-openstack.sh

