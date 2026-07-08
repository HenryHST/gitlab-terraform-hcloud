#!/usr/bin/env bash
set -euo pipefail

VMID="${1:-}"
TARGET_HOST="${2:-gitlab.stadthagen.dev}"
LOG_PATH="/Users/henry/Projects/gitlab-terraform-hcloud/.cursor/debug-672ee6.log"
SESSION_ID="672ee6"
RUN_ID="ct-cert-debug"

if [[ -z "${VMID}" ]]; then
    echo "usage: $0 <vmid> [fqdn]" >&2
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

ct_state="$(pct status "${VMID}" 2>/dev/null || true)"
compose_ps="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose ps --format json" 2>/dev/null || true)"
traefik_logs="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose logs --tail=200 traefik 2>/dev/null || true" || true)"
traefik_acme_errors="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose logs --tail=500 traefik 2>/dev/null | rg -ni 'acme|certificate|resolver|lego|challenge|letsencrypt|error|fail' || true" || true)"
traefik_file_errors="$(pct exec "${VMID}" -- bash -lc "rg -ni 'acme|certificate|resolver|lego|challenge|letsencrypt|error|fail' /var/log/traefik/traefik.log 2>/dev/null | tail -n 120 || true" 2>/dev/null || true)"

acme_enabled_flag="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && grep -n 'certResolver: hetzner' traefik/traefik.yml >/dev/null && echo true || echo false" 2>/dev/null || true)"
acme_storage_state="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && stat -c '%n|%s|%a|%U:%G' traefik/certs/acme_letsencrypt.json 2>/dev/null || echo missing" 2>/dev/null || true)"
acme_json_sample="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && (head -c 160 traefik/certs/acme_letsencrypt.json 2>/dev/null || true)" 2>/dev/null || true)"
acme_cert_domains="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && python3 - <<'PY'
import json
from pathlib import Path
p = Path('traefik/certs/acme_letsencrypt.json')
if not p.exists():
    print('missing')
    raise SystemExit(0)
try:
    data = json.loads(p.read_text())
except Exception as e:
    print(f'invalid_json:{e.__class__.__name__}')
    raise SystemExit(0)
resolver = data.get('hetzner', {})
certs = resolver.get('Certificates', []) or []
if not certs:
    print('none')
else:
    vals = []
    for c in certs:
        d = c.get('domain', {}) or {}
        main = d.get('main', '')
        sans = ','.join(d.get('sans', []) or [])
        vals.append(f'{main}|{sans}')
    print(';'.join(vals))
PY" 2>/dev/null || true)"
acme_email_state="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && val=\$(awk -F= '/^ACME_EMAIL=/{print \$2}' traefik/.env | tr -d '\"' || true); if [ -n \"\$val\" ]; then echo set; else echo empty; fi" 2>/dev/null || true)"
hetzner_token_state="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && val=\$(awk -F= '/^HETZNER_API_TOKEN=/{print \$2}' traefik/.env | tr -d '\"' || true); if [ -n \"\$val\" ]; then echo set; else echo empty; fi" 2>/dev/null || true)"

router_state="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose config 2>/dev/null | rg -n 'traefik.http.routers.gitlab.(rule|entrypoints|tls|tls.certresolver)' || true" 2>/dev/null || true)"
dns_state="$(pct exec "${VMID}" -- bash -lc "getent hosts '${TARGET_HOST}' || true" 2>/dev/null || true)"
tls_probe="$(pct exec "${VMID}" -- bash -lc "echo | openssl s_client -connect '${TARGET_HOST}:443' -servername '${TARGET_HOST}' -brief 2>/dev/null | tr '\n' ';' || true" 2>/dev/null || true)"
cert_subject="$(pct exec "${VMID}" -- bash -lc "echo | openssl s_client -connect '${TARGET_HOST}:443' -servername '${TARGET_HOST}' 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null | tr '\n' ';' || true" 2>/dev/null || true)"

dns_zone_base="${TARGET_HOST#*.}"
hetzner_api_probe="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && tok=\$(awk -F= '/^HETZNER_API_TOKEN=/{print \$2}' traefik/.env | tr -d '\"'); if [ -z \"\$tok\" ]; then echo token_missing; else code=\$(curl -sL -o /tmp/hetzner-zone-check.json -w '%{http_code}' -H \"Auth-API-Token: \$tok\" \"https://dns.hetzner.com/api/v1/zones?name=${dns_zone_base}\" || true); body=\$(tr -d '\n' </tmp/hetzner-zone-check.json 2>/dev/null || true); if echo \"\$body\" | rg -q '\"zones\"'; then zones_count=\$(python3 - <<'PY'
import json
from pathlib import Path
p=Path('/tmp/hetzner-zone-check.json')
try:
    j=json.loads(p.read_text())
    print(len(j.get('zones',[])))
except Exception:
    print('parse_error')
