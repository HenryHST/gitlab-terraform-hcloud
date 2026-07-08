#!/usr/bin/env bash
set -euo pipefail
COMPOSE_DIR=/opt/gitlab
LOG=/var/log/gitlab-plantuml-enable.log
exec >>"$LOG" 2>&1
echo "=== gitlab-plantuml-enable $(date -Is) ==="
cd "$COMPOSE_DIR"

for attempt in $(seq 1 40); do
  if [ "$(docker compose ps gitlab --format '{{.State}}' 2>/dev/null | head -1)" != "running" ]; then
    sleep 30
    continue
  fi
  if docker compose exec -T gitlab gitlab-rails runner \
    "ApplicationSetting.current.update!(plantuml_enabled: true, plantuml_url: '${PLANTUML_URL}'); puts 'plantuml_ok'" \
    2>/dev/null | grep -q plantuml_ok; then
    echo "=== plantuml enabled $(date -Is) ==="
    exit 0
  fi
  sleep 30
done

echo "=== plantuml enable timed out $(date -Is) ===" >&2
exit 1
