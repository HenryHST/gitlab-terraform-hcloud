#!/usr/bin/env bash
# Runs inside the LXC container. Installs Docker and deploys GitLab Compose stack.
# Sync with terraform/templates/gitlab-docker-cloud-init.yaml.tpl (core stack).
set -euo pipefail

ENV_FILE="${ENV_FILE:-/root/pve-gitlab.env}"
LOG=/var/log/gitlab-docker-bootstrap.log
exec >>"$LOG" 2>&1
echo "=== gitlab-docker bootstrap $(date -Is) ==="

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "ERROR: missing ${ENV_FILE}" >&2
    exit 1
fi
# shellcheck source=/dev/null
source "${ENV_FILE}"

TEMPLATES_DIR="${TEMPLATES_DIR:-/root/gitlab-docker-core}"

render_template() {
    local src="$1" dest="$2" mode="${3:-644}"
    local dir
    dir="$(dirname "${dest}")"
    install -d -m 0755 "${dir}"
    export GITLAB_FQDN EXTERNAL_URL_SCHEME GITLAB_URL TRAEFIK_IMAGE GITLAB_CE_IMAGE POSTGRES_IMAGE
    export HETZNER_API_TOKEN ACME_EMAIL GITLAB_ROOT_EMAIL GITLAB_ROOT_PASSWORD POSTGRES_PASSWORD
    export GITLAB_SIGNUP_ENABLED GITLAB_THEME_ID GITLAB_COLOR_MODE GITLAB_TIME_ZONE ACME_GITLAB_RB_BLOCK
    export DNS_DOMAIN TRAEFIK_MANAGER_IMAGE TRAEFIK_MANAGER_PASSWORD TRAEFIK_MANAGER_CERT_RESOLVER
    envsubst '${GITLAB_FQDN} ${EXTERNAL_URL_SCHEME} ${GITLAB_URL} ${TRAEFIK_IMAGE} ${GITLAB_CE_IMAGE} ${POSTGRES_IMAGE} ${HETZNER_API_TOKEN} ${ACME_EMAIL} ${GITLAB_ROOT_EMAIL} ${GITLAB_ROOT_PASSWORD} ${POSTGRES_PASSWORD} ${GITLAB_SIGNUP_ENABLED} ${GITLAB_THEME_ID} ${GITLAB_COLOR_MODE} ${GITLAB_TIME_ZONE} ${ACME_GITLAB_RB_BLOCK} ${DNS_DOMAIN} ${TRAEFIK_MANAGER_IMAGE} ${TRAEFIK_MANAGER_PASSWORD} ${TRAEFIK_MANAGER_CERT_RESOLVER}' \
        <"${src}" >"${dest}"
    chmod "${mode}" "${dest}"
}

if [[ "${TRAEFIK_ACME_ENABLED}" == "true" ]]; then
    ACME_GITLAB_RB_BLOCK="letsencrypt['enable'] = false
