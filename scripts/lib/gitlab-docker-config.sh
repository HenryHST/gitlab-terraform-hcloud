#!/usr/bin/env bash
# GitLab Docker Compose config for PVE LXC install (sourced by pve-secure-gitlab-lxc.sh).
# Keep in sync with terraform/templates/gitlab-docker-cloud-init.yaml.tpl for core stack.

gitlab_docker_config_init_defaults() {
    CONFIG_FILE="${CONFIG_FILE:-}"
    DNS_DOMAIN="${DNS_DOMAIN:-example.com}"
    GITLAB_DNS_LABEL="${GITLAB_DNS_LABEL:-gitlab}"
    GITLAB_FQDN="${GITLAB_FQDN:-}"
    TRAEFIK_IMAGE="${TRAEFIK_IMAGE:-traefik:v3.7.6}"
    GITLAB_CE_IMAGE="${GITLAB_CE_IMAGE:-gitlab/gitlab-ce:18.11.6-ce.0}"
    POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:17-alpine}"
    TRAEFIK_ACME_ENABLED="${TRAEFIK_ACME_ENABLED:-false}"
    HETZNER_API_TOKEN="${HETZNER_API_TOKEN:-}"
    ACME_EMAIL="${ACME_EMAIL:-}"
    GITLAB_ROOT_EMAIL="${GITLAB_ROOT_EMAIL:-}"
    GITLAB_ROOT_PASSWORD="${GITLAB_ROOT_PASSWORD:-}"
    POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
    GITLAB_SIGNUP_ENABLED="${GITLAB_SIGNUP_ENABLED:-false}"
    GITLAB_THEME_ID="${GITLAB_THEME_ID:-2}"
    GITLAB_COLOR_MODE="${GITLAB_COLOR_MODE:-3}"
    GITLAB_TIME_ZONE="${GITLAB_TIME_ZONE:-Europe/Berlin}"
    HOST_HARDENING_ENABLED="${HOST_HARDENING_ENABLED:-true}"
    HOST_HARDENING_UNATTENDED_UPGRADES="${HOST_HARDENING_UNATTENDED_UPGRADES:-true}"
    UFW_SSH_SOURCE_IPS="${UFW_SSH_SOURCE_IPS:-}"
    SSH_PUBLIC_KEY_FILE="${SSH_PUBLIC_KEY_FILE:-}"
    SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"
    GITLAB_ADMIN_ENABLED="${GITLAB_ADMIN_ENABLED:-false}"
    GITLAB_ADMIN_USERNAME="${GITLAB_ADMIN_USERNAME:-gadmin}"
    TRAEFIK_MANAGER_ENABLED="${TRAEFIK_MANAGER_ENABLED:-true}"
    TRAEFIK_MANAGER_IMAGE="${TRAEFIK_MANAGER_IMAGE:-ghcr.io/chr0nzz/traefik-manager:1.6.1}"
    TRAEFIK_MANAGER_PASSWORD="${TRAEFIK_MANAGER_PASSWORD:-}"
    TRAEFIK_MANAGER_SECRET_KEY="${TRAEFIK_MANAGER_SECRET_KEY:-}"
    RUNNER_ENABLED="${RUNNER_ENABLED:-false}"
    RUNNER_IMAGE="${RUNNER_IMAGE:-gitlab/gitlab-runner:alpine-v18.4.0}"
    RUNNER_AUTOREGISTER="${RUNNER_AUTOREGISTER:-false}"
    RUNNER_DESCRIPTION="${RUNNER_DESCRIPTION:-gitlab-docker-runner}"
    RUNNER_EXECUTOR="${RUNNER_EXECUTOR:-docker}"
    RUNNER_DEFAULT_IMAGE="${RUNNER_DEFAULT_IMAGE:-alpine:3.22}"
    RUNNER_PRIVILEGED="${RUNNER_PRIVILEGED:-true}"
    RUNNER_CONCURRENT="${RUNNER_CONCURRENT:-4}"
    RUNNER_TAG_LIST="${RUNNER_TAG_LIST:-docker,lxc}"
    RUNNER_TOKEN="${RUNNER_TOKEN:-}"
    BACKUP_ENABLED="${BACKUP_ENABLED:-false}"
    BACKUP_AUTO_ENABLED="${BACKUP_AUTO_ENABLED:-false}"
    BACKUP_CRON="${BACKUP_CRON:-30 2 * * *}"
    BACKUP_KEEP_TIME="${BACKUP_KEEP_TIME:-1209600}"
    REGISTRY_ENABLED="${REGISTRY_ENABLED:-false}"
    REGISTRY_FQDN="${REGISTRY_FQDN:-registry.${DNS_DOMAIN}}"
    PAGES_ENABLED="${PAGES_ENABLED:-false}"
    PAGES_FQDN="${PAGES_FQDN:-pages.${DNS_DOMAIN}}"
    ARTIFACTS_ENABLED="${ARTIFACTS_ENABLED:-false}"
    ARTIFACTS_PATH="${ARTIFACTS_PATH:-/var/opt/gitlab/gitlab-rails/shared/artifacts}"
    TERRAFORM_ENABLED="${TERRAFORM_ENABLED:-false}"
    GITLAB_TERRAFORM_STATE_PATH="${GITLAB_TERRAFORM_STATE_PATH:-/var/opt/gitlab/gitlab-rails/shared/terraform_state}"
    GITLAB_TERRAFORM_STATE_FILE="${GITLAB_TERRAFORM_STATE_FILE:-terraform_state}"
    PLANTUML_ENABLED="${PLANTUML_ENABLED:-false}"
    PLANTUML_IMAGE="${PLANTUML_IMAGE:-plantuml/plantuml-server:v1.2025.7}"
    PLANTUML_URL="${PLANTUML_URL:-http://plantuml:8080}"
    RENOVATE_ENABLED="${RENOVATE_ENABLED:-false}"
    RENOVATE_CE_IMAGE="${RENOVATE_CE_IMAGE:-ghcr.io/mend/renovate-ce:9.8.7}"
    RENOVATE_FQDN="${RENOVATE_FQDN:-renovate.${DNS_DOMAIN}}"
    RENOVATE_LICENSE_KEY="${RENOVATE_LICENSE_KEY:-}"
    RENOVATE_SERVER_API_SECRET="${RENOVATE_SERVER_API_SECRET:-}"
    RENOVATE_GITLAB_PAT="${RENOVATE_GITLAB_PAT:-}"
    RENOVATE_WEBHOOK_SECRET="${RENOVATE_WEBHOOK_SECRET:-}"
    PGBOUNCER_ENABLED="${PGBOUNCER_ENABLED:-false}"
    PGBOUNCER_IMAGE="${PGBOUNCER_IMAGE:-bitnami/pgbouncer:1.24.1}"
    PGBOUNCER_POOL_MODE="${PGBOUNCER_POOL_MODE:-transaction}"
    PGBOUNCER_MAX_CLIENT_CONN="${PGBOUNCER_MAX_CLIENT_CONN:-1000}"
    PGBOUNCER_DEFAULT_POOL_SIZE="${PGBOUNCER_DEFAULT_POOL_SIZE:-100}"
}

