#!/usr/bin/env bash
# Compare pinned GitLab CE, Traefik and PostgreSQL Docker image tags (Terraform) against Docker Hub.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT}/terraform"
VARS_FILE="${TF_DIR}/variables.tf"
TFVARS_FILE="${TF_DIR}/terraform.tfvars"

EXIT_SUCCESS=0
EXIT_OUTDATED=1
EXIT_ERROR=2

GITLAB_CE_VERSION_FILTER="${GITLAB_CE_VERSION_FILTER:-^[0-9]+\\.[0-9]+\\.[0-9]+-ce\\.0$}"
TRAEFIK_VERSION_FILTER="${TRAEFIK_VERSION_FILTER:-^v3\\.[0-9]+\\.[0-9]+$}"
if [[ -z "${POSTGRES_MAJOR_FILTER:-}" ]]; then
  POSTGRES_MAJOR_FILTER='^(1[3-7])(\.[0-9]+){0,2}(-[a-zA-Z0-9._-]+)?$'
fi
LOG_LEVEL="${CHECK_IMAGES_DEBUG:-warning}"
CACHE_DIR="${CHECK_IMAGES_CACHE_DIR:-${HOME}/.docker-hub-cache}"
CACHE_TTL="${CHECK_IMAGES_CACHE_TTL:-3600}"
STRICT=0

log() {
  local level="$1"
  shift
  case "${level}" in
    debug)
      if [[ "${LOG_LEVEL}" == "debug" ]]; then
        echo "[debug] $*" >&2
      fi
      ;;
    warning)
      if [[ "${LOG_LEVEL}" == "debug" || "${LOG_LEVEL}" == "warning" ]]; then
        echo "[warning] $*" >&2
      fi
      ;;
    error)
      echo "[error] $*" >&2
      ;;
  esac
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log error "required command not found: $1"
    exit "${EXIT_ERROR}"
  }
}

file_mtime() {
  local path="$1"
  if stat -f %m "${path}" >/dev/null 2>&1; then
    stat -f %m "${path}"
  else
    stat -c %Y "${path}"
  fi
}

cache_is_fresh() {
  local cache_file="$1"
  [[ -f "${cache_file}" ]] || return 1
  local age=$(( $(date +%s) - $(file_mtime "${cache_file}") ))
  [[ "${age}" -lt "${CACHE_TTL}" ]]
}

cache_file_for_repo() {
  local repo_path="$1"
  local safe_name="${repo_path//\//__}"
  echo "${CACHE_DIR}/${safe_name}.tags"
}

validate_var_name() {
  local var_name="$1"
  [[ "${var_name}" =~ ^[a-z_][a-z0-9_]*$ ]] || {
    log error "invalid Terraform variable name: ${var_name}"
    exit "${EXIT_ERROR}"
  }
}

validate_image() {
  local image="$1"
  [[ "${image}" =~ ^[^:]+:[^:]+$ ]] || {
    log error "invalid image format (expected repo:tag): ${image}"
    exit "${EXIT_ERROR}"
  }
}

check_dependencies() {
  require_cmd curl
  require_cmd jq
  require_cmd sort

  if ! jq -e '.' >/dev/null 2>&1 <<< '{}'; then
    log error "jq is not functional (check installation)"
    exit "${EXIT_ERROR}"
  fi
  log debug "jq version: $(jq --version 2>/dev/null || echo unknown)"

  if ! printf 'v1\nv2\n' | sort -V >/dev/null 2>&1; then
    log error "sort -V is not supported on this system"
    exit "${EXIT_ERROR}"
  fi

  mkdir -p "${CACHE_DIR}"
  log debug "cache directory: ${CACHE_DIR} (TTL ${CACHE_TTL}s)"
}

fetch_page_with_retry() {
  local url="$1"
  local repo_path="$2"
  local attempt=1
  local max_retries=3
  local page_json=""

  while [[ "${attempt}" -le "${max_retries}" ]]; do
    log debug "fetching ${repo_path} (attempt ${attempt}/${max_retries})"
    if page_json="$(curl -fsS --connect-timeout 15 --max-time 60 "${url}")"; then
      printf '%s' "${page_json}"
      return 0
    fi
    if [[ "${attempt}" -lt "${max_retries}" ]]; then
      log warning "Docker Hub API request failed for ${repo_path}, retrying in $((attempt * 2))s..."
      sleep $((attempt * 2))
    fi
    attempt=$((attempt + 1))
  done

  log error "Docker Hub API request failed permanently for ${repo_path}"
  exit "${EXIT_ERROR}"
}

