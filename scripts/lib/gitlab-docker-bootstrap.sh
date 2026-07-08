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
    export HETZNER_API_TOKEN ACME_EMAIL GITLAB_ROOT_EMAIL GITLAB_ROOT_PASSWORD POSTGRES_PASSWORD DB_HOST
    export GITLAB_SIGNUP_ENABLED GITLAB_THEME_ID GITLAB_COLOR_MODE GITLAB_TIME_ZONE ACME_GITLAB_RB_BLOCK
    export DNS_DOMAIN TRAEFIK_MANAGER_IMAGE TRAEFIK_MANAGER_PASSWORD TRAEFIK_MANAGER_SECRET_KEY TRAEFIK_MANAGER_CERT_RESOLVER
    export COMPOSE_PGBOUNCER_BLOCK COMPOSE_GITLAB_OPTIONAL_VOLUME_BLOCK COMPOSE_GITLAB_PGBOUNCER_DEPENDENCY_BLOCK
    export COMPOSE_GITLAB_REGISTRY_LABEL_BLOCK COMPOSE_GITLAB_PAGES_LABEL_BLOCK COMPOSE_PLANTUML_BLOCK
    export COMPOSE_RUNNER_BLOCK COMPOSE_RENOVATE_BLOCK COMPOSE_ACME_JSON_PATH_BLOCK
    export GITLAB_RB_PAGES_BLOCK GITLAB_RB_REGISTRY_BLOCK GITLAB_RB_ARTIFACTS_BLOCK GITLAB_RB_TERRAFORM_BLOCK GITLAB_RB_PLANTUML_BLOCK
    envsubst '${GITLAB_FQDN} ${EXTERNAL_URL_SCHEME} ${GITLAB_URL} ${TRAEFIK_IMAGE} ${GITLAB_CE_IMAGE} ${POSTGRES_IMAGE} ${HETZNER_API_TOKEN} ${ACME_EMAIL} ${GITLAB_ROOT_EMAIL} ${GITLAB_ROOT_PASSWORD} ${POSTGRES_PASSWORD} ${DB_HOST} ${GITLAB_SIGNUP_ENABLED} ${GITLAB_THEME_ID} ${GITLAB_COLOR_MODE} ${GITLAB_TIME_ZONE} ${ACME_GITLAB_RB_BLOCK} ${DNS_DOMAIN} ${TRAEFIK_MANAGER_IMAGE} ${TRAEFIK_MANAGER_PASSWORD} ${TRAEFIK_MANAGER_SECRET_KEY} ${TRAEFIK_MANAGER_CERT_RESOLVER} ${COMPOSE_PGBOUNCER_BLOCK} ${COMPOSE_GITLAB_OPTIONAL_VOLUME_BLOCK} ${COMPOSE_GITLAB_PGBOUNCER_DEPENDENCY_BLOCK} ${COMPOSE_GITLAB_REGISTRY_LABEL_BLOCK} ${COMPOSE_GITLAB_PAGES_LABEL_BLOCK} ${COMPOSE_PLANTUML_BLOCK} ${COMPOSE_RUNNER_BLOCK} ${COMPOSE_RENOVATE_BLOCK} ${COMPOSE_ACME_JSON_PATH_BLOCK} ${GITLAB_RB_PAGES_BLOCK} ${GITLAB_RB_REGISTRY_BLOCK} ${GITLAB_RB_ARTIFACTS_BLOCK} ${GITLAB_RB_TERRAFORM_BLOCK} ${GITLAB_RB_PLANTUML_BLOCK} ${REGISTRY_FQDN} ${PAGES_FQDN} ${ARTIFACTS_PATH} ${GITLAB_TERRAFORM_STATE_PATH} ${GITLAB_TERRAFORM_STATE_FILE} ${PLANTUML_URL} ${PGBOUNCER_IMAGE} ${PGBOUNCER_POOL_MODE} ${PGBOUNCER_MAX_CLIENT_CONN} ${PGBOUNCER_DEFAULT_POOL_SIZE} ${PLANTUML_IMAGE} ${RUNNER_IMAGE} ${RUNNER_DESCRIPTION} ${RUNNER_EXECUTOR} ${RUNNER_DEFAULT_IMAGE} ${RUNNER_PRIVILEGED} ${RUNNER_CONCURRENT} ${RUNNER_TAG_LIST} ${RUNNER_TOKEN} ${RENOVATE_CE_IMAGE} ${RENOVATE_FQDN} ${RENOVATE_LICENSE_KEY} ${RENOVATE_SERVER_API_SECRET} ${RENOVATE_GITLAB_PAT} ${RENOVATE_WEBHOOK_SECRET}' \
        <"${src}" >"${dest}"
    chmod "${mode}" "${dest}"
}