PY
); else zones_count=unknown; fi; echo \"status=\$code zones=\$zones_count\"; fi" 2>/dev/null || true)"
hetzner_api_auth_probe="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && tok=\$(awk -F= '/^HETZNER_API_TOKEN=/{print \$2}' traefik/.env | tr -d '\"'); if [ -z \"\$tok\" ]; then echo token_missing; else code=\$(curl -sL -o /tmp/hetzner-auth-check.json -w '%{http_code}' -H \"Auth-API-Token: \$tok\" \"https://dns.hetzner.com/api/v1/zones\" || true); body=\$(tr -d '\n' </tmp/hetzner-auth-check.json 2>/dev/null || true); if echo \"\$body\" | rg -q '\"error\"'; then err=\$(python3 - <<'PY'
import json
from pathlib import Path
p=Path('/tmp/hetzner-auth-check.json')
try:
    j=json.loads(p.read_text())
    e=j.get('error',{}) if isinstance(j,dict) else {}
    print(f\"{e.get('code','')}:{e.get('message','')}\")
except Exception:
    print('none')
PY
); else err=none; fi; echo \"status=\$code error=\$err\"; fi" 2>/dev/null || true)"
traefik_env_provider_state="$(pct exec "${VMID}" -- bash -lc "cd /opt/gitlab && docker compose exec -T traefik sh -lc 'token_len=\${#HETZNER_API_TOKEN}; key_len=\${#HETZNER_API_KEY}; if [ \"\$token_len\" -gt 0 ]; then token_state=set; else token_state=empty; fi; if [ \"\$key_len\" -gt 0 ]; then key_state=set; else key_state=empty; fi; printf \"token=%s(%s) key=%s(%s)\\n\" \"\$token_state\" \"\$token_len\" \"\$key_state\" \"\$key_len\"' 2>/dev/null || true" 2>/dev/null || true)"

# #region agent log
write_log "A" "gitlab-cert-debug.sh:runtime" "container_and_traefik_runtime" \
    "{\"pct_status\":\"$(json_escape "${ct_state}")\",\"compose_ps\":\"$(json_escape "${compose_ps}")\"}"
# #endregion

# #region agent log
write_log "B" "gitlab-cert-debug.sh:acme-files" "acme_config_and_storage_state" \
    "{\"acme_enabled\":\"$(json_escape "${acme_enabled_flag}")\",\"acme_storage\":\"$(json_escape "${acme_storage_state}")\",\"acme_json_sample\":\"$(json_escape "${acme_json_sample}")\",\"acme_cert_domains\":\"$(json_escape "${acme_cert_domains}")\"}"
# #endregion

# #region agent log
write_log "C" "gitlab-cert-debug.sh:acme-env" "acme_env_presence" \
    "{\"acme_email\":\"$(json_escape "${acme_email_state}")\",\"hetzner_token\":\"$(json_escape "${hetzner_token_state}")\"}"
# #endregion

# #region agent log
write_log "D" "gitlab-cert-debug.sh:routing" "router_tls_configuration" \
    "{\"router_lines\":\"$(json_escape "${router_state}")\"}"
# #endregion

# #region agent log
write_log "E" "gitlab-cert-debug.sh:tls-probe" "live_tls_and_dns_probe" \
    "{\"target_host\":\"$(json_escape "${TARGET_HOST}")\",\"dns\":\"$(json_escape "${dns_state}")\",\"tls_brief\":\"$(json_escape "${tls_probe}")\",\"cert_meta\":\"$(json_escape "${cert_subject}")\"}"
# #endregion

# #region agent log
write_log "A" "gitlab-cert-debug.sh:traefik-logs" "traefik_recent_logs" \
    "{\"tail\":\"$(json_escape "${traefik_logs}")\"}"
# #endregion

# #region agent log
write_log "B" "gitlab-cert-debug.sh:traefik-acme" "traefik_acme_error_lines" \
    "{\"matches\":\"$(json_escape "${traefik_acme_errors}")\"}"
# #endregion

# #region agent log
write_log "B" "gitlab-cert-debug.sh:traefik-file-acme" "traefik_file_log_acme_errors" \
    "{\"matches\":\"$(json_escape "${traefik_file_errors}")\"}"
# #endregion

# #region agent log
write_log "F" "gitlab-cert-debug.sh:hetzner-api" "hetzner_dns_api_probe" \
    "{\"zone\":\"$(json_escape "${dns_zone_base}")\",\"probe\":\"$(json_escape "${hetzner_api_probe}")\"}"
# #endregion

# #region agent log
write_log "F" "gitlab-cert-debug.sh:hetzner-api-auth" "hetzner_dns_api_auth_probe" \
    "{\"zone\":\"$(json_escape "${dns_zone_base}")\",\"probe\":\"$(json_escape "${hetzner_api_auth_probe}")\"}"
# #endregion

# #region agent log
write_log "F" "gitlab-cert-debug.sh:traefik-env-provider" "traefik_provider_env_state" \
    "{\"state\":\"$(json_escape "${traefik_env_provider_state}")\"}"
# #endregion

echo "wrote debug logs to ${LOG_PATH}"
