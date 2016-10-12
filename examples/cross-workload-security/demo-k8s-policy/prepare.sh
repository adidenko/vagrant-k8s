#!/bin/bash

set -o xtrace
set -o errexit
set -o nounset

readonly BASE_DIR=$(realpath "$(dirname "${BASH_SOURCE}[0]")")
readonly CREDENTIALS="./data/credentials"

source "$BASE_DIR/functions.sh"

docker run -ti --rm \
    --env-file=$CREDENTIALS \
    -v "$BASE_DIR:/demo" -w /demo \
    127.0.0.1:31500/ccp/nova-base \
    /bin/bash ./stack/prepare.sh

vm01_ipaddr=$(<./data/vm01-ipaddr)
vm02_ipaddr=$(<./data/vm02-ipaddr)

wait_ssh $vm01_ipaddr
wait_ssh $vm02_ipaddr