replace_template_token() {
    local file="$1" token="$2" replacement="${3:-}"
    TOKEN_REPLACEMENT="${replacement}" python3 - "${file}" "${token}" <<'PY'
import os
import sys

path = sys.argv[1]
token = sys.argv[2]
replacement = os.environ.get("TOKEN_REPLACEMENT", "")
with open(path, "r", encoding="utf-8") as f:
    content = f.read()
content = content.replace(f"#{token}", replacement)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PY
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

if [[ "${PGBOUNCER_ENABLED:-false}" == "true" ]]; then
    DB_HOST="pgbouncer"
    COMPOSE_PGBOUNCER_BLOCK="$(cat <<'EOF'
  pgbouncer:
    image: ${PGBOUNCER_IMAGE}
    restart: unless-stopped
    environment:
      DB_USER: gitlab
      DB_PASSWORD: "${POSTGRES_PASSWORD}"
      DB_HOST: postgres
      DB_PORT: 5432
      DB_NAME: gitlabhq_production
      POOL_MODE: ${PGBOUNCER_POOL_MODE}
      AUTH_TYPE: scram-sha-256
      MAX_CLIENT_CONN: ${PGBOUNCER_MAX_CLIENT_CONN}
      DEFAULT_POOL_SIZE: ${PGBOUNCER_DEFAULT_POOL_SIZE}
    networks:
      socket_proxy:
        ipv4_address: 172.31.255.251
        ipv6_address: fd00:1:be:a:7001:0:3e:8ffc
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -h localhost -p 5432 -U gitlab -d gitlabhq_production"]
      interval: 5s
      timeout: 5s
      retries: 20
    security_opt:
      - no-new-privileges:true
EOF
)"
    COMPOSE_GITLAB_PGBOUNCER_DEPENDENCY_BLOCK="$(cat <<'EOF'
      pgbouncer:
        condition: service_healthy
EOF
)"
else
    DB_HOST="postgres"
    COMPOSE_PGBOUNCER_BLOCK=""
    COMPOSE_GITLAB_PGBOUNCER_DEPENDENCY_BLOCK=""
fi

COMPOSE_GITLAB_OPTIONAL_VOLUME_BLOCK=""
if [[ "${ARTIFACTS_ENABLED:-false}" == "true" ]]; then
    COMPOSE_GITLAB_OPTIONAL_VOLUME_BLOCK="${COMPOSE_GITLAB_OPTIONAL_VOLUME_BLOCK}"$'\n'"      - ./artifacts/data:${ARTIFACTS_PATH}"
fi
if [[ "${REGISTRY_ENABLED:-false}" == "true" ]]; then
    COMPOSE_GITLAB_OPTIONAL_VOLUME_BLOCK="${COMPOSE_GITLAB_OPTIONAL_VOLUME_BLOCK}"$'\n'"      - ./registry/data:/var/opt/gitlab/gitlab-rails/shared/registry"$'\n'"      - ./registry/certs:/etc/gitlab/ssl/registry"
