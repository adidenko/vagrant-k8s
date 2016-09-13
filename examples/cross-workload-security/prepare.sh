#!/bin/bash

set -o xtrace
set -o errexit
set -o nounset

source "./functions.sh"

mkdir -p ./data

sudo docker run -ti --rm \
    --env-file=credentials \
    -v $(pwd):/demo -w /demo\
    127.0.0.1:31500/ccp/nova-base \
    /bin/bash ./prepare-stack.sh

vm01_ipaddr=$(<./data/vm01-ipaddr)
vm02_ipaddr=$(<./data/vm02-ipaddr)

wait_ssh $vm01_ipaddr
wait_ssh $vm02_ipaddr
