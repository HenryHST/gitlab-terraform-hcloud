#!/usr/bin/env bash
#
# GitLab CE (Docker Compose) on Proxmox LXC — Debian host, Traefik + PostgreSQL
#
# Version: 3.0.0
# Based on hiall-fyi/pve-secure-gitlab-lxc (Omnibus/Ubuntu); stack aligned with
# terraform/templates/gitlab-docker-cloud-init.yaml.tpl
#
# Usage:
#   Interactive:  ./pve-secure-gitlab-lxc.sh
#   Non-interactive: ./pve-secure-gitlab-lxc.sh --config scripts/pve-gitlab.conf --vmid 110 ...
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/gitlab-docker-config.sh
source "${SCRIPT_DIR}/lib/gitlab-docker-config.sh"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step() { echo -e "\n${BLUE}==>${NC} ${GREEN}$*${NC}\n"; }
err() { log_error "$*"; exit 1; }

INTERACTIVE=true
SCRIPT_VERSION="3.0.0"
CONFIG_FILE=""
VMID=""
CT_HOSTNAME=""
CPU=""
RAM=""
SWAP=""
BOOTDISK=""
DATA_SIZE=""
CT_IP=""
GATEWAY=""
DNS=""
STORAGE=""
ROOTFS_STORAGE=""
LVM_VG=""
BRIDGE="vmbr0"
FORCE_CLEANUP=false
STORAGE_MODE="simple"
CLI_FQDN=""
CLI_ACME=""

print_config_summary() {
    local tls_mode="HTTP (Traefik)"
    if [[ "${TRAEFIK_ACME_ENABLED}" == "true" ]]; then
        tls_mode="HTTPS (Traefik ACME DNS-01)"
    fi
    cat <<EOF
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
  Container ID    : ${GREEN}${VMID}${NC}
  Hostname        : ${GREEN}${CT_HOSTNAME}${NC}
  CPU Cores       : ${GREEN}${CPU}${NC}
  RAM             : ${GREEN}${RAM} MB${NC}
  Swap            : ${GREEN}${SWAP} MB${NC}
EOF
    if [ "$STORAGE_MODE" = "simple" ]; then
        cat <<EOF
  Storage Mode    : ${GREEN}Simple (root filesystem)${NC}
  Root Size       : ${GREEN}${BOOTDISK} GB${NC}
EOF
    else
        cat <<EOF
  Storage Mode    : ${YELLOW}Advanced (/opt/gitlab LV)${NC}
  Boot Disk       : ${GREEN}${BOOTDISK} GB${NC}
  Data LV         : ${GREEN}${DATA_SIZE} GB${NC} → /opt/gitlab
EOF
    fi
    cat <<EOF
  IP Address      : ${GREEN}${CT_IP}${NC}
  Gateway         : ${GREEN}${GATEWAY}${NC}
  DNS             : ${GREEN}${DNS}${NC}
  GitLab FQDN     : ${GREEN}${GITLAB_FQDN}${NC}
  GitLab URL      : ${GREEN}${GITLAB_URL}${NC}
  TLS             : ${GREEN}${tls_mode}${NC}
  GitLab Image    : ${GREEN}${GITLAB_CE_IMAGE}${NC}
  Optional stack  : ${GREEN}runner=${RUNNER_ENABLED},backup=${BACKUP_ENABLED},registry=${REGISTRY_ENABLED},pages=${PAGES_ENABLED},plantuml=${PLANTUML_ENABLED},renovate=${RENOVATE_ENABLED},pgbouncer=${PGBOUNCER_ENABLED}${NC}
  Storage VG      : ${GREEN}${LVM_VG}${NC}
  Rootfs storage  : ${GREEN}${ROOTFS_STORAGE}${NC}
  Network Bridge  : ${GREEN}${BRIDGE}${NC}
  Template        : ${GREEN}${TEMPLATE}${NC}
  Config File     : ${GREEN}${CONFIG_FILE:-<defaults>}${NC}
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
EOF
}