fi
if [[ "${TERRAFORM_ENABLED:-false}" == "true" ]]; then
    COMPOSE_GITLAB_OPTIONAL_VOLUME_BLOCK="${COMPOSE_GITLAB_OPTIONAL_VOLUME_BLOCK}"$'\n'"      - ./data/terraform/state:${GITLAB_TERRAFORM_STATE_PATH}"
fi

if [[ "${REGISTRY_ENABLED:-false}" == "true" ]]; then
    COMPOSE_GITLAB_REGISTRY_LABEL_BLOCK="$(cat <<'EOF'
      - "traefik.http.middlewares.registry-buffering.buffering.maxRequestBodyBytes=0"
      - "traefik.http.services.registry.loadbalancer.server.port=5050"
      - "traefik.http.routers.registry.service=registry"
      - "traefik.http.routers.registry.rule=Host(`${REGISTRY_FQDN}`)"
EOF
)"
    if [[ "${TRAEFIK_ACME_ENABLED}" == "true" ]]; then
        COMPOSE_GITLAB_REGISTRY_LABEL_BLOCK="${COMPOSE_GITLAB_REGISTRY_LABEL_BLOCK}"$'\n'"      - \"traefik.http.routers.registry.entrypoints=websecure\""$'\n'"      - \"traefik.http.routers.registry.tls=true\""$'\n'"      - \"traefik.http.routers.registry.tls.certresolver=hetzner\""
    else
        COMPOSE_GITLAB_REGISTRY_LABEL_BLOCK="${COMPOSE_GITLAB_REGISTRY_LABEL_BLOCK}"$'\n'"      - \"traefik.http.routers.registry.entrypoints=web\""
    fi
    COMPOSE_GITLAB_REGISTRY_LABEL_BLOCK="${COMPOSE_GITLAB_REGISTRY_LABEL_BLOCK}"$'\n'"      - \"traefik.http.routers.registry.middlewares=registry-buffering@docker,default@file\""
else
    COMPOSE_GITLAB_REGISTRY_LABEL_BLOCK=""
fi

if [[ "${PAGES_ENABLED:-false}" == "true" ]]; then
    COMPOSE_GITLAB_PAGES_LABEL_BLOCK="$(cat <<'EOF'
      - "traefik.http.services.pages.loadbalancer.server.port=8090"
      - "traefik.http.routers.pages.service=pages"
      - "traefik.http.routers.pages.rule=Host(`${PAGES_FQDN}`)"
EOF
)"
    if [[ "${TRAEFIK_ACME_ENABLED}" == "true" ]]; then
        COMPOSE_GITLAB_PAGES_LABEL_BLOCK="${COMPOSE_GITLAB_PAGES_LABEL_BLOCK}"$'\n'"      - \"traefik.http.routers.pages.entrypoints=websecure\""$'\n'"      - \"traefik.http.routers.pages.tls=true\""$'\n'"      - \"traefik.http.routers.pages.tls.certresolver=hetzner\""
    else
        COMPOSE_GITLAB_PAGES_LABEL_BLOCK="${COMPOSE_GITLAB_PAGES_LABEL_BLOCK}"$'\n'"      - \"traefik.http.routers.pages.entrypoints=web\""
    fi
    COMPOSE_GITLAB_PAGES_LABEL_BLOCK="${COMPOSE_GITLAB_PAGES_LABEL_BLOCK}"$'\n'"      - \"traefik.http.routers.pages.middlewares=default@file\""
else
    COMPOSE_GITLAB_PAGES_LABEL_BLOCK=""
fi

if [[ "${PLANTUML_ENABLED:-false}" == "true" ]]; then
    COMPOSE_PLANTUML_BLOCK="$(cat <<'EOF'
  plantuml:
    container_name: plantuml
    image: ${PLANTUML_IMAGE}
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      socket_proxy: {}
EOF
)"
    GITLAB_RB_PLANTUML_BLOCK="$(cat <<'EOF'
