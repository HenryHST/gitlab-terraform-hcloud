# Changelog

Alle wesentlichen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format orientiert sich an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Repository-Layout:** Terraform-Konfiguration (`*.tf`, `modules/`, `templates/`, `terraform.tfvars.example`, Lockfile, TFLint) nach [`terraform/`](terraform/) verschoben; Root enthält README, CHANGELOG, Makefile, CI, Renovate.
- **Makefile / CI:** Befehle laufen mit Working Directory `terraform/` (`make` vom Repo-Root).

### Migration

- Lokale Dateien nach dem Pull: `terraform.tfvars`, `terraform.tfstate` und `.terraform/` in den Ordner **`terraform/`** legen, dann `cd terraform && terraform init`.

## [0.0.4] - 2026-05-17

Patch-Release: Backups/Restore für beide GitLab-Installationsmodi, Traefik-/HTTPS-Stabilität, Web-IDE-Doku, Sign-up-Steuerung.

### Added

- **Backups (`docker_compose` und `hetzner_app`):** Variablen `gitlab_docker_backup_enabled`, `gitlab_docker_backup_keep_time`, `gitlab_docker_backup_cron` — `gitlab.rb`-Backup-Pfad, Host-Cron und Skripte ([`variables.tf`](variables.tf), [`main.tf`](main.tf)).
- **`docker_compose`:** `/opt/gitlab/scripts/gitlab-backup.sh`, `/opt/gitlab/scripts/gitlab-restore.sh` (`--list`, `<BACKUP_ID>`, `--config-only`); Bind-Mount `./backups` ([`templates/gitlab-docker-cloud-init.yaml.tpl`](templates/gitlab-docker-cloud-init.yaml.tpl)).
- **`hetzner_app`:** `/usr/local/sbin/gitlab-backup.sh` und `gitlab-restore.sh` im Omnibus-Cloud-Init ([`templates/gitlab-cloud-init.yaml.tpl`](templates/gitlab-cloud-init.yaml.tpl)).
- **`gitlab_signup_enabled`:** Steuert `gitlab_rails['gitlab_signup_enabled']` in `gitlab.rb` (nur `docker_compose`).
- **GitHub Issue Templates:** [`.github/ISSUE_TEMPLATE/`](.github/ISSUE_TEMPLATE/) (Bug Report, Feature Request).
- **README:** Abschnitte Backups/Restore, Web IDE (OAuth, Extension Marketplace, Extension-Host-Format), Traefik-Troubleshooting.

### Changed

- **[`templates/gitlab-docker-cloud-init.yaml.tpl`](templates/gitlab-docker-cloud-init.yaml.tpl):** Traefik Docker-Provider `allowEmptyServices: true`; GitLab-Container-Healthcheck deaktiviert; TLS-Option in `tls.yml` von `default` nach `secure` umbenannt; Traefik-Router ohne `tls.options=default@file` (Traefik v3-kompatibel).
- **[`README.md`](README.md)** und **[`terraform.tfvars.example`](terraform.tfvars.example):** erweiterte Doku zu Backups, HTTPS/DNS-01, Web IDE.

### Fixed

- **HTTPS / Web IDE:** Label `traefik.http.routers.gitlab.tls.options=default@file` führte zu `unknown TLS options: default@file` — Router wurde nicht gebaut, TLS-Handshake schlug fehl (`SSL_ERROR_SYSCALL`).
- **Traefik 404 beim GitLab-Start:** Router fehlte, solange der Image-Healthcheck `starting`/`unhealthy` meldete; behoben durch `allowEmptyServices` und `healthcheck: disable`.
- **Cloud-Init / Terraform `templatefile`:** Bash-Parameter-Expansion in Restore-Skripten als `$${VAR:-}` escaped.

[0.0.4]: https://github.com/HenryHST/gitlab-terraform-hcloud/releases/tag/v0.0.4

## [0.0.3] - 2026-05-15

Patch-Release: Docker-Compose-Stack (Traefik, GitLab, PostgreSQL) produktionsnäher; Firewall mit SSH 2424 und Egress; optionales SMTP für GitLab.

### Added

