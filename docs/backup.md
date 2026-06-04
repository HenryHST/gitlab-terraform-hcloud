# GitLab-Backups (Docker Compose / Omnibus)

Terraform steuert Backup-Pfad, Aufbewahrung, Host-Skripte und optional einen **Cron-Job** für `gitlab-backup create`. Gilt für **`gitlab_install_mode`** `docker_compose`, `hetzner_app`, `proxmox` (bzw. Proxmox mit `proxmox_gitlab_docker_compose_enabled`).

## Terraform-Variablen

| Variable | Default | Rolle |
|----------|---------|--------|
| `gitlab_docker_backup_enabled` | `true` | `gitlab.rb` (`manage_backup_path`, `backup_path`, `backup_keep_time`), Backup-/Restore-Skripte auf dem Host |
| `gitlab_docker_backup_auto_enabled` | `true` | Nur wenn `true`: `/etc/cron.d/gitlab-backup` |
| `gitlab_docker_backup_time` | `"03:00"` | Tägliche Uhrzeit (HH:MM, 24h, Host-Zeitzone), wenn `gitlab_docker_backup_cron` leer ist |
| `gitlab_docker_backup_cron` | `""` | Optional: fünf Cron-Felder (`minute hour dom month dow`); leer = aus `gitlab_docker_backup_time` |
| `gitlab_docker_backup_keep_time` | `604800` | Aufbewahrung in Sekunden (7 Tage); `0` = alle Archive behalten |

Vollständige Referenz: [reference.md](reference.md).

**Beispiele**

- Nur manuelle Backups: `gitlab_docker_backup_auto_enabled = false` (Skripte bleiben aktiv).
- Backup um 04:30: `gitlab_docker_backup_time = "04:30"` → Cron `30 4 * * *`.
- Eigenes Intervall: `gitlab_docker_backup_cron = "0 2 * * 0"` (Sonntag 02:00).

## Pfade und Skripte

| Modus | Backup-Skript | Archive | Log |
|-------|---------------|---------|-----|
| `docker_compose` / Proxmox-Docker | `/opt/gitlab/scripts/gitlab-backup.sh` | `/opt/gitlab/backups/` | `/var/log/gitlab-backup.log` |
| `hetzner_app` | `/usr/local/sbin/gitlab-backup.sh` | `/var/opt/gitlab/backups/` | `/var/log/gitlab-backup.log` |

Auf Docker-Hosts liegt zusätzlich **`/opt/gitlab/docs/BACKUP.md`** (Kurzreferenz).

Das Skript setzt `GITLAB_BACKUP_SOURCE` (`cron`, `manual`, `gitlab_ci`; Default `manual`). Bei `cron` oder `CRON=1` wird `gitlab-backup create CRON=1` verwendet ([GitLab-Doku](https://docs.gitlab.com/administration/backup_restore/backup_gitlab/#backup-command)). Ein Lock unter `/var/run/gitlab-backup.lock` verhindert parallele Läufe (Cron + CI).

**Manuell (Docker Compose)**

```bash
sudo GITLAB_BACKUP_SOURCE=manual /opt/gitlab/scripts/gitlab-backup.sh
```

**Restore:** `gitlab-restore.sh --list` · `<BACKUP_ID>` · `--config-only` — siehe [Restore-Doku](https://docs.gitlab.com/administration/backup_restore/restore_gitlab/).

## Auslösen über GitLab (CI/CD)

Es gibt **keine** GitLab-REST-API für Vollinstanz-Backups auf self-managed CE ([Forum](https://forum.gitlab.com/t/api-endpoint-for-backup-on-self-managed-gitlab-instance/103332)). Empfohlen:

1. **GitLab CI/CD** — manueller Job oder Pipeline Schedule mit **Shell-Runner** auf dem GitLab-Host (oder SSH auf dasselbe Skript).
2. **SSH** / direkt auf der VM wie oben.

Beispiel-Pipeline: [`examples/gitlab-backup-ci.yml.example`](examples/gitlab-backup-ci.yml.example).

## Checkliste nach Apply

- [ ] `gitlab_docker_backup_auto_enabled = false` → keine Datei `/etc/cron.d/gitlab-backup`
- [ ] `gitlab_docker_backup_time = "04:30"` → Cron-Zeile `30 4 * * *` (in `/etc/cron.d/gitlab-backup`)
- [ ] Manuell: Skript läuft, Eintrag in `/var/log/gitlab-backup.log`
- [ ] Optional: CI-Job aus dem Beispiel mit passenden Runner-`tags`

## Nicht abgedeckt

Verschlüsselung, Offsite-Upload (S3, rsync) usw. sind nicht Teil dieses Moduls — nur Host-Pfad und Cron; Offsite separat planen.
