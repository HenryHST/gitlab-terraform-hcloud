#!/usr/bin/env bash
# Repair host where cloud-init bootstrap failed before Docker install (apt line concatenation bug).
# Run on the server as root, e.g. ssh root@git04 'bash -s' < scripts/repair-git04-docker-bootstrap.sh
set -euxo pipefail

if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    jq ufw fail2ban unattended-upgrades
  systemctl enable --now docker
fi

if id gadmin &>/dev/null; then
  usermod -aG docker gadmin || true
fi

cd /opt/gitlab
docker compose pull
docker compose up -d

echo "Docker bootstrap repair finished."