nginx['custom_gitlab_server_config'] = "location /-/plantuml/ { \n  rewrite ^/-/plantuml/(.*) /$1 break;\n  proxy_cache off;\n  proxy_pass http://plantuml:8080/;\n}\n"
gitlab_rails['env'] = { 'PLANTUML_ENCODING' => 'deflate' }
EOF
)"
else
    COMPOSE_PLANTUML_BLOCK=""
    GITLAB_RB_PLANTUML_BLOCK=""
fi

if [[ "${RUNNER_ENABLED:-false}" == "true" ]]; then
    COMPOSE_RUNNER_BLOCK="$(cat <<'EOF'
  gitlab-runner:
    container_name: gitlab-runner
    image: ${RUNNER_IMAGE}
    restart: unless-stopped
    depends_on:
      gitlab:
        condition: service_started
    extra_hosts:
      - "${GITLAB_FQDN}:172.31.191.247"
    volumes:
      - ./gitlab-runner:/etc/gitlab-runner
      - /var/run/docker.sock:/var/run/docker.sock
    security_opt:
      - no-new-privileges:true
    networks:
      proxy:
        ipv4_address: 172.31.129.250
        ipv6_address: fd00:1:be:a:7001:0:3e:7ffc
      socket_proxy: {}
EOF
)"
else
    COMPOSE_RUNNER_BLOCK=""
fi

if [[ "${RENOVATE_ENABLED:-false}" == "true" ]]; then
    COMPOSE_RENOVATE_BLOCK="$(cat <<'EOF'
  renovate-ce:
    container_name: renovate-ce
    image: ${RENOVATE_CE_IMAGE}
    restart: unless-stopped
    environment:
      LOG_LEVEL: info
      MEND_RNV_LICENSE_KEY: "${RENOVATE_LICENSE_KEY}"
      MEND_RNV_ACCEPT_TOS: "Y"
      MEND_RNV_SERVER_API_SECRET: "${RENOVATE_SERVER_API_SECRET}"
      MEND_RNV_PLATFORM: gitlab
      MEND_RNV_ENDPOINT: "${GITLAB_URL}/api/v4"
      MEND_RNV_GITLAB_PAT: "${RENOVATE_GITLAB_PAT}"
      MEND_RNV_WEBHOOK_SECRET: "${RENOVATE_WEBHOOK_SECRET}"
      MEND_RNV_WEBHOOK_URL: "${GITLAB_URL}/webhook"
    ports:
      - "8084:8080"
    volumes:
      - renovate_logs:/logs
      - renovate_db:/db
      - /etc/localtime:/etc/localtime:ro
    security_opt:
      - no-new-privileges:true
    networks:
      proxy:
        ipv4_address: 172.31.129.251
        ipv6_address: fd00:1:be:a:7001:0:3e:7ffd
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=proxy"
      - "traefik.http.services.renovate.loadbalancer.server.port=8084"
      - "traefik.http.routers.renovate.rule=Host(`${RENOVATE_FQDN}`)"
EOF
)"
    if [[ "${TRAEFIK_ACME_ENABLED}" == "true" ]]; then
        COMPOSE_RENOVATE_BLOCK="${COMPOSE_RENOVATE_BLOCK}"$'\n'"      - \"traefik.http.routers.renovate.entrypoints=websecure\""$'\n'"      - \"traefik.http.routers.renovate.tls=true\""$'\n'"      - \"traefik.http.routers.renovate.tls.certresolver=hetzner\""
    else
        COMPOSE_RENOVATE_BLOCK="${COMPOSE_RENOVATE_BLOCK}"$'\n'"      - \"traefik.http.routers.renovate.entrypoints=web\""
    fi
    COMPOSE_RENOVATE_BLOCK="${COMPOSE_RENOVATE_BLOCK}"$'\n'"      - \"traefik.http.routers.renovate.middlewares=default@file\""
else
    COMPOSE_RENOVATE_BLOCK=""
fi

