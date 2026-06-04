#cloud-config
# Hetzner 001_onboot appends to /root/.bashrc during cloud_final. "enable" alone may not start our unit if
# multi-user.target is already active. A small background script waits until hooks exist, then starts the oneshot.
write_files:
  - path: /usr/local/sbin/gitlab-terraform-schedule-bootstrap.sh
    permissions: "0755"
    owner: root:root
    content: |
      #!/bin/bash
      set -euo pipefail
      if [[ -f /var/lib/gitlab-terraform/.bootstrap-done ]]; then
        exit 0
      fi
      for _ in $(seq 1 90); do
        if grep -qE 'gitlab_setup|hcloud/gitlab_setup' /root/.bashrc 2>/dev/null; then
          break
        fi
        sleep 2
      done
      sleep 5
      systemctl start gitlab-terraform-bootstrap.service

  - path: /usr/local/lib/gitlab-terraform/clear_letsencrypt_auto_enabled.py
    permissions: "0644"
    owner: root:root
    content: |
      #!/usr/bin/env python3
      """Persist letsencrypt.auto_enabled=false in gitlab-secrets.json (no other keys removed)."""
      import json
      from pathlib import Path

      def main() -> None:
          p = Path("/etc/gitlab/gitlab-secrets.json")
          if not p.is_file():
              return
          try:
              d = json.loads(p.read_text(encoding="utf-8"))
          except json.JSONDecodeError:
              return
          lec = dict(d.get("letsencrypt") or {})
          lec["auto_enabled"] = False
          d["letsencrypt"] = lec
          p.write_text(json.dumps(d, indent=2) + "\n", encoding="utf-8")

      if __name__ == "__main__":
          main()

  - path: /usr/local/sbin/gitlab-terraform-bootstrap.sh
    permissions: "0755"
    owner: root:root
    content: |
      #!/bin/bash
      set -euo pipefail
      sleep ${bootstrap_wait}
      for f in /root/.bashrc /root/.profile; do
        if [[ -f "$f" ]]; then
          sed -i '#gitlab_setup#d' "$f"
        fi
      done
      if [[ -f /opt/hcloud/gitlab_setup.sh ]]; then
        printf '%s\n' '#!/bin/sh' 'exit 0' > /opt/hcloud/gitlab_setup.sh
        chmod 0755 /opt/hcloud/gitlab_setup.sh
      fi
      mkdir -p /var/lib/gitlab-terraform
      # Strip prior assignments so image/Hetzner defaults cannot override appended block (journal showed LE still running after append-only).
      sed -i '/^[[:space:]]*external_url[[:space:]]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*letsencrypt\['enable'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*letsencrypt\["enable"\]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*letsencrypt\['acme_staging'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*letsencrypt\["acme_staging"\]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*letsencrypt\['contact_emails'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*letsencrypt\["contact_emails"\]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*nginx\['redirect_http_to_https'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*nginx\["redirect_http_to_https"\]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*nginx\['listen_https'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*nginx\["listen_https"\]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*letsencrypt\['auto_enabled'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*letsencrypt\["auto_enabled"\]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*gitlab_rails\['manage_backup_path'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*gitlab_rails\["manage_backup_path"\]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*gitlab_rails\['backup_path'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*gitlab_rails\["backup_path"\]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*gitlab_rails\['backup_keep_time'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*gitlab_rails\["backup_keep_time"\]/d' /etc/gitlab/gitlab.rb
%{ if gitlab_letsencrypt_enabled }
      {
        echo ""
        echo "# --- gitlab-terraform: integrated Let's Encrypt ---"
        echo "external_url 'https://${gitlab_fqdn}'"
        echo "letsencrypt['enable'] = true"
        echo "letsencrypt['contact_emails'] = ['${letsencrypt_email}']"
        echo "letsencrypt['acme_staging'] = false"
      } >> /etc/gitlab/gitlab.rb
%{ else }
      {
        echo ""
        echo "# --- gitlab-terraform: disable integrated Let's Encrypt (first boot) ---"
        echo "external_url 'http://${gitlab_fqdn}'"
        echo "letsencrypt['enable'] = false"
        echo "letsencrypt['auto_enabled'] = false"
        echo "letsencrypt['acme_staging'] = false"
        echo "nginx['redirect_http_to_https'] = false"
        echo "nginx['listen_https'] = false"
      } >> /etc/gitlab/gitlab.rb
      python3 /usr/local/lib/gitlab-terraform/clear_letsencrypt_auto_enabled.py
%{ endif }
%{ if backup_enabled ~}
      {
        echo ""
        echo "# --- gitlab-terraform: backups (https://docs.gitlab.com/omnibus/settings/backups.html) ---"
        echo "gitlab_rails['manage_backup_path'] = true"
        echo "gitlab_rails['backup_path'] = \"/var/opt/gitlab/backups\""
        echo "gitlab_rails['backup_keep_time'] = ${backup_keep_time}"
      } >> /etc/gitlab/gitlab.rb
%{ endif ~}
      gitlab-ctl reconfigure
      touch /var/lib/gitlab-terraform/.bootstrap-done