- **SMTP für `docker_compose`:** Variablen `gitlab_smtp_*` und `gitlab_email_from` — schreiben Omnibus-SMTP in `/opt/gitlab/data/config/gitlab.rb`; Validierung nur bei `gitlab_install_mode = docker_compose` ([`variables.tf`](variables.tf), [`terraform.tfvars.example`](terraform.tfvars.example)).
- **Firewall [`modules/firewall`](modules/firewall):**
  - Eingehend **TCP 2424** (`enable_ssh_high`, Standard `true`) — GitLab Shell SSH (`gitlab_shell_ssh_port = 2424`).
  - Ausgehend **DNS 53** (TCP/UDP), **HTTP 80**, **HTTPS 443** (`enable_egress_dns` / `http` / `https`, `egress_destination_ips`).
  - Ausgehend **SMTP** (`enable_egress_smtp`, `egress_smtp_port`) — an Root an `gitlab_smtp_enabled` / `gitlab_smtp_port` gekoppelt; Runner-Firewall ohne 2424 und ohne SMTP-Egress.
- **Traefik (Docker-Init):** `.env` mit `ABSOLUTE_PATH`, `TZ`, Host-Label, `HETZNER_API_TOKEN`, `ACME_EMAIL`; `dynamic_conf/` (gzip, fail2ban, Security-Headers, TLS-Optionen); ACME/TLS-JSON unter `/opt/gitlab/traefik/certs` (Bind-Mount `/certs`).

### Changed

- **[`templates/gitlab-docker-cloud-init.yaml.tpl`](templates/gitlab-docker-cloud-init.yaml.tpl):**
  - GitLab-Konfiguration über **`gitlab.rb`** auf dem Host (kein `GITLAB_OMNIBUS_CONFIG`); Bind-Mounts für `config`, `logs`, `data/gitlab` und PostgreSQL `./postgres/data`.
  - GitLab-Container zusätzlich im Netz **`socket_proxy`**, damit der Hostname `postgres` auflösbar ist.
  - Statische IPs im `proxy`-Subnetz angepasst (`172.31.129.x`).
  - Traefik-Router: Middleware-Kette `default@file`, TLS `default@file`.
- **[`main.tf`](main.tf):** SMTP- und Firewall-Parameter an Server- bzw. Runner-Module durchgereicht.
- **[`README.md`](README.md):** Pfade unter `/opt/gitlab`, `gitlab.rb`, Firewall 2424/Egress, SMTP-Doku.
- **[`modules/gitlab-api/main.tf`](modules/gitlab-api/main.tf):** Kleinere Anpassungen an Provider-Ressourcen.

### Fixed

- **`PG::ConnectionBad: could not translate host name "postgres"`** — GitLab war nicht im gleichen Docker-Netz wie PostgreSQL; Beitritt zu `socket_proxy` behebt die Auflösung.
- **Firewall-Modul:** Syntax in [`modules/firewall/variables.tf`](modules/firewall/variables.tf) für `enable_ssh_high` korrigiert.

[0.0.3]: https://github.com/HenryHST/gitlab-terraform-hcloud/releases/tag/v0.0.3

## [0.0.2] - 2026-05-15

Patch-Release: GitLab-Provider-Ressourcen in ein Modul ausgelagert; `terraform plan` funktioniert wieder ohne API-Token, wenn `enable_gitlab_resources = false`.

### Added

- **Modul [`modules/gitlab-api/`](modules/gitlab-api/):** Gruppe `devops`, Projekte `devops` und `terraform`, User `renovate-bot`, optionale Gruppen-Mitgliedschaft und `gitlab_project_hook` für Renovate.

### Changed

- **[`gitlab.tf`](gitlab.tf):** Aufruf von `module.gitlab_api` mit `count = var.enable_gitlab_resources` statt inline Provider-Ressourcen.
- **[`outputs.tf`](outputs.tf):** GitLab-IDs aus Modul-Outputs (`devops_group_id`, `devops_project_id`, `terraform_project_id`).
- **[`provider.tf`](provider.tf):** Aliased GitLab-Provider; Platzhalter-Token und `early_auth_check` nur bei aktivierten API-Ressourcen.
- **[`variables.tf`](variables.tf)** / **[`terraform.tfvars.example`](terraform.tfvars.example):** Klarstellung `gitlab_api_url` für Self-Hosted (nicht `gitlab.com`, wenn GitLab auf dem eigenen Server läuft).

### Fixed

- **GitLab Provider v18:** Leerer `gitlab_api_token` löste `unable to locate config file` auf jedem `terraform plan` aus (Fallback auf glab-Config); behoben durch bedingtes Token und `early_auth_check`.

## [0.0.1] - 2026-05-15