gitlab_docker_config_load() {
    gitlab_docker_config_init_defaults
    if [[ -n "${CONFIG_FILE}" && -f "${CONFIG_FILE}" ]]; then
        # shellcheck source=/dev/null
        source "${CONFIG_FILE}"
    fi
    gitlab_docker_config_derive
    gitlab_docker_config_generate_secrets
    gitlab_docker_config_validate
}

gitlab_docker_config_derive() {
    if [[ -z "${GITLAB_FQDN}" ]]; then
        GITLAB_FQDN="${GITLAB_DNS_LABEL}.${DNS_DOMAIN}"
    fi
    if [[ "${TRAEFIK_ACME_ENABLED}" == "true" || "${TRAEFIK_ACME_ENABLED}" == "1" ]]; then
        EXTERNAL_URL_SCHEME="https"
        TRAEFIK_ACME_ENABLED=true
        TRAEFIK_MANAGER_CERT_RESOLVER="hetzner"
    else
        EXTERNAL_URL_SCHEME="http"
        TRAEFIK_ACME_ENABLED=false
        TRAEFIK_MANAGER_CERT_RESOLVER="none"
    fi
    if [[ "${TRAEFIK_MANAGER_ENABLED}" == "true" || "${TRAEFIK_MANAGER_ENABLED}" == "1" ]]; then
        TRAEFIK_MANAGER_ENABLED=true
    else
        TRAEFIK_MANAGER_ENABLED=false
    fi
    for bool_var in \
        RUNNER_ENABLED RUNNER_AUTOREGISTER BACKUP_ENABLED BACKUP_AUTO_ENABLED REGISTRY_ENABLED \
        PAGES_ENABLED ARTIFACTS_ENABLED TERRAFORM_ENABLED PLANTUML_ENABLED RENOVATE_ENABLED \
        PGBOUNCER_ENABLED HOST_HARDENING_ENABLED HOST_HARDENING_UNATTENDED_UPGRADES \
        GITLAB_ADMIN_ENABLED; do
        if [[ "${!bool_var}" == "true" || "${!bool_var}" == "1" || "${!bool_var}" == "yes" ]]; then
            printf -v "${bool_var}" '%s' "true"
        else
            printf -v "${bool_var}" '%s' "false"
        fi
    done
    GITLAB_URL="${EXTERNAL_URL_SCHEME}://${GITLAB_FQDN}"
    if [[ -z "${GITLAB_ROOT_EMAIL}" ]]; then
        if [[ -n "${ACME_EMAIL}" ]]; then
            GITLAB_ROOT_EMAIL="${ACME_EMAIL}"
        else
            GITLAB_ROOT_EMAIL="gitlab-root@${DNS_DOMAIN}"
        fi
    fi
    if [[ -z "${ACME_EMAIL}" && "${TRAEFIK_ACME_ENABLED}" == "true" ]]; then
        ACME_EMAIL="${GITLAB_ROOT_EMAIL}"
    fi
    SSH_PUBLIC_KEY_EFFECTIVE="$(gitlab_docker_config_read_ssh_key)"
}