if [[ "${TRAEFIK_ACME_ENABLED}" == "true" ]]; then
    COMPOSE_ACME_JSON_PATH_BLOCK='      ACME_JSON_PATH: /app/acme.json'
else
    COMPOSE_ACME_JSON_PATH_BLOCK=""
fi

if [[ "${PAGES_ENABLED:-false}" == "true" ]]; then
    GITLAB_RB_PAGES_BLOCK="$(cat <<'EOF'
pages_external_url '${EXTERNAL_URL_SCHEME}://${PAGES_FQDN}'
gitlab_pages['enable'] = true
gitlab_pages['listen_proxy'] = '0.0.0.0:8090'
gitlab_pages['custom_domain_mode'] = 'http'
pages_nginx['enable'] = false
EOF
)"
else
    GITLAB_RB_PAGES_BLOCK="gitlab_pages['enable'] = false"
fi

if [[ "${REGISTRY_ENABLED:-false}" == "true" ]]; then
    GITLAB_RB_REGISTRY_BLOCK="$(cat <<'EOF'
registry_external_url '${EXTERNAL_URL_SCHEME}://${REGISTRY_FQDN}'
gitlab_rails['registry_enabled'] = true
registry['enable'] = true
registry_nginx['enable'] = false
registry['registry_http_addr'] = "0.0.0.0:5050"
EOF
)"
else
    GITLAB_RB_REGISTRY_BLOCK=""
fi

if [[ "${ARTIFACTS_ENABLED:-false}" == "true" ]]; then
    GITLAB_RB_ARTIFACTS_BLOCK="$(cat <<'EOF'
gitlab_rails['artifacts_enabled'] = true
gitlab_rails['artifacts_path'] = "${ARTIFACTS_PATH}"
EOF
)"
else
    GITLAB_RB_ARTIFACTS_BLOCK="gitlab_rails['artifacts_enabled'] = false"
fi

if [[ "${TERRAFORM_ENABLED:-false}" == "true" ]]; then
    GITLAB_RB_TERRAFORM_BLOCK="$(cat <<'EOF'
gitlab_rails['terraform_enabled'] = true
gitlab_rails['terraform_state_storage'] = 'local'
gitlab_rails['terraform_state_path'] = "${GITLAB_TERRAFORM_STATE_PATH}"
gitlab_rails['terraform_state_file'] = "${GITLAB_TERRAFORM_STATE_FILE}"
EOF
)"
else
    GITLAB_RB_TERRAFORM_BLOCK=""
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
POSTGRES_UID="$(docker run --rm "${POSTGRES_IMAGE}" sh -lc 'id -u postgres 2>/dev/null || id -u' 2>/dev/null || true)"
POSTGRES_GID="$(docker run --rm "${POSTGRES_IMAGE}" sh -lc 'id -g postgres 2>/dev/null || id -g' 2>/dev/null || true)"
if [[ ! "${POSTGRES_UID}" =~ ^[0-9]+$ ]] || [[ ! "${POSTGRES_GID}" =~ ^[0-9]+$ ]]; then
    POSTGRES_UID=70
    POSTGRES_GID=70
fi
chown "${POSTGRES_UID}:${POSTGRES_GID}" /opt/gitlab/postgres/data
install -m 0755 -d /opt/gitlab/data/config /opt/gitlab/data/logs /opt/gitlab/data/gitlab
install -m 0755 -d /var/log/traefik
touch /var/log/traefik/access.log
chmod 0644 /var/log/traefik/access.log
if [[ "${BACKUP_ENABLED:-false}" == "true" ]]; then
    install -m 0755 -d /opt/gitlab/docs
    install -m 0750 -d /opt/gitlab/backups /opt/gitlab/scripts
fi
if [[ "${RUNNER_ENABLED:-false}" == "true" ]]; then
    install -m 0700 -d /opt/gitlab/gitlab-runner
fi
if [[ "${ARTIFACTS_ENABLED:-false}" == "true" ]]; then
    install -m 0750 -d /opt/gitlab/artifacts/data
