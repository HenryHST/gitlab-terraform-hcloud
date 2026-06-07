# Changelog

Alle wesentlichen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format orientiert sich an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Backups (Docker Compose / Omnibus):** `gitlab_docker_backup_auto_enabled`, `gitlab_docker_backup_time` (HH:MM), optionaler `gitlab_docker_backup_cron`-Override; Cron nur bei Auto aktiv; erweiterte Host-Skripte (`GITLAB_BACKUP_SOURCE`, Lockfile); [`docs/backup.md`](docs/backup.md) und [`docs/examples/gitlab-backup-ci.yml.example`](docs/examples/gitlab-backup-ci.yml.example).
- **GitLab Pages (Docker Compose / Proxmox-Docker):** `gitlab_docker_pages_enabled`, `gitlab_docker_pages_dns_label`; Wildcard-DNS (`pages`, `*.pages`), Traefik-Router auf Port 8090 mit DNS-01-Wildcard-Zertifikat; `gitlab_pages['custom_domain_mode'] = 'http'` (Traefik-TLS); Outputs `pages_fqdn`, `pages_wildcard_fqdn`, `pages_url`; [`docs/pages.md`](docs/pages.md), [`terraform/README.md`](terraform/README.md).
- **GitLab Runner (Buildah):** `gitlab_docker_runner_buildah_enabled` — drei Instance-Runner mit Tags `buildah-rootless`, `buildah-multiarch`, `buildah-privileged`; Host-QEMU/binfmt; [`docs/runner-buildah.md`](docs/runner-buildah.md), [`docs/examples/gitlab-ci-buildah.yml.example`](docs/examples/gitlab-ci-buildah.yml.example).
- **Docker-Host-Admin:** `gitlab_admin` — optionaler Linux-Benutzer (`gadmin`) auf dem Compose-Host via Cloud-Init (Home, `sudo`, `docker`, SSH mit Root-Key); Output `gitlab_docker_host_admin_username`.
- **Docker-Host-Hardening:** `gitlab_docker_host_hardening` — opt-in Host-OS: `jq`, `ufw`, `fail2ban` (`sshd`, `recidive`), sshd-Key-only, sysctl, unattended-upgrades.

### Changed

- **Buildah Runner `config.toml`:** Autoregister schreibt minimale Config (Reihenfolge rootless → privileged → multiarch, `run_untagged`, kein `tag_list`/Default-Image/`session_server` in der Datei; Tags weiterhin per API).
- **Docker-Host-Hardening (Host-OS):** sshd Drop-in, sysctl, fail2ban `recidive`, optional `ufw_ssh_source_ips` / ICMP / unattended-upgrades.
- **`docker_compose` Cloud-Init:** `user_data` für Hetzner-Server wird als **gzip+base64** übergeben (32-KiB-API-Limit); Proxmox-Snippets unverändert plain.
- **Dokumentation:** README auf Einstieg, Architektur und Schnellstart reduziert; Tiefgang nach [`docs/`](docs/) mit zentralem [Inhaltsverzeichnis](docs/README.md) (`reference.md`, `gitlab-install-modes.md`, `proxmox.md`, `operations.md`).
- **`gitlab_docker_backup_enabled`:** auch bei `gitlab_install_mode = "proxmox"` (und Legacy Proxmox-Docker-Stack); `gitlab_docker_backup_cron` Default leer (Zeit aus `gitlab_docker_backup_time`).

## [0.1.2] - 2026-06-04

Patch-Release: dedizierter Proxmox-Installationsmodus mit VM-ID-Plan-Check, Provider-Timeouts, Compose-Image-Checks und GitLab/PostgreSQL-Versionsvalidierung.

### Added

