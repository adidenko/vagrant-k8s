#!/bin/bash
echo master > /var/tmp/role

# SSH keys and config
sudo rm -rf /root/.ssh
sudo mv ~vagrant/ssh /root/.ssh
sudo echo -e 'Host 10.*\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile=/dev/null' >> /root/.ssh/config
sudo chown -R root: /root/.ssh