fi
if [[ "${REGISTRY_ENABLED:-false}" == "true" ]]; then
    install -m 0750 -d /opt/gitlab/registry/data /opt/gitlab/registry/certs
fi
if [[ "${TERRAFORM_ENABLED:-false}" == "true" ]]; then
    install -m 0750 -d /opt/gitlab/data/terraform/state
fi

if [[ "${TRAEFIK_MANAGER_ENABLED}" == "true" ]]; then
    install -m 0700 -d /opt/gitlab/traefik-manager/config /opt/gitlab/traefik-manager/backups
    if [[ -z "${TRAEFIK_MANAGER_SECRET_KEY:-}" ]]; then
        TRAEFIK_MANAGER_SECRET_KEY="$(openssl rand -hex 32)"
    fi
    if [[ ! -f /opt/gitlab/traefik-manager/config/manager.yml ]]; then
        render_template "${TEMPLATES_DIR}/traefik-manager/manager.yml.tpl" \
            /opt/gitlab/traefik-manager/config/manager.yml 0600
    fi
fi

install -d -m 0755 /opt/gitlab/traefik/dynamic_conf
cp -a "${TEMPLATES_DIR}/traefik/dynamic_conf/." /opt/gitlab/traefik/dynamic_conf/

render_template "${TRAEFIK_SRC}" /opt/gitlab/traefik/traefik.yml 0644
render_template "${TEMPLATES_DIR}/traefik/.env.tpl" /opt/gitlab/traefik/.env 0600
render_template "${COMPOSE_SRC}" /opt/gitlab/docker-compose.yml 0644
replace_template_token /opt/gitlab/docker-compose.yml "__COMPOSE_PGBOUNCER_BLOCK__" "${COMPOSE_PGBOUNCER_BLOCK}"
replace_template_token /opt/gitlab/docker-compose.yml "__COMPOSE_GITLAB_PGBOUNCER_DEPENDENCY_BLOCK__" "${COMPOSE_GITLAB_PGBOUNCER_DEPENDENCY_BLOCK}"
replace_template_token /opt/gitlab/docker-compose.yml "__COMPOSE_GITLAB_OPTIONAL_VOLUME_BLOCK__" "${COMPOSE_GITLAB_OPTIONAL_VOLUME_BLOCK}"
replace_template_token /opt/gitlab/docker-compose.yml "__COMPOSE_GITLAB_REGISTRY_LABEL_BLOCK__" "${COMPOSE_GITLAB_REGISTRY_LABEL_BLOCK}"
replace_template_token /opt/gitlab/docker-compose.yml "__COMPOSE_GITLAB_PAGES_LABEL_BLOCK__" "${COMPOSE_GITLAB_PAGES_LABEL_BLOCK}"
replace_template_token /opt/gitlab/docker-compose.yml "__COMPOSE_PLANTUML_BLOCK__" "${COMPOSE_PLANTUML_BLOCK}"
replace_template_token /opt/gitlab/docker-compose.yml "__COMPOSE_RUNNER_BLOCK__" "${COMPOSE_RUNNER_BLOCK}"
replace_template_token /opt/gitlab/docker-compose.yml "__COMPOSE_RENOVATE_BLOCK__" "${COMPOSE_RENOVATE_BLOCK}"
replace_template_token /opt/gitlab/docker-compose.yml "__COMPOSE_ACME_JSON_PATH_BLOCK__" "${COMPOSE_ACME_JSON_PATH_BLOCK}"
render_template "${TEMPLATES_DIR}/data/config/gitlab.rb.tpl" /opt/gitlab/data/config/gitlab.rb 0600
if [[ "${BACKUP_ENABLED:-false}" == "true" ]]; then
    render_template "${TEMPLATES_DIR}/scripts/gitlab-backup.sh.tpl" /opt/gitlab/scripts/gitlab-backup.sh 0750
    render_template "${TEMPLATES_DIR}/scripts/gitlab-restore.sh.tpl" /opt/gitlab/scripts/gitlab-restore.sh 0750