gitlab_docker_config_read_ssh_key() {
    local key=""
    if [[ -n "${SSH_PUBLIC_KEY_FILE}" ]]; then
        local expanded
        expanded="${SSH_PUBLIC_KEY_FILE/#\~/$HOME}"
        if [[ -f "${expanded}" ]]; then
            key="$(tr -d '\r\n' < "${expanded}")"
        fi
    fi
    if [[ -z "${key}" && -n "${SSH_PUBLIC_KEY}" ]]; then
        key="${SSH_PUBLIC_KEY}"
    fi
    printf '%s' "${key}"
}

gitlab_docker_config_generate_secrets() {
    if [[ -z "${GITLAB_ROOT_PASSWORD}" ]]; then
        GITLAB_ROOT_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
    fi
    if [[ -z "${POSTGRES_PASSWORD}" ]]; then
        POSTGRES_PASSWORD="$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)"
    fi
    if [[ "${TRAEFIK_MANAGER_ENABLED}" == "true" && -z "${TRAEFIK_MANAGER_PASSWORD}" ]]; then
        TRAEFIK_MANAGER_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
    fi
    if [[ "${TRAEFIK_MANAGER_ENABLED}" == "true" && -z "${TRAEFIK_MANAGER_SECRET_KEY}" ]]; then
        TRAEFIK_MANAGER_SECRET_KEY="$(openssl rand -hex 32)"
    fi
}

