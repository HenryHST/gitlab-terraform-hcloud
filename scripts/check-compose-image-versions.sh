#!/usr/bin/env bash
# Compare pinned GitLab CE and Traefik Docker image tags (Terraform) against Docker Hub.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT}/terraform"
VARS_FILE="${TF_DIR}/variables.tf"
TFVARS_FILE="${TF_DIR}/terraform.tfvars"

STRICT=0
if [[ "${CHECK_IMAGES_STRICT:-0}" == "1" ]] || [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 2
  }
}

require_cmd curl
require_cmd jq
require_cmd sort

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
  local override
  if override="$(read_tfvars_override "${var_name}" 2>/dev/null)"; then
    echo "${override}"
  else
    read_default "${var_name}"
  fi
}

fetch_docker_hub_tags() {
  local repo_path="$1"
  local url="https://hub.docker.com/v2/repositories/${repo_path}/tags?page_size=100"
  local page_json tags chunk
  tags=""
  while [[ -n "${url}" ]]; do
    page_json="$(curl -fsS --connect-timeout 15 --max-time 60 "${url}")" || {
      echo "error: Docker Hub API request failed for ${repo_path}" >&2
      exit 2
    }
    chunk="$(echo "${page_json}" | jq -r '.results[].name')"
    tags="${tags}"$'\n'"${chunk}"
    url="$(echo "${page_json}" | jq -r '.next // empty')"
  done
  echo "${tags}" | sed '/^$/d' | sort -u
}

latest_gitlab_ce_tag() {
  fetch_docker_hub_tags "gitlab/gitlab-ce" \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+-ce\.0$' \
    | sort -V \
    | tail -1
}

latest_traefik_v3_tag() {
  fetch_docker_hub_tags "library/traefik" \
    | grep -E '^v3\.[0-9]+\.[0-9]+$' \
    | sort -V \
    | tail -1
}

compare_tags() {
  local pinned_tag="$1"
  local latest_tag="$2"
  if [[ "${pinned_tag}" == "${latest_tag}" ]]; then
    echo "UP TO DATE"
    return 0
  fi
  local newer
  newer="$(printf '%s\n%s\n' "${pinned_tag}" "${latest_tag}" | sort -V | tail -1)"
  if [[ "${newer}" == "${latest_tag}" && "${pinned_tag}" != "${latest_tag}" ]]; then
    echo "UPDATE AVAILABLE"
    return 1
  fi
  echo "PINNED AHEAD OF DOCKER HUB FILTER"
  return 0
}

print_image_report() {
  local name="$1"
  local pinned_image="$2"
  local latest_tag="$3"
  local pinned_tag="${pinned_image#*:}"
  local latest_image="${pinned_image%:*}:${latest_tag}"
  local status
  local rc=0

  status="$(compare_tags "${pinned_tag}" "${latest_tag}")" || rc=$?

  echo "${name}"
  echo "  pinned:  ${pinned_image}"
  echo "  latest:  ${latest_image}"
  if [[ "${name}" == "traefik" ]]; then
    echo "  filter:  v3.x tags only"
  else
    echo "  filter:  *-ce.0 release tags"
  fi
  echo "  status:  ${status}"
  echo
  return "${rc}"
}

main() {
  [[ -f "${VARS_FILE}" ]] || {
    echo "error: ${VARS_FILE} not found" >&2
    exit 2
  }

  local gitlab_image traefik_image
  gitlab_image="$(effective_image "gitlab_docker_gitlab_ce_image")"
  traefik_image="$(effective_image "gitlab_docker_traefik_image")"

  local gitlab_latest traefik_latest
  gitlab_latest="$(latest_gitlab_ce_tag)"
  traefik_latest="$(latest_traefik_v3_tag)"

  [[ -n "${gitlab_latest}" ]] || {
    echo "error: no GitLab CE tags matched *-ce.0 on Docker Hub" >&2
    exit 2
  }
  [[ -n "${traefik_latest}" ]] || {
    echo "error: no Traefik v3.x tags found on Docker Hub" >&2
    exit 2
  }

  echo "Image checks (Docker Hub vs Terraform pin)"
  echo

  local outdated=0
  print_image_report "gitlab/gitlab-ce" "${gitlab_image}" "${gitlab_latest}" || outdated=1
  print_image_report "traefik" "${traefik_image}" "${traefik_latest}" || outdated=1

  if [[ "${outdated}" -eq 1 ]]; then
    echo "Hint: update gitlab_docker_gitlab_ce_image / gitlab_docker_traefik_image in"
    echo "      terraform/variables.tf or terraform/terraform.tfvars, then plan/apply."
    if [[ "${STRICT}" -eq 1 ]]; then
      exit 1
    fi
  fi
}

main "$@"
