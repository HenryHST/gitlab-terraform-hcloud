# Changelog

Alle wesentlichen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format orientiert sich an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.0.2]: https://github.com/HenryHST/gitlab-terraform-hcloud/releases/tag/v0.0.2
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

[0.0.1]: https://github.com/HenryHST/gitlab-terraform-hcloud/releases/tag/v0.0.1