gitlab_docker_config_validate() {
    if [[ ! "${GITLAB_FQDN}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
        echo "Invalid GITLAB_FQDN: ${GITLAB_FQDN}" >&2
        return 1
    fi
    if [[ "${TRAEFIK_ACME_ENABLED}" == "true" ]]; then
        if [[ -z "${HETZNER_API_TOKEN}" ]]; then
            echo "TRAEFIK_ACME_ENABLED requires HETZNER_API_TOKEN" >&2
            return 1
        fi
        if [[ -z "${ACME_EMAIL}" ]]; then
            echo "TRAEFIK_ACME_ENABLED requires ACME_EMAIL" >&2
            return 1
        fi
    fi
    if [[ "${GITLAB_ADMIN_ENABLED}" == "true" && -z "${SSH_PUBLIC_KEY_EFFECTIVE}" ]]; then
        echo "GITLAB_ADMIN_ENABLED requires SSH_PUBLIC_KEY_FILE or SSH_PUBLIC_KEY" >&2
        return 1
    fi
    if [[ ! "${POSTGRES_IMAGE}" =~ ^postgres:(1[3-7])(\.[0-9]+){0,2}(-[a-zA-Z0-9._-]+)?$ ]]; then
        echo "Invalid POSTGRES_IMAGE: ${POSTGRES_IMAGE} (expected postgres:<major>[.<minor>[.<patch>]][-suffix], major 13-17)" >&2
        return 1
    fi
    if [[ "${RUNNER_ENABLED}" == "true" ]]; then
        if [[ ! "${RUNNER_IMAGE}" =~ ^[a-zA-Z0-9./_-]+:[a-zA-Z0-9._-]+$ ]]; then
            echo "Invalid RUNNER_IMAGE: ${RUNNER_IMAGE}" >&2
            return 1
        fi
        if [[ ! "${RUNNER_CONCURRENT}" =~ ^[1-9][0-9]*$ ]]; then
            echo "RUNNER_CONCURRENT must be a positive integer" >&2
            return 1
        fi
    fi
    if [[ "${PGBOUNCER_ENABLED}" == "true" && ! "${PGBOUNCER_IMAGE}" =~ ^[a-zA-Z0-9./_-]+:[a-zA-Z0-9._-]+$ ]]; then
        echo "Invalid PGBOUNCER_IMAGE: ${PGBOUNCER_IMAGE}" >&2
        return 1
    fi
    if [[ "${RENOVATE_ENABLED}" == "true" ]]; then
        if [[ -z "${RENOVATE_LICENSE_KEY}" || -z "${RENOVATE_SERVER_API_SECRET}" || -z "${RENOVATE_GITLAB_PAT}" || -z "${RENOVATE_WEBHOOK_SECRET}" ]]; then
            echo "RENOVATE_ENABLED requires RENOVATE_LICENSE_KEY, RENOVATE_SERVER_API_SECRET, RENOVATE_GITLAB_PAT and RENOVATE_WEBHOOK_SECRET" >&2
            return 1
        fi
    fi
    if [[ "${TRAEFIK_ACME_ENABLED}" == "true" && "${PAGES_ENABLED}" == "true" && -z "${PAGES_FQDN}" ]]; then
        echo "PAGES_ENABLED requires PAGES_FQDN" >&2
        return 1
    fi
    if [[ "${GITLAB_CE_IMAGE}" =~ ^gitlab/gitlab-ce:([0-9]+)\.[0-9]+\.[0-9]+-ce\.0$ ]]; then
        local gitlab_major="${BASH_REMATCH[1]}"
        if [[ "${gitlab_major}" == "19" && ! "${POSTGRES_IMAGE}" =~ ^postgres:17(\.[0-9]+){0,2}(-[a-zA-Z0-9._-]+)?$ ]]; then
            echo "POSTGRES_IMAGE must use postgres:17* when GITLAB_CE_IMAGE is GitLab 19.x" >&2
            return 1
        fi
    fi
    if [[ "${TRAEFIK_MANAGER_ENABLED}" == "true" ]]; then
        if [[ ! "${TRAEFIK_MANAGER_IMAGE}" =~ ^ghcr\.io/chr0nzz/traefik-manager:[a-zA-Z0-9][a-zA-Z0-9._-]+$ ]]; then
            echo "Invalid TRAEFIK_MANAGER_IMAGE: ${TRAEFIK_MANAGER_IMAGE}" >&2
            return 1
        fi
        if [[ -n "${TRAEFIK_MANAGER_PASSWORD}" && ${#TRAEFIK_MANAGER_PASSWORD} -lt 8 ]]; then
            echo "TRAEFIK_MANAGER_PASSWORD must be at least 8 characters when set" >&2
            return 1
        fi
    fi
}

gitlab_docker_config_write_env_file() {
    local dest="$1"
    umask 077
    {
        printf 'GITLAB_FQDN=%q\n' "${GITLAB_FQDN}"
        printf 'DNS_DOMAIN=%q\n' "${DNS_DOMAIN}"
        printf 'EXTERNAL_URL_SCHEME=%q\n' "${EXTERNAL_URL_SCHEME}"
        printf 'GITLAB_URL=%q\n' "${GITLAB_URL}"
        printf 'TRAEFIK_IMAGE=%q\n' "${TRAEFIK_IMAGE}"
        printf 'GITLAB_CE_IMAGE=%q\n' "${GITLAB_CE_IMAGE}"
        printf 'POSTGRES_IMAGE=%q\n' "${POSTGRES_IMAGE}"
        printf 'TRAEFIK_ACME_ENABLED=%q\n' "${TRAEFIK_ACME_ENABLED}"
        printf 'HETZNER_API_TOKEN=%q\n' "${HETZNER_API_TOKEN}"
        printf 'ACME_EMAIL=%q\n' "${ACME_EMAIL}"
        printf 'GITLAB_ROOT_EMAIL=%q\n' "${GITLAB_ROOT_EMAIL}"
        printf 'GITLAB_ROOT_PASSWORD=%q\n' "${GITLAB_ROOT_PASSWORD}"
        printf 'POSTGRES_PASSWORD=%q\n' "${POSTGRES_PASSWORD}"
        printf 'GITLAB_SIGNUP_ENABLED=%q\n' "${GITLAB_SIGNUP_ENABLED}"
        printf 'GITLAB_THEME_ID=%q\n' "${GITLAB_THEME_ID}"
        printf 'GITLAB_COLOR_MODE=%q\n' "${GITLAB_COLOR_MODE}"
        printf 'GITLAB_TIME_ZONE=%q\n' "${GITLAB_TIME_ZONE}"
        printf 'HOST_HARDENING_ENABLED=%q\n' "${HOST_HARDENING_ENABLED}"
        printf 'HOST_HARDENING_UNATTENDED_UPGRADES=%q\n' "${HOST_HARDENING_UNATTENDED_UPGRADES}"
        printf 'UFW_SSH_SOURCE_IPS=%q\n' "${UFW_SSH_SOURCE_IPS}"
        printf 'GITLAB_ADMIN_ENABLED=%q\n' "${GITLAB_ADMIN_ENABLED}"
        printf 'GITLAB_ADMIN_USERNAME=%q\n' "${GITLAB_ADMIN_USERNAME}"
        printf 'SSH_PUBLIC_KEY_EFFECTIVE=%q\n' "${SSH_PUBLIC_KEY_EFFECTIVE}"
        printf 'TRAEFIK_MANAGER_ENABLED=%q\n' "${TRAEFIK_MANAGER_ENABLED}"
        printf 'TRAEFIK_MANAGER_IMAGE=%q\n' "${TRAEFIK_MANAGER_IMAGE}"
        printf 'TRAEFIK_MANAGER_PASSWORD=%q\n' "${TRAEFIK_MANAGER_PASSWORD}"
        printf 'TRAEFIK_MANAGER_SECRET_KEY=%q\n' "${TRAEFIK_MANAGER_SECRET_KEY}"
        printf 'TRAEFIK_MANAGER_CERT_RESOLVER=%q\n' "${TRAEFIK_MANAGER_CERT_RESOLVER}"
        printf 'RUNNER_ENABLED=%q\n' "${RUNNER_ENABLED}"
        printf 'RUNNER_IMAGE=%q\n' "${RUNNER_IMAGE}"
        printf 'RUNNER_AUTOREGISTER=%q\n' "${RUNNER_AUTOREGISTER}"
        printf 'RUNNER_DESCRIPTION=%q\n' "${RUNNER_DESCRIPTION}"
        printf 'RUNNER_EXECUTOR=%q\n' "${RUNNER_EXECUTOR}"
        printf 'RUNNER_DEFAULT_IMAGE=%q\n' "${RUNNER_DEFAULT_IMAGE}"
        printf 'RUNNER_PRIVILEGED=%q\n' "${RUNNER_PRIVILEGED}"
        printf 'RUNNER_CONCURRENT=%q\n' "${RUNNER_CONCURRENT}"
        printf 'RUNNER_TAG_LIST=%q\n' "${RUNNER_TAG_LIST}"
        printf 'RUNNER_TOKEN=%q\n' "${RUNNER_TOKEN}"
        printf 'BACKUP_ENABLED=%q\n' "${BACKUP_ENABLED}"
        printf 'BACKUP_AUTO_ENABLED=%q\n' "${BACKUP_AUTO_ENABLED}"
        printf 'BACKUP_CRON=%q\n' "${BACKUP_CRON}"
        printf 'BACKUP_KEEP_TIME=%q\n' "${BACKUP_KEEP_TIME}"
        printf 'REGISTRY_ENABLED=%q\n' "${REGISTRY_ENABLED}"
        printf 'REGISTRY_FQDN=%q\n' "${REGISTRY_FQDN}"
        printf 'PAGES_ENABLED=%q\n' "${PAGES_ENABLED}"
        printf 'PAGES_FQDN=%q\n' "${PAGES_FQDN}"
        printf 'ARTIFACTS_ENABLED=%q\n' "${ARTIFACTS_ENABLED}"
        printf 'ARTIFACTS_PATH=%q\n' "${ARTIFACTS_PATH}"
        printf 'TERRAFORM_ENABLED=%q\n' "${TERRAFORM_ENABLED}"
        printf 'GITLAB_TERRAFORM_STATE_PATH=%q\n' "${GITLAB_TERRAFORM_STATE_PATH}"
        printf 'GITLAB_TERRAFORM_STATE_FILE=%q\n' "${GITLAB_TERRAFORM_STATE_FILE}"
        printf 'PLANTUML_ENABLED=%q\n' "${PLANTUML_ENABLED}"
        printf 'PLANTUML_IMAGE=%q\n' "${PLANTUML_IMAGE}"
        printf 'PLANTUML_URL=%q\n' "${PLANTUML_URL}"
        printf 'RENOVATE_ENABLED=%q\n' "${RENOVATE_ENABLED}"
        printf 'RENOVATE_CE_IMAGE=%q\n' "${RENOVATE_CE_IMAGE}"
        printf 'RENOVATE_FQDN=%q\n' "${RENOVATE_FQDN}"
        printf 'RENOVATE_LICENSE_KEY=%q\n' "${RENOVATE_LICENSE_KEY}"
        printf 'RENOVATE_SERVER_API_SECRET=%q\n' "${RENOVATE_SERVER_API_SECRET}"
        printf 'RENOVATE_GITLAB_PAT=%q\n' "${RENOVATE_GITLAB_PAT}"
        printf 'RENOVATE_WEBHOOK_SECRET=%q\n' "${RENOVATE_WEBHOOK_SECRET}"
        printf 'PGBOUNCER_ENABLED=%q\n' "${PGBOUNCER_ENABLED}"
        printf 'PGBOUNCER_IMAGE=%q\n' "${PGBOUNCER_IMAGE}"
        printf 'PGBOUNCER_POOL_MODE=%q\n' "${PGBOUNCER_POOL_MODE}"
        printf 'PGBOUNCER_MAX_CLIENT_CONN=%q\n' "${PGBOUNCER_MAX_CLIENT_CONN}"
        printf 'PGBOUNCER_DEFAULT_POOL_SIZE=%q\n' "${PGBOUNCER_DEFAULT_POOL_SIZE}"
        printf 'TEMPLATES_DIR=%q\n' "${TEMPLATES_DIR:-/root/gitlab-docker-core}"
    } >"${dest}"
    chmod 600 "${dest}"
}
