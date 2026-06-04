#!/usr/bin/env bash
# Terraform data.external: check Proxmox cluster VM ID availability via API.
# Reads JSON query on stdin; writes JSON result on stdout.
set -euo pipefail

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "{\"error\":\"required command not found: $1\"}" >&2
    exit 1
  }
}

require_cmd curl
require_cmd jq

query="$(cat)"
api_url="$(echo "$query" | jq -r '.api_url // empty')"
api_token_id="$(echo "$query" | jq -r '.api_token_id // empty')"
api_token="$(echo "$query" | jq -r '.api_token // empty')"
tls_insecure="$(echo "$query" | jq -r '.tls_insecure // "false"')"
gitlab_vmid="$(echo "$query" | jq -r '.gitlab_vmid // "0"')"
runner_vmid="$(echo "$query" | jq -r '.runner_vmid // "0"')"
check_runner="$(echo "$query" | jq -r '.check_runner // "false"')"

if [[ -z "$api_url" || -z "$api_token_id" || -z "$api_token" ]]; then
  echo '{"gitlab_available":"false","runner_available":"false","error":"missing api_url, api_token_id, or api_token"}'
  exit 0
fi

curl_args=(-sS -f -H "Authorization: PVEAPIToken=${api_token_id}=${api_token}")
if [[ "$tls_insecure" == "true" ]]; then
  curl_args+=(-k)
fi

resources_url="${api_url%/}/cluster/resources?type=vm"
response=""
if ! response="$(curl "${curl_args[@]}" "$resources_url")"; then
  echo '{"gitlab_available":"false","runner_available":"false","error":"proxmox API request failed"}'
  exit 0
fi

used_vmids="$(echo "$response" | jq -c '[.data[]? | select(.vmid != null) | .vmid]')"

gitlab_available="true"
if [[ "$gitlab_vmid" != "0" && -n "$gitlab_vmid" ]]; then
  if echo "$used_vmids" | jq -e --argjson id "$gitlab_vmid" 'index($id) != null' >/dev/null; then
    gitlab_available="false"
  fi
fi

runner_available="true"
if [[ "$check_runner" == "true" && "$runner_vmid" != "0" && -n "$runner_vmid" ]]; then
  if echo "$used_vmids" | jq -e --argjson id "$runner_vmid" 'index($id) != null' >/dev/null; then
    runner_available="false"
  fi
fi

jq -n \
  --arg gitlab_available "$gitlab_available" \
  --arg runner_available "$runner_available" \
  --argjson used_vmids "$used_vmids" \
  '{gitlab_available: $gitlab_available, runner_available: $runner_available, used_vmids: ($used_vmids | map(tostring) | join(","))}'