%{ if backup_enabled ~}

  - path: /usr/local/sbin/gitlab-backup.sh
    permissions: "0755"
    owner: root:root
    content: |
      #!/usr/bin/env bash
      # Application + gitlab.rb/config backup (Omnibus). Archives: /var/opt/gitlab/backups
      set -euo pipefail
      LOG=/var/log/gitlab-backup.log
      LOCK=/var/run/gitlab-backup.lock
      SOURCE="$${GITLAB_BACKUP_SOURCE:-manual}"
      exec 9>"$LOCK"
      flock -n 9 || { echo "gitlab-backup already running (lock $LOCK)"; exit 1; }
      exec >>"$LOG" 2>&1
      echo "=== gitlab-backup $(date -Is) source=$SOURCE ==="
      if ! gitlab-ctl status >/dev/null 2>&1; then
        echo "ERROR: gitlab-ctl status failed (GitLab not ready)"
        exit 1
      fi
      if [[ "$SOURCE" == "cron" || "$${CRON:-}" == "1" ]]; then
        gitlab-backup create CRON=1
      else
        gitlab-backup create
      fi
      gitlab-ctl backup-etc --delete-old-backups
      echo "=== finished $(date -Is) source=$SOURCE ==="

  - path: /usr/local/sbin/gitlab-restore.sh
    permissions: "0755"
    owner: root:root
    content: |
      #!/usr/bin/env bash
      # Restore GitLab application and/or config from backups (see gitlab-backup.sh).
      # https://docs.gitlab.com/administration/backup_restore/restore_gitlab/
      set -euo pipefail
      BACKUP_DIR=/var/opt/gitlab/backups
      CONFIG_BACKUP_DIR=/etc/gitlab/config_backup
      LOG=/var/log/gitlab-restore.log

      usage() {
        cat <<'EOF'
      Usage:
        gitlab-restore.sh --list
        gitlab-restore.sh --config-only [gitlab_config_TIMESTAMP.tar]
        gitlab-restore.sh <BACKUP_ID>

      BACKUP_ID is the archive name without _gitlab_backup.tar (e.g. 1234567890_2026_05_16_18.10.5-ce.0).
      Set GITLAB_RESTORE_FORCE=1 to skip confirmation. Destructive: overwrites GitLab data.
      EOF
      }

      log() { echo "=== gitlab-restore $(date -Is) $* ===" >>"$LOG"; }
      die() { echo "ERROR: $*" >&2; exit 1; }

      confirm() {
        [[ "$${GITLAB_RESTORE_FORCE:-}" == "1" ]] && return 0
        echo "WARNING: This overwrites GitLab data. Continue? [y/N]" >&2
        read -r ans
        [[ "$ans" == [yY] || "$ans" == [yY][eE][sS] ]] || exit 1
      }

      list_backups() {
        local f id
        shopt -s nullglob
        for f in "$BACKUP_DIR"/*_gitlab_backup.tar; do
          id=$(basename "$f" _gitlab_backup.tar)
          echo "$id"
        done
        shopt -u nullglob
      }

      restore_config() {
        local tarfile="$${1:-}"
        if [[ -z "$tarfile" ]]; then
          tarfile=$(ls -t "$CONFIG_BACKUP_DIR"/gitlab_config_*.tar 2>/dev/null | head -1 || true)
        elif [[ ! "$tarfile" = /* ]]; then
          tarfile="$CONFIG_BACKUP_DIR/$tarfile"
        fi
        [[ -n "$tarfile" && -f "$tarfile" ]] || die "no config backup in $CONFIG_BACKUP_DIR"
        log "config-only $tarfile"
        exec >>"$LOG" 2>&1
        gitlab-ctl stop
        tar -xf "$tarfile" -C /
        gitlab-ctl reconfigure
        gitlab-ctl restart
        echo "=== config restore finished $(date -Is) ==="
      }

      restore_app() {
        local id="$1"
        local archive="$BACKUP_DIR/$${id}_gitlab_backup.tar"
        [[ -f "$archive" ]] || die "backup not found: $archive"
        chown git:git "$archive" 2>/dev/null || true
        log "application BACKUP=$id"
        exec >>"$LOG" 2>&1
        gitlab-ctl stop puma
        gitlab-ctl stop sidekiq
        gitlab-backup restore BACKUP="$id"
        gitlab-ctl reconfigure
        gitlab-ctl restart
        gitlab-rake gitlab:check SANITIZE=true || true
        echo "=== application restore finished $(date -Is) ==="
      }

      main() {
        case "$${1:-}" in
          -h|--help) usage; exit 0 ;;
          --list|-l) list_backups; exit 0 ;;
          --config-only)
            confirm
            restore_config "$${2:-}"
            ;;
          "")
            usage
            echo >&2
            echo "Available application backups:" >&2
            list_backups || echo "(none)" >&2
            exit 1
            ;;
          *)
            confirm
            restore_app "$1"
            ;;
        esac
      }

      main "$@"
%{ if backup_auto_enabled ~}

  - path: /etc/cron.d/gitlab-backup
    permissions: "0644"
    owner: root:root
    content: |
      SHELL=/bin/bash
      PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
      ${backup_cron_effective} root GITLAB_BACKUP_SOURCE=cron /usr/local/sbin/gitlab-backup.sh
%{ endif ~}
%{ endif ~}

  - path: /etc/systemd/system/gitlab-terraform-bootstrap.service
    permissions: "0644"
    owner: root:root
    content: |
      [Unit]
      Description=GitLab Terraform bootstrap after Hetzner 001_onboot hooks exist
      After=network-online.target
      Wants=network-online.target
      ConditionPathExists=!/var/lib/gitlab-terraform/.bootstrap-done

      [Service]
      Type=oneshot
      ExecStartPre=/usr/bin/mkdir -p /var/lib/gitlab-terraform
      ExecStart=/usr/local/sbin/gitlab-terraform-bootstrap.sh
      RemainAfterExit=yes

      [Install]
      WantedBy=multi-user.target

runcmd:
  - [systemctl, daemon-reload]
  - [systemctl, enable, gitlab-terraform-bootstrap.service]
  - [bash, -lc, "nohup /usr/local/sbin/gitlab-terraform-schedule-bootstrap.sh &"]