Erstes Release: Terraform-Root für Hetzner Cloud mit optionalem GitLab (Omnibus, Docker Compose oder aus), DNS/Mail-Records, GitLab Runner und GitLab-Provider-Ressourcen.

### Added

- **Hetzner Cloud (Root):** Module für Firewall, Server und DNS (`modules/firewall`, `modules/server`, `modules/dns`) inkl. Mail-Records (MX, SPF, DMARC, DKIM, CAA, TLSA, SRV).
- **SSH:** Unterstützung für `ssh_public_key` und `ssh_public_key_file`; Validierung der Schlüsselformate.
- **GitLab-Installationsmodi** (`gitlab_install_mode`):
  - `none` — Standard-Server ohne GitLab-Cloud-Init.
  - `hetzner_app` — Hetzner-Image `gitlab` mit Omnibus-Cloud-Init ([`templates/gitlab-cloud-init.yaml.tpl`](templates/gitlab-cloud-init.yaml.tpl)), optionales integriertes Let's Encrypt (`gitlab_letsencrypt_enabled`).
  - `docker_compose` — Debian-VM mit Docker Compose: **Traefik**, **GitLab CE**, **PostgreSQL** ([`templates/gitlab-docker-cloud-init.yaml.tpl`](templates/gitlab-docker-cloud-init.yaml.tpl)); Netze nach LAB-Pattern (`crowdsec`, `proxy`, `socket_proxy`).
- **Docker Compose:** Externe PostgreSQL für GitLab; `random_password` für initiales `root`- und DB-Passwort (Outputs sensitiv).
- **Mend Renovate CE** (optional, `gitlab_docker_renovate_enabled`): Container `ghcr.io/mend/renovate-ce`, Env unter `/opt/gitlab/renovate/`, Traefik-Routing auf `renovate.<zone>`, DNS-A-Record, Webhook-Secrets per Terraform.
- **GitLab Runner (optional):** Zweite VM (`cpx22`), eigene Firewall, Cloud-Init mit optionaler `.deb`-Installation ([`templates/gitlab-runner-cloud-init.yaml.tpl`](templates/gitlab-runner-cloud-init.yaml.tpl)).
- **GitLab Provider** ([`gitlab.tf`](gitlab.tf), `enable_gitlab_resources`): Gruppe `devops`, Projekte `devops` und `terraform`, Bot-User `renovate-bot`, optional `gitlab_project_hook` für Renovate (`/webhook`).
- **Provider:** `hetznercloud/hcloud`, `hashicorp/random`, `gitlabhq/gitlab` (v18).
- **Outputs:** Server/DNS/Firewall, `gitlab_url` / `gitlab_fqdn`, Docker-Passwörter, Renovate-FQDN, GitLab-Provider-IDs, Runner-Verbindungsdaten.
- **Validierungen** in [`variables.tf`](variables.tf) für Installationsmodus, Docker-Images, API-Token und Renovate-Pflichtfelder.
- **CI / Qualität:** `Makefile` (`fmt`, `validate`), GitHub Actions Workflow für `terraform fmt` und `validate`.
- **Dokumentation:** Ausführliche [`README.md`](README.md), [`terraform.tfvars.example`](terraform.tfvars.example).

### Changed

- **`enable_gitlab_app` entfernt** — ersetzt durch `gitlab_install_mode` (`none` | `hetzner_app` | `docker_compose`).
- **GitLab Bootstrap (Omnibus):** systemd-Oneshot + Scheduler; HTTP-first ohne LE; `gitlab-secrets` / `auto_enabled`-Handling.
- **DNS-Modul:** Refactoring und DKIM-Chunking für lange Werte.

### Fixed

- GitLab Runner Cloud-Init: korrekte `.deb`-Paket-URLs (Arch-Mapping `armhf` → `arm`).
- GitLab Provider: `gitlab_project_hook` statt nicht vorhandenem `gitlab_webhook`; `visibility_level` und `namespace_id` (Provider v18).

### Security

- Secrets (`hcloud_token`, `gitlab_api_token`, Renovate-Lizenz/PAT, generierte Passwörter) gehören in `terraform.tfvars` (gitignored) oder CI-Secrets; sensible Terraform-Outputs markiert.

[0.0.2]: https://github.com/HenryHST/gitlab-terraform-hcloud/releases/tag/v0.0.2
[0.0.1]: https://github.com/HenryHST/gitlab-terraform-hcloud/releases/tag/v0.0.1
