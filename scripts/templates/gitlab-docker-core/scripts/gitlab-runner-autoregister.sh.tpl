#!/usr/bin/env bash
set -euo pipefail
COMPOSE_DIR=/opt/gitlab
LOG=/var/log/gitlab-runner-autoregister.log
exec >>"$LOG" 2>&1
echo "=== gitlab-runner-autoregister $(date -Is) ==="
cd "$COMPOSE_DIR"

for attempt in $(seq 1 40); do
  if [ "$(docker compose ps gitlab --format '{{.State}}' 2>/dev/null | head -1)" != "running" ]; then
    echo "attempt $attempt: gitlab not running yet"
    sleep 30
    continue
  fi
  PAT="$(docker compose exec -T gitlab gitlab-rails runner "
u = User.find_by_username('root')
raise 'root user missing' unless u
pat = u.personal_access_tokens.create!(name: 'runner-bootstrap-lxc', scopes: [:api], expires_at: 1.day.from_now)
puts pat.token
" 2>/dev/null | tr -d '\r' | tail -1)"
  if [[ -z "$PAT" ]]; then
    sleep 30
    continue
  fi
  RESP="$(docker compose exec -T gitlab curl -sf --request POST \"http://localhost/api/v4/user/runners\" --header \"PRIVATE-TOKEN: $PAT\" --form \"runner_type=instance_type\" --form \"description=${RUNNER_DESCRIPTION}\" --form \"tag_list=${RUNNER_TAG_LIST}\" 2>/dev/null || true)"
  TOKEN="$(printf '%s' "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('token',''))" 2>/dev/null || true)"
  docker compose exec -T gitlab gitlab-rails runner "u = User.find_by_username('root'); u.personal_access_tokens.find_by(name: 'runner-bootstrap-lxc')&.revoke!" || true
  if [[ -n "$TOKEN" ]]; then
    cat >"${COMPOSE_DIR}/gitlab-runner/config.toml" <<EOF
concurrent = ${RUNNER_CONCURRENT}
check_interval = 0
shutdown_timeout = 0

[[runners]]
  name = "${RUNNER_DESCRIPTION}"
  url = "${GITLAB_URL}/"
  token = "$TOKEN"
  executor = "${RUNNER_EXECUTOR}"
  tag_list = ["${RUNNER_TAG_LIST}"]
  [runners.docker]
    image = "${RUNNER_DEFAULT_IMAGE}"
    privileged = ${RUNNER_PRIVILEGED}
    volumes = ["/cache"]
EOF
    chmod 0600 "${COMPOSE_DIR}/gitlab-runner/config.toml"
    docker compose up -d gitlab-runner
    echo "=== runner autoregister ok $(date -Is) ==="
    exit 0
  fi
  sleep 30
done

echo "=== runner autoregister timed out $(date -Is) ===" >&2
exit 1
