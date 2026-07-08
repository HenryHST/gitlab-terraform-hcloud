#!/usr/bin/env bash
set -euo pipefail
COMPOSE_DIR=/opt/gitlab
BACKUP_DIR=/opt/gitlab/backups

usage() {
  cat <<'EOF'
Usage:
  gitlab-restore.sh --list
  gitlab-restore.sh <BACKUP_ID>
EOF
}

if [[ "${1:-}" == "--list" ]]; then
  ls -1 "${BACKUP_DIR}"/*_gitlab_backup.tar 2>/dev/null | sed 's|.*/||; s/_gitlab_backup\.tar$//' || true
  exit 0
fi

if [[ -z "${1:-}" ]]; then
  usage
  exit 1
fi

cd "$COMPOSE_DIR"
docker compose exec -T gitlab gitlab-ctl stop puma
docker compose exec -T gitlab gitlab-ctl stop sidekiq
docker compose exec -T gitlab gitlab-backup restore BACKUP="$1"
docker compose restart gitlab
docker compose exec -T gitlab gitlab-rake gitlab:check SANITIZE=true || true