- **Proxmox:** Provider-Variablen `pm_timeout` (30–86400 s, Default 300) und `pm_parallel` (1–32, Default 1) in [`proxmox_variables.tf.example`](terraform/proxmox_variables.tf.example), an [`provider_proxmox.tf.example`](terraform/provider_proxmox.tf.example) angebunden.
- **Proxmox:** `gitlab_install_mode = "proxmox"` (erfordert `enable_proxmox_resources` und `proxmox_gitlab_docker_compose_enabled`); Variablen `proxmox_gitlab_vmid` / `proxmox_runner_vmid` (`0` = Auto); Modul [`modules/proxmox`](terraform/modules/proxmox) setzt `vmid` auf den QEMU-Ressourcen; bei festen IDs und `proxmox`-Modus Plan-Check per [`scripts/proxmox-check-vmids.sh`](scripts/proxmox-check-vmids.sh) und [`proxmox_data.tf.example`](terraform/proxmox_data.tf.example) → `proxmox_data.tf`.
- **Makefile:** `make check-images` und `make check-images-strict` — vergleichen gepinnte GitLab-CE- und Traefik-Docker-Tags mit Docker Hub ([`scripts/check-compose-image-versions.sh`](scripts/check-compose-image-versions.sh)).
- **GitLab CE / PostgreSQL:** Validierung von `gitlab_docker_gitlab_ce_image` und `gitlab_docker_postgres_image` sowie `check.gitlab_docker_postgres_version` in [`checks_gitlab_docker.tf`](terraform/checks_gitlab_docker.tf) gemäß [GitLab installation requirements](https://docs.gitlab.com/install/requirements/) (z. B. GitLab 18.x → PostgreSQL 16 oder 17; **GitLab 19.x → automatisch `postgres:17`** via `local.gitlab_docker_postgres_image_effective`).

[0.1.2]: https://github.com/HenryHST/gitlab-terraform-hcloud/releases/tag/v0.1.2

## [0.1.1] - 2026-05-31

Patch-Release: PlantUML und CI-Artifacts im Docker-Compose-Stack, Runner-Autoregister, erweitertes Proxmox-Modul (Validierung, Outputs, `vm_state`).

### Added

- **PlantUML (`docker_compose`):** Optionaler Service `plantuml/plantuml-server` im Compose-Stack; `nginx['custom_gitlab_server_config']` leitet `/-/plantuml/` an `http://plantuml:8080/`; `PLANTUML_ENCODING=deflate`; Bootstrap-Skript setzt `plantuml_enabled` / `plantuml_url` in den Application Settings. Variablen `gitlab_docker_plantuml_enabled` (Standard `true`), `gitlab_docker_plantuml_image`.
- **CI job artifacts (`docker_compose`):** Variablen `artifacts_enabled` (Standard `true`) und `artifacts_path` in `gitlab.rb`; dedizierter Host-Bind-Mount `/opt/gitlab/artifacts/data` → Container-Pfad (Standard `/var/opt/gitlab/gitlab-rails/shared/artifacts`).
- **GitLab Runner Autoregister (`docker_compose`):** `gitlab_docker_runner_autoregister` (Standard `true`) — Bootstrap-Skript `gitlab-runner-autoregister.sh` erstellt Instance-Runner via `POST /api/v4/user/runners`, schreibt `config.toml`, startet Compose-Profil `runner`; manuelles `glrt-…` weiterhin möglich.
- **Proxmox-Modul [`modules/proxmox`](terraform/modules/proxmox):** Variablen-Validierung in `variables.tf` und Querbezüge in `checks.tf`; Outputs `gitlab_vm_status`, `gitlab_vm_network`, `gitlab_vm` (sowie Runner-Pendants) mit VM-ID, Power-State und Netzwerk; Variablen `vm_state` / `vm_state_runner` (Standard `stopped`, Werte `running`/`stopped`); Root-Outputs in [`outputs_proxmox.tf.example`](terraform/outputs_proxmox.tf.example) ergänzt.
- **README:** Abschnitt [Tech Stack](README.md) mit Logos und Kurzbeschreibungen der eingesetzten Technologien.

### Changed

- **Proxmox-Provider (Modul):** Mindestversion `>= 3.0.0` (für `vm_state` und erweiterte Outputs); [`provider_proxmox.tf.example`](terraform/provider_proxmox.tf.example) angepasst.

### Fixed

- **Renovate (GitHub):** `assignees` in [`renovate.json`](renovate.json) auf `henryhst` korrigiert.
- **TFLint:** Doppelte ungenutzte Variablen `gitlab_artifacts_*` entfernt (zugunsten `artifacts_*`).
- **CI:** `terraform fmt -check` für [`modules/proxmox/main.tf`](terraform/modules/proxmox/main.tf).

[0.1.1]: https://github.com/HenryHST/gitlab-terraform-hcloud/releases/tag/v0.1.1

## [0.1.0] - 2026-05-23

Minor-Release: Hetzner-`docker_compose` als Standardpfad mit CI/TFLint; optionale Proxmox-Schicht über kopierte `.example`-Dateien; GitLab Runner im Compose-Stack; DNS-Variable `dns_domain`.

### Added

- **GitLab CI:** [`.gitlab-ci.yml`](.gitlab-ci.yml) — `terraform fmt -check`, `terraform validate`, `tofu validate`, `tflint` (ohne Apply/Cloud-Tokens); `make ci` für lokale Parität.
- **`gitlab_root_email`:** Variable und `GITLAB_ROOT_EMAIL` in [`gitlab-docker-cloud-init.yaml.tpl`](terraform/templates/gitlab-docker-cloud-init.yaml.tpl) für den initialen GitLab-`root`-Benutzer (`docker_compose` / Proxmox-Docker-Stack); Fallback über `gitlab_letsencrypt_email` bzw. `gitlab-root@<zone>`.
- **`gitlab_docker_runner_enabled`:** Optionaler `gitlab-runner`-Service im Docker-Compose-Stack (`config.toml` + Docker-Executor); Variablen u. a. `gitlab_docker_runner_token`, `gitlab_docker_runner_tags`.
- **Proxmox optional (Hetzner-only):** [`proxmox.tf.example`](terraform/proxmox.tf.example), [`provider_proxmox.tf.example`](terraform/provider_proxmox.tf.example), [`proxmox_variables.tf.example`](terraform/proxmox_variables.tf.example), [`outputs_proxmox.tf.example`](terraform/outputs_proxmox.tf.example) — kein Proxmox-Provider im Default-`plan`; [`checks_proxmox.tf`](terraform/checks_proxmox.tf) für fehlende Dateien bei `enable_proxmox_resources = true`.
- **Modul [`modules/proxmox`](terraform/modules/proxmox):** QEMU-VMs, Cloud-Init-Snippet-Upload; Root-Wrapper als optionale Kopie von `proxmox.tf.example`.

### Changed

- **`domain_cicd_showcase_de` → `dns_domain`:** Variable und Output umbenannt (Hetzner-DNS-Zonenname); `moved`-Block für Output-State; in `terraform.tfvars` anpassen.
- **Proxmox-Variablen:** Aus [`variables.tf`](terraform/variables.tf) nach [`proxmox_variables.tf.example`](terraform/proxmox_variables.tf.example) — behebt TFLint `terraform_unused_declarations` im Hetzner-only-Stack.
- **GitLab-Provider:** `gitlab_early_auth_check` (Standard `false`); Platzhalter-Token nur bei `enable_gitlab_resources`; README Zwei-Phasen-Bootstrap.
- **`enable_hetzner_dns`:** Automatisch aus, wenn Proxmox alleiniger GitLab-Ziel ist; optionaler Override.

### Fixed

- **`terraform plan` ohne Proxmox:** Kein erzwungener `proxmox`-Provider und keine Verbindung zu `127.0.0.1:8006`, wenn nur Hetzner-`docker_compose` genutzt wird.
- **TFLint CI:** Exit-Code 2 durch 30 ungenutzte Proxmox-Variablen im Root-Modul.

### Migration

- `domain_cicd_showcase_de` in `terraform.tfvars` → `dns_domain`.
- Proxmox: zusätzlich `cp proxmox_variables.tf.example proxmox_variables.tf` (neben `proxmox.tf`, `provider_proxmox.tf`, `outputs_proxmox.tf`).
- GitLab Runner im Compose: erst GitLab betreiben, dann `glrt-…`-Token setzen und `gitlab_docker_runner_enabled = true`.

[0.1.0]: https://github.com/HenryHST/gitlab-terraform-hcloud/releases/tag/v0.1.0

## [0.0.5] - 2026-05-18

Patch-Release: Proxmox-Schienen mit Docker-Compose-Cloud-Init, Container Registry, Repo-Layout unter `terraform/`, GitLab-API-Ressourcen für Admin/Gruppen.

### Added

- **Proxmox (`enable_proxmox_resources`):** [`proxmox.tf`](terraform/proxmox.tf), [`proxmox_cloud_init.tf`](terraform/proxmox_cloud_init.tf) — Upload von `gitlab-docker-cloud-init.yaml.tpl` als Snippet, `cicustom` an `proxmox_vm_qemu.gitlab`; Variablen u. a. `proxmox_gitlab_docker_compose_enabled`, `proxmox_gitlab_ipconfig0`, `proxmox_api_token_id`, `proxmox_enable_clone` / `proxmox_enable_runner`; Provider `telmate/proxmox`, `hashicorp/null`, `hashicorp/local`; Doku [GitLab auf Proxmox](docs/proxmox.md).
- **Container Registry (`docker_compose`):** Variablen `gitlab_docker_registry_enabled` (Standard `true`) und `gitlab_docker_registry_dns_label`; DNS A-Record; Traefik-Router Port 5050; Registry-Volumes und `registry_external_url` in `gitlab.rb`; Outputs `registry_fqdn` / `registry_url`; Diagramme unter [`docs/diagrams/`](docs/diagrams/).
- **GitLab-Provider (`enable_gitlab_resources`):** Admin-Benutzer, Gruppen und Projekte in [`gitlab.tf`](terraform/gitlab.tf); Output `gitlab_admin_password`.

### Changed

- **Repository-Layout:** Terraform nach [`terraform/`](terraform/) verschoben; Makefile/CI mit Working Directory `terraform/`.
- **Docker-Stack-Locals:** `local.gitlab_docker_stack_enabled` auch bei Proxmox — gemeinsames Template und Passwort-Outputs für Hetzner und Proxmox.

### Fixed

- **Traefik TLS (GitLab + Registry):** Explizite Labels `traefik.http.routers.<name>.service=<name>`; behebt leeres ACME-JSON und Default-Zertifikat (`tls: unknown certificate`).
- **Cloud-Init / `templatefile`:** Kommentar ohne `${…}`-Syntax im Template (Terraform-Parse-Fehler bei `destroy`/`plan`).

### Migration

- `terraform.tfvars`, State und `.terraform/` nach **`terraform/`** verschieben, dann `cd terraform && terraform init`.
- Proxmox: `enable_proxmox_resources = true`, `gitlab_install_mode = "none"` für reine On-Prem-VM; Snippet-Storage (`proxmox_snippet_storage`) muss `snippets` unterstützen.

[0.0.5]: https://github.com/HenryHST/gitlab-terraform-hcloud/releases/tag/v0.0.5

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
