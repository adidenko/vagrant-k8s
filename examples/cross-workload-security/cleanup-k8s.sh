#!/bin/bash

set -o xtrace
set -o nounset

kubectl delete deployment nginx01
kubectl delete deployment nginx02

sudo calicoctl profile remove proj01-profile
sudo calicoctl profile remove proj02-profile