fetch_docker_hub_tags() {
  local repo_path="$1"
  local cache_file
  cache_file="$(cache_file_for_repo "${repo_path}")"

  if cache_is_fresh "${cache_file}"; then
    log debug "cache hit for ${repo_path}"
    cat "${cache_file}"
    return 0
  fi

  log debug "cache miss for ${repo_path}"
  local url="https://hub.docker.com/v2/repositories/${repo_path}/tags?page_size=100"
  local page_json tags chunk
  tags=""
  while [[ -n "${url}" ]]; do
    page_json="$(fetch_page_with_retry "${url}" "${repo_path}")"
    chunk="$(echo "${page_json}" | jq -r '.results[].name')"
    tags="${tags}"$'\n'"${chunk}"
    url="$(echo "${page_json}" | jq -r '.next // empty')"
  done

  printf '%s\n' "${tags}" | sed '/^$/d' | sort -u > "${cache_file}.tmp"
  mv "${cache_file}.tmp" "${cache_file}"
  log debug "cached ${repo_path} tag list ($(wc -l < "${cache_file}" | tr -d ' ') tags)"
  cat "${cache_file}"
}

latest_gitlab_ce_tag() {
  fetch_docker_hub_tags "gitlab/gitlab-ce" \
    | grep -E "${GITLAB_CE_VERSION_FILTER}" \
    | sort -V \
    | tail -1 \
    || true
}

latest_traefik_v3_tag() {
  fetch_docker_hub_tags "library/traefik" \
    | grep -E "${TRAEFIK_VERSION_FILTER}" \
    | sort -V \
    | tail -1 \
    || true
}

latest_postgres_supported_major_tag() {
  fetch_docker_hub_tags "library/postgres" \
    | grep -E "${POSTGRES_MAJOR_FILTER}" \
    | sort -V \
    | tail -1 \
    || true
}

read_default() {
  local var_name="$1"
  sed -n "/^variable \"${var_name}\"/,/^}/p" "${VARS_FILE}" \
    | grep -m1 'default[[:space:]]*=' \
    | sed -E 's/.*default[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/'
}

read_tfvars_override() {
  local var_name="$1"
  if [[ ! -f "${TFVARS_FILE}" ]]; then
    return 1
  fi
  local line
  line="$(grep -E "^[[:space:]]*${var_name}[[:space:]]*=" "${TFVARS_FILE}" 2>/dev/null | head -1 || true)"
  [[ -n "${line}" ]] || return 1
  echo "${line}" | sed -E 's/^[^=]*=[[:space:]]*"([^"]+)".*/\1/'
}

effective_image() {
  local var_name="$1"
  validate_var_name "${var_name}"
  local image override
  if override="$(read_tfvars_override "${var_name}" 2>/dev/null)"; then
    image="${override}"
  else
    image="$(read_default "${var_name}")"
  fi
  [[ -n "${image}" ]] || {
    log error "no value found for variable ${var_name}"
    exit "${EXIT_ERROR}"
  }
  validate_image "${image}"
  echo "${image}"
}

compare_tags() {
  local pinned_tag="$1"
  local latest_tag="$2"
  if [[ "${pinned_tag}" == "${latest_tag}" ]]; then
    echo "UP TO DATE"
    return "${EXIT_SUCCESS}"
  fi
  local newer
  newer="$(printf '%s\n%s\n' "${pinned_tag}" "${latest_tag}" | sort -V | tail -1)"
  if [[ "${newer}" == "${latest_tag}" && "${pinned_tag}" != "${latest_tag}" ]]; then
    echo "UPDATE AVAILABLE"
    return "${EXIT_OUTDATED}"
  fi
  echo "PINNED AHEAD OF DOCKER HUB FILTER"
  return "${EXIT_SUCCESS}"
}

print_image_report() {
  local name="$1"
  local pinned_image="$2"
  local latest_tag="$3"
  local filter_desc="$4"
  local pinned_tag="${pinned_image#*:}"
  local latest_image="${pinned_image%:*}:${latest_tag}"
  local status
  local rc=0

  status="$(compare_tags "${pinned_tag}" "${latest_tag}")" || rc=$?

  echo "${name}"
  echo "  pinned:  ${pinned_image}"
  echo "  latest:  ${latest_image}"
  echo "  filter:  ${filter_desc}"
  echo "  status:  ${status}"
  echo
  return "${rc}"
}

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Compare pinned Docker image tags with latest on Docker Hub.

Options:
  --strict     Exit with code 1 if images are outdated
  --help       Show this help message

