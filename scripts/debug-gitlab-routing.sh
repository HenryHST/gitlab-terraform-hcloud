#!/usr/bin/env bash
# Collect GitLab/Traefik routing diagnostics → NDJSON for debug session 672ee6.
set -euo pipefail
LOG_PATH="${DEBUG_LOG_PATH:-$(cd "$(dirname "$0")/.." && pwd)/.cursor/debug-672ee6.log}"
RUN_ID="${DEBUG_RUN_ID:-pre-fix}"
SESSION_ID="672ee6"
HOST="${1:-}"
if [[ -z "$HOST" ]]; then
  if command -v terraform >/dev/null 2>&1; then
    HOST="$(terraform -chdir="$(cd "$(dirname "$0")/.." && pwd)" output -raw server_ip 2>/dev/null || true)"
  fi
fi
FQDN="${GITLAB_FQDN:-gitlab.cicd-showcase.de}"
[[ -n "$HOST" ]] || { echo "Usage: $0 <server_ip>   or set server via terraform output" >&2; exit 1; }

log_json() {
  local hypothesis_id="$1" location="$2" message="$3" data="$4"
  local ts
  ts="$(date +%s000 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))')"
  printf '%s\n' "{\"sessionId\":\"$SESSION_ID\",\"runId\":\"$RUN_ID\",\"hypothesisId\":\"$hypothesis_id\",\"location\":\"$location\",\"message\":\"$message\",\"data\":$data,\"timestamp\":$ts}" >>"$LOG_PATH"
}

http_code() {
  curl -sS -o /dev/null -w '%{http_code}' -H "Host: $FQDN" --connect-timeout 5 "$1" 2>/dev/null || echo "000"
}

CODE_HTTP="$(http_code "http://$HOST/")"
CODE_HTTPS="$(http_code -k "https://$HOST/")"
log_json "A" "debug-gitlab-routing.sh:curl" "external_http_status" "{\"host\":\"$HOST\",\"fqdn\":\"$FQDN\",\"http\":$CODE_HTTP,\"https\":$CODE_HTTPS}"

REMOTE="$(ssh -o BatchMode=yes -o ConnectTimeout=10 "root@$HOST" bash -s "$FQDN" <<'EOS'
set -euo pipefail
FQDN="$1"
GL_HEALTH="$(docker inspect gitlab-gitlab-1 --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' 2>/dev/null || echo missing)"
ROUTER="$(docker exec traefik grep -c 'routerName\":\"gitlab@docker' /var/log/traefik/traefik.log 2>/dev/null || echo 0)"
FILTERED="$(docker exec traefik grep -c 'Filtering unhealthy or starting container' /var/log/traefik/traefik.log 2>/dev/null || echo 0)"
BACKEND="$(docker exec traefik wget -qO- --server-response --header="Host: $FQDN" http://172.31.129.254/ 2>&1 | head -1 || true)"
printf '{"gitlab_health":"%s","gitlab_router_log_hits":%s,"filter_unhealthy_log_hits":%s,"backend_probe":"%s"}' \
  "$GL_HEALTH" "$ROUTER" "$FILTERED" "$(echo "$BACKEND" | tr -d '"')"
EOS
)" || REMOTE='{"ssh_error":true}'
log_json "B" "debug-gitlab-routing.sh:ssh" "server_docker_state" "$REMOTE"

echo "Wrote diagnostics to $LOG_PATH (runId=$RUN_ID)"
echo "HTTP $CODE_HTTP / HTTPS $CODE_HTTPS for Host: $FQDN → $HOST"