print_final_summary() {
    cat <<EOF

${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${GREEN}           GitLab Docker Compose Installation Successful!             ${NC}
${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${BLUE}Container:${NC}
  • ID / Hostname : ${GREEN}${VMID}${NC} / ${GREEN}${CT_HOSTNAME}${NC}
  • IP            : ${GREEN}${CT_IP}${NC}
  • GitLab URL    : ${GREEN}${GITLAB_URL}${NC}

${BLUE}GitLab login:${NC}
  • User          : ${GREEN}root${NC}
  • Password      : ${YELLOW}${GITLAB_ROOT_PASSWORD}${NC}
  ${RED}Change the password after first login.${NC}

${BLUE}Docker Compose (inside CT):${NC}
  ${GREEN}pct exec ${VMID} -- bash -c 'cd /opt/gitlab && docker compose ps'${NC}
  ${GREEN}pct exec ${VMID} -- bash -c 'cd /opt/gitlab && docker compose logs -f gitlab'${NC}

${BLUE}Next steps:${NC}
  1. Point DNS A/AAAA for ${GITLAB_FQDN} to ${CT_IP%%/*}
  2. Open ${GITLAB_URL}
  3. SSH Git clone: port ${GREEN}2424${NC}

${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
EOF
}

write_install_log() {
    local log_file="/var/log/gitlab-docker-install-${VMID}.log"
    umask 077
    cat >"${log_file}" <<EOF
GitLab Docker Compose Installation Log
======================================
Date: $(date)
Container ID: ${VMID}
Hostname: ${CT_HOSTNAME}
IP: ${CT_IP}
GitLab URL: ${GITLAB_URL}
GitLab FQDN: ${GITLAB_FQDN}
GitLab root password: ${GITLAB_ROOT_PASSWORD}
Postgres password: ${POSTGRES_PASSWORD}
Config: ${CONFIG_FILE:-<defaults>}
EOF
    chmod 600 "${log_file}"
    log_info "Installation log saved to: ${log_file}"
}

show_usage() {
    cat <<EOF
GitLab Docker Compose on Proxmox LXC v${SCRIPT_VERSION}

Usage: $0 [OPTIONS]

Interactive (no arguments):
    $0

Non-interactive (simple storage):
    $0 --config scripts/pve-gitlab.conf \\
       --vmid 110 --hostname gitlab --cpu 4 --ram 8192 \\
       --storage-mode simple --rootfs-size 50 \\
       --ip 192.168.1.110/24 --gateway 192.168.1.1 --dns 8.8.8.8 \\
       --rootfs-storage local-lvm --lvm-vg pve

Non-interactive (advanced: separate /opt/gitlab LV):
    $0 --config scripts/pve-gitlab.conf \\
       --vmid 120 --hostname gitlab --cpu 4 --ram 8192 \\
       --storage-mode advanced --bootdisk 20 --data-size 100 \\
       --ip 192.168.1.120/24 --gateway 192.168.1.1 --dns 8.8.8.8 \\
       --rootfs-storage local-lvm --lvm-vg pve

Required (non-interactive):
    --vmid, --hostname, --cpu, --ram, --ip, --gateway, --dns
    --rootfs-storage and/or --lvm-vg (or legacy --storage; see below)
    simple: --rootfs-size
    advanced: --bootdisk, --data-size

GitLab / TLS (optional CLI overrides; else from --config):
    --config <file>     Shell config (see scripts/pve-gitlab.conf.example)
    --fqdn <name>       GitLab FQDN (e.g. gitlab.example.com)
    --acme true|false   Traefik ACME DNS-01 (needs Hetzner API token in config)

Other:
    --swap <MiB>        LXC swap (default: 512; 0 = no swap)
    --rootfs-storage <id> Proxmox storage for CT rootfs (e.g. local-lvm)
    --lvm-vg <name>       LVM VG for advanced mode data LV (default: pve)
    --storage <id|vg>     Shorthand: Proxmox storage ID or LVM VG name (auto-map)
    --bridge <name>     Network bridge (default: vmbr0)
    --force-cleanup     Remove existing CT/LV for VMID
    --help              Show this help

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --vmid) VMID="$2"; INTERACTIVE=false; shift 2 ;;
        --hostname) CT_HOSTNAME="$2"; shift 2 ;;
        --cpu) CPU="$2"; shift 2 ;;
        --ram) RAM="$2"; shift 2 ;;
        --swap) SWAP="$2"; shift 2 ;;
        --storage-mode) STORAGE_MODE=$(echo "$2" | tr '[:upper:]' '[:lower:]' | xargs); shift 2 ;;
        --rootfs-size) BOOTDISK="$2"; shift 2 ;;
        --bootdisk) BOOTDISK="$2"; shift 2 ;;
        --data-size) DATA_SIZE="$2"; shift 2 ;;
        --datadisk) DATA_SIZE="$2"; log_warn "--datadisk is deprecated; use --data-size"; shift 2 ;;
        --ip) CT_IP="$2"; shift 2 ;;
        --gateway) GATEWAY="$2"; shift 2 ;;
        --dns) DNS="$2"; shift 2 ;;
        --storage) STORAGE="$2"; shift 2 ;;
        --rootfs-storage) ROOTFS_STORAGE="$2"; shift 2 ;;
        --lvm-vg) LVM_VG="$2"; shift 2 ;;
        --bridge) BRIDGE="$2"; shift 2 ;;
        --config) CONFIG_FILE="$2"; shift 2 ;;
        --fqdn) CLI_FQDN="$2"; shift 2 ;;
        --acme) CLI_ACME="$2"; shift 2 ;;
        --force-cleanup) FORCE_CLEANUP=true; shift ;;
        --help|-h) show_usage ;;
        *) err "Unknown option: $1 (use --help)" ;;
    esac
done

log_step "Running pre-flight checks..."
[[ $EUID -eq 0 ]] || err "Run as root on the Proxmox host."
command -v pct >/dev/null || err "This script requires Proxmox VE (pct)."
command -v openssl >/dev/null || err "openssl is required."
log_info "Proxmox environment OK"

pve_storage_exists() {
    pvesm status -storage "$1" >/dev/null 2>&1
}

find_rootfs_storage_for_vg() {
    local vg="$1"
    local sid=""
    if [[ -f /etc/pve/storage.cfg ]]; then
        sid="$(awk -v vg="${vg}" '
            /^[a-z][a-z0-9]*: / {
                line=$0
                sub(/^[^:]*: /, "", line)
                split(line, parts, " ")
                sid=parts[1]
                vgname=""
                content=""
            }
            /^[[:space:]]+vgname / { vgname=$2 }
            /^[[:space:]]+content / { content=$0 }
            vgname == vg && content ~ /rootdir/ { print sid; exit }
        ' /etc/pve/storage.cfg 2>/dev/null || true)"
    fi
    if [[ -z "${sid}" ]] && pve_storage_exists "local-lvm" && [[ "${vg}" == "pve" ]]; then
        sid="local-lvm"
    fi
    printf '%s' "${sid}"
}

resolve_storage_settings() {
    if [[ -n "${ROOTFS_STORAGE}" && -n "${LVM_VG}" ]]; then
        :
    elif [[ -n "${STORAGE}" ]]; then
        if pve_storage_exists "${STORAGE}"; then
            ROOTFS_STORAGE="${STORAGE}"
            LVM_VG="${LVM_VG:-pve}"
            log_info "Using --storage as Proxmox rootfs storage: ${ROOTFS_STORAGE}"
        elif vgs "${STORAGE}" >/dev/null 2>&1; then
            LVM_VG="${STORAGE}"
            ROOTFS_STORAGE="$(find_rootfs_storage_for_vg "${STORAGE}")"
            log_info "Mapped LVM VG '${LVM_VG}' to rootfs storage '${ROOTFS_STORAGE:-<none>}'"
        else
            err "'${STORAGE}' is neither a Proxmox storage (pvesm) nor an LVM VG (vgs)."
        fi
    elif [[ -n "${ROOTFS_STORAGE}" ]]; then
        LVM_VG="${LVM_VG:-pve}"
    elif [[ -n "${LVM_VG}" ]]; then
        ROOTFS_STORAGE="$(find_rootfs_storage_for_vg "${LVM_VG}")"
    else
        LVM_VG="pve"
        ROOTFS_STORAGE="$(find_rootfs_storage_for_vg pve)"
    fi

    if [[ -z "${ROOTFS_STORAGE}" ]]; then
        err "No Proxmox rootdir storage found for VG '${LVM_VG}'. Set --rootfs-storage (e.g. local-lvm)."
    fi
    pve_storage_exists "${ROOTFS_STORAGE}" || err "Proxmox storage '${ROOTFS_STORAGE}' not found. Run: pvesm status -content rootdir"
    vgs "${LVM_VG}" >/dev/null 2>&1 || err "LVM VG '${LVM_VG}' not found. Run: vgs"
}

log_step "Updating Proxmox host..."
apt update -qq || err "apt update failed"
DEBIAN_FRONTEND=noninteractive apt upgrade -y -qq || err "apt upgrade failed"
DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y -qq || log_warn "dist-upgrade had warnings"
apt autoremove -y -qq
apt autoclean -qq

log_step "Detecting Debian LXC template..."
TEMPLATE=$(pvesm list local 2>/dev/null | awk '/vztmpl\/debian-13-standard/ {print $1; exit}')
if [[ -z "${TEMPLATE}" ]]; then
    TEMPLATE=$(pvesm list local 2>/dev/null | awk '/vztmpl\/debian-12-standard/ {print $1; exit}')
fi
if [[ -z "${TEMPLATE}" ]]; then
    log_warn "Debian template not found locally, trying pveam..."
    pveam update || true
  TEMPLATE_NAME=$(pveam available --section system 2>/dev/null \
        | awk '{print $2}' \
        | grep -E '^debian-(13|12)-standard_.*\.tar\.zst$' \
        | sort -V \
        | tail -n1)
    if [[ -n "${TEMPLATE_NAME}" ]]; then
        pveam download local "${TEMPLATE_NAME}" || err "pveam download failed for ${TEMPLATE_NAME}"
        TEMPLATE=$(pvesm list local 2>/dev/null | awk '/vztmpl\/debian-(13|12)-standard/ {print $1; exit}')
    fi
fi
[[ -n "${TEMPLATE}" ]] || err "No debian-13/12-standard template. Run: pveam update && pveam available --section system"
log_info "Using template: ${TEMPLATE}"

log_step "Collecting parameters..."
if [[ "${INTERACTIVE}" == "true" ]]; then
    DEFAULT_VMID=$(pvesh get /cluster/nextid 2>/dev/null || echo "110")
    read -rp "Container ID [${DEFAULT_VMID}]: " VMID
    VMID="${VMID:-$DEFAULT_VMID}"
    read -rp "Hostname [gitlab]: " CT_HOSTNAME
    CT_HOSTNAME="${CT_HOSTNAME:-gitlab}"
    read -rp "CPU cores [4]: " CPU
    CPU="${CPU:-4}"
    read -rp "RAM MB [8192]: " RAM
    RAM="${RAM:-8192}"
    read -rp "Swap MB [512]: " SWAP
    SWAP="${SWAP:-512}"
    echo ""
    echo "Storage: 1=simple (recommended), 2=advanced (/opt/gitlab LV)"
    read -rp "Mode [1]: " MODE_CHOICE
    MODE_CHOICE="${MODE_CHOICE:-1}"
    if [[ "${MODE_CHOICE}" == "2" ]]; then
        STORAGE_MODE="advanced"
        read -rp "Boot disk GB [20]: " BOOTDISK
        BOOTDISK="${BOOTDISK:-20}"
        read -rp "Data LV GB (/opt/gitlab) [100]: " DATA_SIZE
        DATA_SIZE="${DATA_SIZE:-100}"
    else
        STORAGE_MODE="simple"
        read -rp "Root filesystem GB [50]: " BOOTDISK
        BOOTDISK="${BOOTDISK:-50}"
    fi
    read -rp "Container IP (CIDR): " CT_IP
    DEFAULT_GATEWAY=$(ip route | awk '/default/ {print $3; exit}')
    read -rp "Gateway [${DEFAULT_GATEWAY}]: " GATEWAY
    GATEWAY="${GATEWAY:-$DEFAULT_GATEWAY}"
    DEFAULT_DNS=$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf)
    read -rp "DNS [${DEFAULT_DNS}]: " DNS
    DNS="${DNS:-$DEFAULT_DNS}"
    read -rp "Proxmox rootfs storage [local-lvm]: " ROOTFS_INPUT
    ROOTFS_STORAGE="${ROOTFS_INPUT:-local-lvm}"
    read -rp "LVM volume group [pve]: " LVM_INPUT
    LVM_VG="${LVM_INPUT:-pve}"
    read -rp "Bridge [vmbr0]: " BRIDGE_INPUT
    BRIDGE="${BRIDGE_INPUT:-vmbr0}"
    DEFAULT_CONFIG="${SCRIPT_DIR}/pve-gitlab.conf"
    if [[ -f "${DEFAULT_CONFIG}" ]]; then
        CONFIG_FILE="${DEFAULT_CONFIG}"
        log_info "Using config: ${CONFIG_FILE}"
    else
        read -rp "Config file [${SCRIPT_DIR}/pve-gitlab.conf.example]: " CONFIG_INPUT
        CONFIG_FILE="${CONFIG_INPUT:-${SCRIPT_DIR}/pve-gitlab.conf.example}"
    fi
else
    if [[ "${STORAGE_MODE}" == "simple" ]]; then
        [[ -n "${VMID}" && -n "${CT_HOSTNAME}" && -n "${CPU}" && -n "${RAM}" && -n "${BOOTDISK}" && \
           -n "${CT_IP}" && -n "${GATEWAY}" && -n "${DNS}" ]] || \
            err "Simple mode: missing required options (see --help)"
    else
        [[ -n "${VMID}" && -n "${CT_HOSTNAME}" && -n "${CPU}" && -n "${RAM}" && -n "${BOOTDISK}" && \
           -n "${DATA_SIZE}" && -n "${CT_IP}" && -n "${GATEWAY}" && -n "${DNS}" ]] || \
            err "Advanced mode: missing required options (see --help)"
    fi
fi

resolve_storage_settings

SWAP="${SWAP:-512}"
if ! [[ "${SWAP}" =~ ^[0-9]+$ ]]; then
    err "Invalid --swap: must be non-negative integer (MiB)"
fi

gitlab_docker_config_load || err "Invalid GitLab Docker config"
if [[ -n "${CLI_FQDN}" ]]; then
    GITLAB_FQDN="${CLI_FQDN}"
    if [[ "${TRAEFIK_ACME_ENABLED}" == "true" ]]; then
        EXTERNAL_URL_SCHEME="https"
        GITLAB_URL="https://${GITLAB_FQDN}"
    else
        EXTERNAL_URL_SCHEME="http"
        GITLAB_URL="http://${GITLAB_FQDN}"
    fi
fi
if [[ -n "${CLI_ACME}" ]]; then
    case "${CLI_ACME}" in
        true|1|yes) TRAEFIK_ACME_ENABLED=true; EXTERNAL_URL_SCHEME="https"; GITLAB_URL="https://${GITLAB_FQDN}" ;;
        false|0|no) TRAEFIK_ACME_ENABLED=false; EXTERNAL_URL_SCHEME="http"; GITLAB_URL="http://${GITLAB_FQDN}" ;;
        *) err "Invalid --acme value: ${CLI_ACME}" ;;
    esac
    gitlab_docker_config_validate || err "ACME config invalid"
fi

log_step "Validating..."
[[ "${CT_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]] || err "Invalid IP CIDR: ${CT_IP}"

LV_DATA="vm-${VMID}-gitlab-data"
EXISTING_CONTAINER=false
EXISTING_LVS=()
pct status "${VMID}" >/dev/null 2>&1 && EXISTING_CONTAINER=true
lvdisplay "/dev/${LVM_VG}/${LV_DATA}" >/dev/null 2>&1 && EXISTING_LVS+=("${LV_DATA}")
for legacy in "vm-${VMID}-gitlab-etc" "vm-${VMID}-gitlab-log" "vm-${VMID}-gitlab-opt"; do
    lvdisplay "/dev/${LVM_VG}/${legacy}" >/dev/null 2>&1 && EXISTING_LVS+=("${legacy}")
done

if [[ "${EXISTING_CONTAINER}" == "true" || ${#EXISTING_LVS[@]} -gt 0 ]]; then
    log_warn "Existing resources for VMID ${VMID}:"
    [[ "${EXISTING_CONTAINER}" == "true" ]] && echo "  • container ${VMID}"
    for lv in "${EXISTING_LVS[@]}"; do echo "  • LV ${lv}"; done
    SHOULD_CLEANUP=false
    if [[ "${INTERACTIVE}" == "true" ]]; then
        read -rp "Cleanup? (yes/no): " CLEANUP_CONFIRM
        [[ "${CLEANUP_CONFIRM}" == "yes" ]] && SHOULD_CLEANUP=true
    elif [[ "${FORCE_CLEANUP}" == "true" ]]; then
        SHOULD_CLEANUP=true
    else
        err "Resources exist. Use --force-cleanup or another VMID."
    fi
    if [[ "${SHOULD_CLEANUP}" == "true" ]]; then
        pct stop "${VMID}" 2>/dev/null || true
        pct destroy "${VMID}" 2>/dev/null || true
        for lv in "${EXISTING_LVS[@]}"; do
            lvremove -f "/dev/${LVM_VG}/${lv}" 2>/dev/null || true
        done
        log_info "Cleanup complete"
    else
        err "Aborted."
    fi
fi

log_step "Configuration summary"
print_config_summary
if [[ "${INTERACTIVE}" == "true" ]]; then
    read -rp "Proceed? (yes/no): " CONFIRM
    [[ "${CONFIRM}" == "yes" ]] || exit 0
fi

log_step "Creating LXC ${VMID}..."
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
FINGERPRINT="# GitLab Docker Compose (pve-secure-gitlab-lxc v${SCRIPT_VERSION})
Installed: ${INSTALL_DATE}
FQDN: ${GITLAB_FQDN}
Stack: Traefik + GitLab CE + PostgreSQL under /opt/gitlab"

pct create "${VMID}" "${TEMPLATE}" \
    --hostname "${CT_HOSTNAME}" \
    --cores "${CPU}" \
    --memory "${RAM}" \
    --swap "${SWAP}" \
    --rootfs "${ROOTFS_STORAGE}:${BOOTDISK}" \
    --net0 "name=eth0,bridge=${BRIDGE},ip=${CT_IP},gw=${GATEWAY},type=veth" \
    --nameserver "${DNS}" \
    --unprivileged 1 \
    --features nesting=1,keyctl=1 \
    --onboot 1 \
    --protection 0 \
    --description "${FINGERPRINT}" || err "pct create failed"

if [[ "${STORAGE_MODE}" == "advanced" ]]; then
    log_step "Advanced storage: LV for /opt/gitlab"
    LV_PATH="/dev/${LVM_VG}/${LV_DATA}"
    if ! lvdisplay "${LV_PATH}" >/dev/null 2>&1; then
        lvcreate -L "${DATA_SIZE}G" -n "${LV_DATA}" "${LVM_VG}" || err "lvcreate failed"
    fi
    fs_type=$(blkid -o value -s TYPE "${LV_PATH}" 2>/dev/null || true)
    if [[ -z "${fs_type}" ]]; then
        wipefs -a "${LV_PATH}" 2>/dev/null || true
        mkfs.ext4 -F "${LV_PATH}" >/dev/null || err "mkfs.ext4 failed"
    elif [[ "${fs_type}" != "ext4" ]]; then
        err "LV ${LV_PATH} is ${fs_type}, expected ext4"
    fi
    pct set "${VMID}" -mp0 "${LV_PATH},mp=/opt/gitlab,backup=0" || err "pct set mount failed"
    mkdir -p /tmp/gitlab-mount-opt
    mount "${LV_PATH}" /tmp/gitlab-mount-opt
    chown -R 100000:100000 /tmp/gitlab-mount-opt
    umount /tmp/gitlab-mount-opt
    rmdir /tmp/gitlab-mount-opt
else
    log_info "Simple storage: /opt/gitlab on root filesystem"
fi

log_step "Starting container..."
pct start "${VMID}" || err "pct start failed"
sleep 5
pct status "${VMID}" | grep -q running || err "Container not running"

log_step "Checking container DNS..."
if ! pct exec "${VMID}" -- getent hosts auth.docker.io registry-1.docker.io >/dev/null 2>&1; then
    err "Container DNS failed (nameserver: ${DNS}). Gateway/router DNS may not respond from CTs — retry with --dns 8.8.8.8 or: pct set ${VMID} -nameserver 8.8.8.8"
fi

log_step "Deploying GitLab Docker stack..."
chmod +x "${SCRIPT_DIR}/lib/gitlab-docker-bootstrap.sh" 2>/dev/null || true
TMP_TAR="/tmp/gitlab-docker-core-${VMID}.tar.gz"
TMP_ENV="/tmp/pve-gitlab-${VMID}.env"
tar -C "${SCRIPT_DIR}/templates/gitlab-docker-core" -czf "${TMP_TAR}" .
gitlab_docker_config_write_env_file "${TMP_ENV}"

pct push "${VMID}" "${SCRIPT_DIR}/lib/gitlab-docker-bootstrap.sh" /root/gitlab-docker-bootstrap.sh
pct push "${VMID}" "${TMP_TAR}" /root/gitlab-docker-core.tar.gz
pct push "${VMID}" "${TMP_ENV}" /root/pve-gitlab.env
rm -f "${TMP_TAR}" "${TMP_ENV}"

pct exec "${VMID}" -- bash -c '
    chmod +x /root/gitlab-docker-bootstrap.sh
    mkdir -p /root/gitlab-docker-core
    tar -xzf /root/gitlab-docker-core.tar.gz -C /root/gitlab-docker-core
    ENV_FILE=/root/pve-gitlab.env /root/gitlab-docker-bootstrap.sh
' || err "Bootstrap failed — check: pct exec '"${VMID}"' -- tail -80 /var/log/gitlab-docker-bootstrap.log
If DNS timeout on auth.docker.io: pct set ${VMID} -nameserver 8.8.8.8 then re-run bootstrap or docker compose pull in /opt/gitlab"

log_step "Waiting for Docker services..."
for i in $(seq 1 60); do
    if pct exec "${VMID}" -- bash -c 'cd /opt/gitlab && docker compose ps --format json 2>/dev/null' | grep -q '"State":"running"'; then
        break
    fi
    sleep 10
done

log_step "Installation complete"
print_final_summary
write_install_log
exit 0