Environment variables:
  CHECK_IMAGES_STRICT         Set to "1" to enable strict mode
  CHECK_IMAGES_DEBUG          Log level: debug, warning (default), error
  CHECK_IMAGES_CACHE_DIR      Cache directory (default: ~/.docker-hub-cache)
  CHECK_IMAGES_CACHE_TTL      Cache TTL in seconds (default: 3600)
  GITLAB_CE_VERSION_FILTER    Regex for GitLab CE tags
  TRAEFIK_VERSION_FILTER      Regex for Traefik tags
  POSTGRES_MAJOR_FILTER       Regex for PostgreSQL tags (majors 13-17)

Exit codes:
  0  Success (up to date, or outdated without --strict)
  1  Outdated images (only with --strict / CHECK_IMAGES_STRICT=1)
  2  Technical error (dependencies, API, validation)
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        show_help
        exit "${EXIT_SUCCESS}"
        ;;
      --strict)
        STRICT=1
        shift
        ;;
      *)
        log error "unknown option: $1"
        show_help >&2
        exit "${EXIT_ERROR}"
        ;;
    esac
  done

  if [[ "${CHECK_IMAGES_STRICT:-0}" == "1" ]]; then
    STRICT=1
  fi
}

main() {
  parse_args "$@"
  check_dependencies

  [[ -f "${VARS_FILE}" ]] || {
    log error "${VARS_FILE} not found"
    exit "${EXIT_ERROR}"
  }

  local gitlab_image traefik_image postgres_image
  gitlab_image="$(effective_image "gitlab_docker_gitlab_ce_image")"
  traefik_image="$(effective_image "gitlab_docker_traefik_image")"
  postgres_image="$(effective_image "gitlab_docker_postgres_image")"

  local tmp_gitlab tmp_traefik tmp_postgres
  tmp_gitlab="$(mktemp "${TMPDIR:-/tmp}/ci_gitlab.XXXXXX")"
  tmp_traefik="$(mktemp "${TMPDIR:-/tmp}/ci_traefik.XXXXXX")"
  tmp_postgres="$(mktemp "${TMPDIR:-/tmp}/ci_postgres.XXXXXX")"

  latest_gitlab_ce_tag > "${tmp_gitlab}" &
  local pid_gitlab=$!
  latest_traefik_v3_tag > "${tmp_traefik}" &
  local pid_traefik=$!
  latest_postgres_supported_major_tag > "${tmp_postgres}" &
  local pid_postgres=$!

  wait "${pid_gitlab}" "${pid_traefik}" "${pid_postgres}"

  local gitlab_latest traefik_latest postgres_latest
  gitlab_latest="$(cat "${tmp_gitlab}")"
  traefik_latest="$(cat "${tmp_traefik}")"
  postgres_latest="$(cat "${tmp_postgres}")"
  rm -f "${tmp_gitlab}" "${tmp_traefik}" "${tmp_postgres}"

  log debug "parallel API lookups completed"

  [[ -n "${gitlab_latest}" ]] || {
    log error "no GitLab CE tags matched filter on Docker Hub: ${GITLAB_CE_VERSION_FILTER}"
    exit "${EXIT_ERROR}"
  }
  [[ -n "${traefik_latest}" ]] || {
    log error "no Traefik tags matched filter on Docker Hub: ${TRAEFIK_VERSION_FILTER}"
    exit "${EXIT_ERROR}"
  }
  [[ -n "${postgres_latest}" ]] || {
    log error "no PostgreSQL tags matched filter on Docker Hub: ${POSTGRES_MAJOR_FILTER}"
    exit "${EXIT_ERROR}"
  }

  echo "Image checks (Docker Hub vs Terraform pin)"
  echo

  local outdated=0
  print_image_report "gitlab/gitlab-ce" "${gitlab_image}" "${gitlab_latest}" "${GITLAB_CE_VERSION_FILTER}" || outdated=1
  print_image_report "traefik" "${traefik_image}" "${traefik_latest}" "${TRAEFIK_VERSION_FILTER}" || outdated=1
  print_image_report "postgres" "${postgres_image}" "${postgres_latest}" "${POSTGRES_MAJOR_FILTER}" || outdated=1

  if [[ "${outdated}" -eq 1 ]]; then
    echo "Hint: update gitlab_docker_gitlab_ce_image / gitlab_docker_traefik_image / gitlab_docker_postgres_image in"
    echo "      terraform/variables.tf or terraform/terraform.tfvars, then plan/apply."
    if [[ "${STRICT}" -eq 1 ]]; then
      exit "${EXIT_OUTDATED}"
    fi
  fi

  exit "${EXIT_SUCCESS}"
}

main "$@"
