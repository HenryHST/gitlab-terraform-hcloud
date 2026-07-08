#!/usr/bin/env bash
set -euo pipefail

VMID="${1:-}"
REQUEST_ID="${2:-}"
LOG_PATH="/Users/henry/Projects/gitlab-terraform-hcloud/.cursor/debug-672ee6.log"
SESSION_ID="672ee6"
RUN_ID="ct-login-debug"

if [[ -z "${VMID}" ]]; then
    echo "usage: $0 <vmid> [request_id]" >&2
    exit 2
fi

json_escape() {
    local s="${1:-}"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "${s}"
}

write_log() {
    local hypothesis_id="$1" location="$2" message="$3" data_json="$4"
    local ts
    ts=$(($(date +%s) * 1000))
    printf '{"sessionId":"%s","runId":"%s","hypothesisId":"%s","location":"%s","message":"%s","data":%s,"timestamp":%s}\n' \
        "${SESSION_ID}" "${RUN_ID}" "${hypothesis_id}" "${location}" "${message}" "${data_json}" "${ts}" >>"${LOG_PATH}"
}

container_state="$(pct status "${VMID}" 2>/dev/null || true)"
compose_states="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose ps --format json" 2>/dev/null || true)"
postgres_ready="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose exec -T postgres pg_isready -U gitlab -d gitlabhq_production" 2>/dev/null || true)"
gitlab_rb_exists="$(pct exec "${VMID}" -- bash -lc "test -f /opt/gitlab/data/config/gitlab.rb && echo yes || echo no" 2>/dev/null || true)"
trusted_proxy_line="$(pct exec "${VMID}" -- bash -lc "grep -n 'trusted_proxies' /opt/gitlab/data/config/gitlab.rb || true" 2>/dev/null || true)"
external_url_line="$(pct exec "${VMID}" -- bash -lc "grep -n '^external_url' /opt/gitlab/data/config/gitlab.rb || true" 2>/dev/null || true)"
if [[ -n "${REQUEST_ID}" ]]; then
    error_tail="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose exec -T gitlab bash -lc \"grep -n '${REQUEST_ID}' /var/log/gitlab/gitlab-rails/production_json.log | tail -n 40 || true\"" 2>/dev/null || true)"
else
    error_tail="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose exec -T gitlab bash -lc \"grep -nE 'Completed 500|FATAL|PG::|ActionController::InvalidAuthenticityToken|NoMethodError|undefined method|Exception' /var/log/gitlab/gitlab-rails/production_json.log | tail -n 60 || true\"" 2>/dev/null || true)"
fi
rails_log_tail="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose exec -T gitlab bash -lc \"tail -n 80 /var/log/gitlab/gitlab-rails/production_json.log || true\"" 2>/dev/null || true)"
rails_text_500="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose exec -T gitlab bash -lc \"grep -nE 'Completed 500|ActionController::InvalidAuthenticityToken|NoMethodError|RuntimeError|PG::|FATAL|Exception' /var/log/gitlab/gitlab-rails/production.log | tail -n 80 || true\"" 2>/dev/null || true)"
if [[ -n "${REQUEST_ID}" ]]; then
    nginx_reqid="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose exec -T gitlab bash -lc \"grep -n '${REQUEST_ID}' /var/log/gitlab/nginx/gitlab_access.log /var/log/gitlab/nginx/gitlab_error.log /var/log/gitlab/gitlab-workhorse/current 2>/dev/null | tail -n 40 || true\"" 2>/dev/null || true)"
else
    nginx_reqid="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose exec -T gitlab bash -lc \"grep -nE ' 500 |status=500|internal server error|csrf|invalid authenticity' /var/log/gitlab/nginx/gitlab_access.log /var/log/gitlab/nginx/gitlab_error.log /var/log/gitlab/gitlab-workhorse/current 2>/dev/null | tail -n 60 || true\"" 2>/dev/null || true)"
fi
workhorse_500="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose logs --tail=200 gitlab 2>/dev/null | grep -niE '500|csrf|invalid authenticity|exception|error' | tail -n 80 || true" 2>/dev/null || true)"
postgres_identity="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose exec -T postgres sh -lc 'id -u; id -g; id'" 2>/dev/null || true)"
postgres_file_stat="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose exec -T postgres sh -lc 'ls -ln /var/lib/postgresql/data/base/16384/22068 2>/dev/null || true; stat -c \"%u:%g %a %n\" /var/lib/postgresql/data/base/16384/22068 2>/dev/null || true'" 2>/dev/null || true)"
postgres_data_stat="$(pct exec "${VMID}" -- bash -lc "ls -ldn /opt/gitlab/postgres/data /opt/gitlab/postgres/data/base /opt/gitlab/postgres/data/base/16384 2>/dev/null || true" 2>/dev/null || true)"
oom_tail="$(pct exec "${VMID}" -- bash -lc "dmesg 2>/dev/null | tail -n 200 | rg -i 'out of memory|killed process|oom'" 2>/dev/null || true)"

# #region agent log
write_log "A" "gitlab-login-debug.sh:container" "container_and_compose_state" \
    "{\"pct_status\":\"$(json_escape "${container_state}")\",\"compose_ps\":\"$(json_escape "${compose_states}")\"}"
# #endregion

# #region agent log
write_log "B" "gitlab-login-debug.sh:database" "postgres_connectivity" \
    "{\"pg_isready\":\"$(json_escape "${postgres_ready}")\"}"
# #endregion

# #region agent log
write_log "C" "gitlab-login-debug.sh:proxy" "gitlab_proxy_config" \
    "{\"gitlab_rb_exists\":\"$(json_escape "${gitlab_rb_exists}")\",\"external_url\":\"$(json_escape "${external_url_line}")\",\"trusted_proxies\":\"$(json_escape "${trusted_proxy_line}")\"}"
# #endregion

# #region agent log
write_log "D" "gitlab-login-debug.sh:app-errors" "application_errors_tail" \
    "{\"request_id\":\"$(json_escape "${REQUEST_ID}")\",\"errors\":\"$(json_escape "${error_tail}")\"}"
# #endregion

# #region agent log
write_log "D" "gitlab-login-debug.sh:app-errors" "rails_production_log_tail" \
    "{\"request_id\":\"$(json_escape "${REQUEST_ID}")\",\"tail\":\"$(json_escape "${rails_log_tail}")\"}"
# #endregion

# #region agent log
write_log "D" "gitlab-login-debug.sh:app-errors" "rails_production_text_500" \
    "{\"request_id\":\"$(json_escape "${REQUEST_ID}")\",\"errors\":\"$(json_escape "${rails_text_500}")\"}"
# #endregion

# #region agent log
write_log "D" "gitlab-login-debug.sh:edge-and-workhorse" "nginx_workhorse_request" \
    "{\"request_id\":\"$(json_escape "${REQUEST_ID}")\",\"matches\":\"$(json_escape "${nginx_reqid}")\",\"gitlab_logs\":\"$(json_escape "${workhorse_500}")\"}"
# #endregion

# #region agent log
write_log "D" "gitlab-login-debug.sh:postgres-permissions" "postgres_file_permissions" \
    "{\"postgres_identity\":\"$(json_escape "${postgres_identity}")\",\"file_stat\":\"$(json_escape "${postgres_file_stat}")\",\"host_data_stat\":\"$(json_escape "${postgres_data_stat}")\"}"
# #endregion

# #region agent log
write_log "E" "gitlab-login-debug.sh:oom-check" "kernel_oom_tail" \
    "{\"oom_messages\":\"$(json_escape "${oom_tail}")\"}"
# #endregion

echo "wrote debug logs to ${LOG_PATH}"
