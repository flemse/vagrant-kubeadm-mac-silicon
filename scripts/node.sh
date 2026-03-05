#!/bin/bash
#
# Setup for Node servers

set -euxo pipefail

config_path="/vagrant/configs"

# Wait for controlplane to finish writing join.sh
echo "Waiting for join.sh from controlplane..."
timeout=180
until [ -f "$config_path/join.sh" ] && [ -s "$config_path/join.sh" ]; do
  timeout=$((timeout - 5))
  if [ $timeout -le 0 ]; then
    echo "ERROR: Timed out waiting for $config_path/join.sh"
    exit 1
  fi
  sleep 5
done

/bin/bash $config_path/join.sh -v

sudo -i -u vagrant bash << EOF

whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
NODENAME=$(hostname -s)

kubectl label node $(hostname -s) node-role.kubernetes.io/worker=worker

EOF