nginx['redirect_http_to_https'] = false
gitlab_rails['trusted_proxies'] = ['127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '172.31.0.0/16']"
    COMPOSE_SRC="${TEMPLATES_DIR}/docker-compose.acme.yml"
    TRAEFIK_SRC="${TEMPLATES_DIR}/traefik/traefik.acme.yml"
    TRAEFIK_MANAGER_CERT_RESOLVER="${TRAEFIK_MANAGER_CERT_RESOLVER:-hetzner}"
else
    ACME_GITLAB_RB_BLOCK=""
    COMPOSE_SRC="${TEMPLATES_DIR}/docker-compose.http.yml"
    TRAEFIK_SRC="${TEMPLATES_DIR}/traefik/traefik.http.yml"
    TRAEFIK_MANAGER_CERT_RESOLVER="${TRAEFIK_MANAGER_CERT_RESOLVER:-none}"
fi

if [[ "${TRAEFIK_MANAGER_ENABLED:-true}" == "true" ]]; then
    TRAEFIK_MANAGER_ENABLED=true
    COMPOSE_PROFILES=(--profile traefik-manager)
else
    TRAEFIK_MANAGER_ENABLED=false
    COMPOSE_PROFILES=()
fi

# Normalize signup for gitlab.rb (Ruby true/false)
if [[ "${GITLAB_SIGNUP_ENABLED}" == "true" || "${GITLAB_SIGNUP_ENABLED}" == "1" ]]; then
    GITLAB_SIGNUP_ENABLED="true"
else
    GITLAB_SIGNUP_ENABLED="false"
fi

echo "=== apt update / upgrade ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

HOST_APT_EXTRA=""
if [[ "${HOST_HARDENING_ENABLED}" == "true" ]]; then
    HOST_APT_EXTRA="jq ufw fail2ban unattended-upgrades"
fi

echo "=== install prerequisites (curl, gpg, envsubst) ==="
apt-get install -y -qq ca-certificates curl gnupg gettext-base

echo "=== install docker ==="
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
# shellcheck disable=SC1091
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
    >/etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    zsh zsh-autosuggestions zsh-syntax-highlighting \
    openssh-server sudo ${HOST_APT_EXTRA}

if grep -q '^SHELL=' /etc/default/useradd; then
    sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' /etc/default/useradd
else
    echo 'SHELL=/usr/bin/zsh' >>/etc/default/useradd
fi
usermod -s /usr/bin/zsh root
systemctl enable --now docker

install -d -m 0755 /etc/zsh/zshrc.d
install -m 0644 "${TEMPLATES_DIR}/etc/zsh/zshrc.d/99-gitlab-docker-host.zsh" \
    /etc/zsh/zshrc.d/99-gitlab-docker-host.zsh

if [[ "${GITLAB_ADMIN_ENABLED}" == "true" && -n "${SSH_PUBLIC_KEY_EFFECTIVE:-}" ]]; then
  if ! id "${GITLAB_ADMIN_USERNAME}" &>/dev/null; then
    useradd -m -s /usr/bin/zsh -G sudo,docker "${GITLAB_ADMIN_USERNAME}"
    install -d -m 700 -o "${GITLAB_ADMIN_USERNAME}" -g "${GITLAB_ADMIN_USERNAME}" \
        "/home/${GITLAB_ADMIN_USERNAME}/.ssh"
    printf '%s\n' "${SSH_PUBLIC_KEY_EFFECTIVE}" \
        >"/home/${GITLAB_ADMIN_USERNAME}/.ssh/authorized_keys"
    chown "${GITLAB_ADMIN_USERNAME}:${GITLAB_ADMIN_USERNAME}" \
        "/home/${GITLAB_ADMIN_USERNAME}/.ssh/authorized_keys"
    chmod 600 "/home/${GITLAB_ADMIN_USERNAME}/.ssh/authorized_keys"
    echo "${GITLAB_ADMIN_USERNAME} ALL=(ALL) NOPASSWD:ALL" \
        >/etc/sudoers.d/"${GITLAB_ADMIN_USERNAME}"
    chmod 440 /etc/sudoers.d/"${GITLAB_ADMIN_USERNAME}"
  fi
  usermod -aG docker "${GITLAB_ADMIN_USERNAME}" || true
fi

if [[ -n "${SSH_PUBLIC_KEY_EFFECTIVE:-}" ]]; then
    install -d -m 700 /root/.ssh
    printf '%s\n' "${SSH_PUBLIC_KEY_EFFECTIVE}" >/root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
fi

if [[ "${HOST_HARDENING_ENABLED}" == "true" ]]; then
    cat >/etc/ssh/sshd_config.d/99-gitlab-docker.conf <<'SSHD'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
PermitRootLogin prohibit-password
SSHD
    if [[ "${GITLAB_ADMIN_ENABLED}" == "true" ]]; then
        echo "AllowUsers root ${GITLAB_ADMIN_USERNAME}" >>/etc/ssh/sshd_config.d/99-gitlab-docker.conf
    else
        echo "AllowUsers root" >>/etc/ssh/sshd_config.d/99-gitlab-docker.conf
    fi

    cat >/etc/sysctl.d/99-gitlab-docker-host.conf <<'SYSCTL'
# LXC-safe sysctl (no kernel.* — blocked in unprivileged containers)
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
SYSCTL
    sysctl -p /etc/sysctl.d/99-gitlab-docker-host.conf 2>/dev/null || true

    cat >/etc/fail2ban/jail.local <<'F2B'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
banaction = ufw

[sshd]
enabled = true
port    = ssh
backend = systemd

[recidive]
enabled  = true
logpath  = /var/log/fail2ban.log
banaction = ufw
bantime  = 1w
findtime = 1d
maxretry = 5
F2B

    if [[ "${HOST_HARDENING_UNATTENDED_UPGRADES}" == "true" ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        cat >/etc/apt/apt.conf.d/20auto-upgrades <<'AU'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
AU
        cat >/etc/apt/apt.conf.d/50unattended-upgrades <<UU
Unattended-Upgrade::Allowed-Origins {
    "${ID}:${VERSION_CODENAME}-security";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
UU
    fi

    sshd -t
    systemctl reload ssh || systemctl restart ssh
    sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
    ufw default deny incoming
    ufw default allow outgoing
    if [[ -n "${UFW_SSH_SOURCE_IPS:-}" ]]; then
        for ip in ${UFW_SSH_SOURCE_IPS}; do
            ufw allow from "${ip}" to any port 22 proto tcp
            ufw allow from "${ip}" to any port 2424 proto tcp
            if [[ "${TRAEFIK_MANAGER_ENABLED}" == "true" ]]; then
                ufw allow from "${ip}" to any port 5000 proto tcp
            fi
        done
    else
        ufw allow 22/tcp
        ufw allow 2424/tcp
        if [[ "${TRAEFIK_MANAGER_ENABLED}" == "true" ]]; then
            ufw allow 5000/tcp
        fi
    fi
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow in proto icmp || true
    ufw --force enable
    systemctl enable --now fail2ban
    if [[ "${HOST_HARDENING_UNATTENDED_UPGRADES}" == "true" ]]; then
        systemctl enable --now unattended-upgrades || true
    fi
fi

echo "=== write /opt/gitlab stack ==="
install -m 0700 -d /opt/gitlab/traefik/certs
touch /opt/gitlab/traefik/certs/.gitkeep
install -m 0700 -d /opt/gitlab/postgres/data
chown 999:999 /opt/gitlab/postgres/data
install -m 0755 -d /opt/gitlab/data/config /opt/gitlab/data/logs /opt/gitlab/data/gitlab
install -m 0755 -d /var/log/traefik
touch /var/log/traefik/access.log
chmod 0644 /var/log/traefik/access.log

if [[ "${TRAEFIK_MANAGER_ENABLED}" == "true" ]]; then
    install -m 0700 -d /opt/gitlab/traefik-manager/config /opt/gitlab/traefik-manager/backups
fi

install -d -m 0755 /opt/gitlab/traefik/dynamic_conf
cp -a "${TEMPLATES_DIR}/traefik/dynamic_conf/." /opt/gitlab/traefik/dynamic_conf/

render_template "${TRAEFIK_SRC}" /opt/gitlab/traefik/traefik.yml 0644
render_template "${TEMPLATES_DIR}/traefik/.env.tpl" /opt/gitlab/traefik/.env 0600
render_template "${COMPOSE_SRC}" /opt/gitlab/docker-compose.yml 0644
render_template "${TEMPLATES_DIR}/data/config/gitlab.rb.tpl" /opt/gitlab/data/config/gitlab.rb 0600

echo "=== docker compose up ==="
cd /opt/gitlab
docker compose "${COMPOSE_PROFILES[@]}" pull
docker compose "${COMPOSE_PROFILES[@]}" up -d

echo "=== finished $(date -Is) ==="
