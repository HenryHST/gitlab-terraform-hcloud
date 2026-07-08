#!/usr/bin/env bash
set -euo pipefail
COMPOSE_DIR=/opt/gitlab
LOG=/var/log/gitlab-backup.log
LOCK=/var/run/gitlab-backup.lock
SOURCE="${GITLAB_BACKUP_SOURCE:-manual}"
exec 9>"$LOCK"
flock -n 9 || { echo "gitlab-backup already running (lock $LOCK)"; exit 1; }
exec >>"$LOG" 2>&1
echo "=== gitlab-backup $(date -Is) source=$SOURCE ==="
cd "$COMPOSE_DIR"
if [ "$(docker compose ps gitlab --format '{{.State}}' 2>/dev/null | head -1)" != "running" ]; then
  echo "ERROR: gitlab service not running"
  exit 1
fi
docker compose exec -T gitlab gitlab-backup create
docker compose exec -T gitlab gitlab-ctl backup-etc --delete-old-backups
echo "=== finished $(date -Is) ==="