fi
if [[ "${RUNNER_ENABLED:-false}" == "true" && "${RUNNER_AUTOREGISTER:-false}" == "true" ]]; then
    render_template "${TEMPLATES_DIR}/scripts/gitlab-runner-autoregister.sh.tpl" /opt/gitlab/scripts/gitlab-runner-autoregister.sh 0750
fi
if [[ "${PLANTUML_ENABLED:-false}" == "true" ]]; then
    render_template "${TEMPLATES_DIR}/scripts/gitlab-plantuml-enable.sh.tpl" /opt/gitlab/scripts/gitlab-plantuml-enable.sh 0750
fi

echo "=== DNS preflight (before docker compose pull) ==="
cat /etc/resolv.conf
if ! getent hosts auth.docker.io registry-1.docker.io >/dev/null 2>&1; then
    echo "ERROR: DNS resolution failed for Docker registries (auth.docker.io / registry-1.docker.io)." >&2
    echo "  nameserver(s): $(awk '/^nameserver/{print $2}' /etc/resolv.conf | tr '\n' ' ')" >&2
    echo "  Fix on Proxmox host: pct set <vmid> -nameserver 8.8.8.8" >&2
    echo "  Or recreate with: --dns 8.8.8.8 (or 1.1.1.1)" >&2
    exit 1
fi

echo "=== docker compose up ==="
cd /opt/gitlab
docker compose "${COMPOSE_PROFILES[@]}" pull
docker compose "${COMPOSE_PROFILES[@]}" up -d
if [[ "${RUNNER_ENABLED:-false}" == "true" && "${RUNNER_AUTOREGISTER:-false}" == "true" ]]; then
    nohup /opt/gitlab/scripts/gitlab-runner-autoregister.sh >>/var/log/gitlab-runner-autoregister.log 2>&1 &
fi
if [[ "${PLANTUML_ENABLED:-false}" == "true" ]]; then
    nohup /opt/gitlab/scripts/gitlab-plantuml-enable.sh >>/var/log/gitlab-plantuml-enable.log 2>&1 &
fi
if [[ "${BACKUP_ENABLED:-false}" == "true" && "${BACKUP_AUTO_ENABLED:-false}" == "true" ]]; then
    cat >/etc/cron.d/gitlab-backup <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
${BACKUP_CRON} root GITLAB_BACKUP_SOURCE=cron /opt/gitlab/scripts/gitlab-backup.sh
EOF
    chmod 0644 /etc/cron.d/gitlab-backup
fi

echo "=== ensure gitlab root user exists ==="
ROOT_ENSURE_OUT="$(docker compose exec -T gitlab bash -lc '
gitlab-rails runner "
u = User.find_by_username(\"root\")
if u.nil?
  pass = ENV[\"GITLAB_ROOT_PASSWORD\"]
  mail = ENV[\"GITLAB_ROOT_EMAIL\"]
  raise \"GITLAB_ROOT_PASSWORD missing\" if pass.to_s.empty?
  raise \"GITLAB_ROOT_EMAIL missing\" if mail.to_s.empty?
  ns = Namespace.find_by(path: \"root\")
  if ns.nil?
    ns = Namespace.create!(name: \"root\", path: \"root\")
  end
  u = User.new(
    username: \"root\",
    name: \"Administrator\",
    email: mail,
    password: pass,
    password_confirmation: pass,
    admin: true,
    namespace: ns
  )
  u.confirm
  u.save!
  puts({root_exists: true, root_created: true, state: u.state, namespace_id: u.namespace_id}.to_json)
else
  puts({root_exists: true, root_created: false, state: u.state, namespace_id: u.namespace_id}.to_json)
end
"
' 2>&1 || true)"
echo "=== finished $(date -Is) ==="
