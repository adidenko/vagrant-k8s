#!/bin/bash

KARGO_COMMIT="${KARGO_COMMIT:-9ea9604b3f7c08c24b93af5220dfd56da39de8b3}"
KARGO_REPO="${KARGO_REPO:-https://github.com/kubernetes-incubator/kargo}"

# Packages
apt-get --yes update
apt-get --yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install git screen vim telnet tcpdump python-setuptools gcc python-dev python-pip libssl-dev libffi-dev software-properties-common curl python-netaddr

# Get ansible-2.1+, vanilla ubuntu-16.04 ansible (2.0.0.2) is broken due to https://github.com/ansible/ansible/issues/13876
ansible --version || (
  apt-add-repository -y ppa:ansible/ansible
  apt-get update
  apt-get install -y ansible
)

# Copy/create nodes list
test -f ./nodes || cp /var/tmp/nodes ./nodes
test -f ./nodes && echo 'for i in `cat nodes`; do screen -t $i ssh $i; done' > ./screen.sh

# Either pull or copy microservices repos
cp -a /var/tmp/microservices* ./ccp/ || touch /var/tmp/ccp-download

# Pull kargo
git clone $KARGO_REPO ~/kargo
cd ~/kargo

# Checkout to kargo commit
if [ -n "$KARGO_COMMIT" ] ; then
  git checkout $KARGO_COMMIT
fi
