#!/usr/bin/env bash
# GitLab Docker Compose config for PVE LXC install (sourced by pve-secure-gitlab-lxc.sh).
# Keep in sync with terraform/templates/gitlab-docker-cloud-init.yaml.tpl for core stack.

gitlab_docker_config_init_defaults() {
    CONFIG_FILE="${CONFIG_FILE:-}"
    DNS_DOMAIN="${DNS_DOMAIN:-example.com}"
    GITLAB_DNS_LABEL="${GITLAB_DNS_LABEL:-gitlab}"
    GITLAB_FQDN="${GITLAB_FQDN:-}"
    TRAEFIK_IMAGE="${TRAEFIK_IMAGE:-traefik:v3.7.5}"
    GITLAB_CE_IMAGE="${GITLAB_CE_IMAGE:-gitlab/gitlab-ce:18.11.6-ce.0}"
    POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:16-alpine}"
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
        printf 'TEMPLATES_DIR=%q\n' "${TEMPLATES_DIR:-/root/gitlab-docker-core}"
    } >"${dest}"
    chmod 600 "${dest}"
}
