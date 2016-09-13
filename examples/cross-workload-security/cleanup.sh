#!/bin/bash

set -o xtrace
set -o nounset

source ./cleanup-k8s.sh

sudo docker run -ti --rm \
    --env-file=credentials \
    -v $(pwd):/demo -w /demo\
    127.0.0.1:31500/ccp/nova-base \
    /bin/bash ./cleanup-stack.sh

