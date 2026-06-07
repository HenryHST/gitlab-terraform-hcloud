# Variablen & Outputs

## Variablen (Root)

Terraform verlangt **alle Variablen ohne `default`** (siehe unten).

### Ohne Default (bei `apply` erforderlich)

| Name | Typ | Sensitiv | Beschreibung |
|------|-----|----------|--------------|
| `hcloud_token` | string | ja | Hetzner **Cloud** API-Token ([Console](https://console.hetzner.cloud/)) |
| `ssh_public_key` | string | nein | Eine Zeile aus `*.pub`, **oder** leer lassen und `ssh_public_key_file` setzen |
| `hetzner_api_key` | string | ja | Hetzner **DNS** API-Token ([dns.hetzner.com](https://dns.hetzner.com/)) — **nicht** `hcloud_token`; bei `docker_compose` → `HETZNER_API_TOKEN` in Traefik `.env` |

### Mit Default (optional überschreibbar)

| Name | Default (Kurz) | Hinweis |
|------|------------------|---------|
| `server_name` | `web1` | Name des `hcloud_server` |
| `server_type` | `cpx32` | Hetzner-Typ des GitLab-Hauptservers (`cx*`, `cpx*`, `ccx*`) |
| `location` | `fsn1` | z. B. `fsn1`, `nbg1`, `hel1`, `ash`, `hil` |
| `gitlab_install_mode` | `none` | `none`: kein GitLab; `hetzner_app`: Image `gitlab` + [`templates/gitlab-cloud-init.yaml.tpl`](../terraform/templates/gitlab-cloud-init.yaml.tpl); `docker_compose`: `gitlab_docker_host_image` (Standard `debian-13`) + [`templates/gitlab-docker-cloud-init.yaml.tpl`](../terraform/templates/gitlab-docker-cloud-init.yaml.tpl), Stack unter `/opt/gitlab`; `proxmox`: QEMU-VM(s) via [`module.proxmox`](../terraform/modules/proxmox) + gleiches Compose-Template (siehe [GitLab auf Proxmox](proxmox.md)) |
| `proxmox_gitlab_vmid` / `proxmox_runner_vmid` | `0` | Nur bei `gitlab_install_mode = proxmox`: feste Proxmox-VM-ID (100–999999999); `0` = nächste freie ID (kein Plan-Check). Bei ID > 0: Verfügbarkeit per Proxmox-API bei `plan` ([`proxmox_data.tf`](../terraform/proxmox_data.tf.example)) |
| `gitlab_docker_host_image` | `debian-13` | Nur `docker_compose`: Hetzner-Image-Slug für den Hauptserver (vor Apply mit `hcloud image list` prüfen; bei abweichendem Slug z. B. `debian-12` setzen) |
| `gitlab_docker_traefik_image` | `traefik:v3.7.1` | Traefik-Container in `docker_compose` |
| `gitlab_docker_gitlab_ce_image` | `gitlab/gitlab-ce:18.11.4-ce.0` | GitLab-CE-Image-Tag (`MAJOR.MINOR.PATCH-ce.0`); Validierung ab GitLab 16+ |
| `gitlab_docker_postgres_image` | `postgres:16-alpine` | PostgreSQL-Image (Major 13–17); **18.x:** 16 oder 17; **19.x:** Terraform setzt automatisch **postgres:17** (Suffix aus dieser Variable, z. B. `-alpine`) — Output `gitlab_docker_postgres_image_effective` |
| `gitlab_docker_renovate_enabled` | `false` | `true`: Mend **Renovate CE** im Compose-Stack; nur bei `docker_compose` |
| `gitlab_docker_renovate_ce_image` | `ghcr.io/mend/renovate-ce:9.1.0` | Image-Tag pinnen ([Container-Pakete](https://github.com/mend/renovate-ce-ee/pkgs/container/renovate-ce)) |
| `gitlab_docker_renovate_dns_label` | `renovate` | DNS + Traefik-Host: `<label>.<zone>` |
| `gitlab_docker_renovate_license_key` | `""` | Mend-Lizenz (sensitiv); Pflicht wenn Renovate aktiv |
| `gitlab_docker_renovate_gitlab_pat` | `""` | GitLab-PAT für Renovate (sensitiv); Pflicht wenn Renovate aktiv |
| `gitlab_docker_registry_enabled` | `true` | `true`: GitLab **Container Registry** (Omnibus + Traefik); nur bei `docker_compose`; `false` = kein DNS, keine Registry-Router |
| `gitlab_docker_registry_dns_label` | `registry` | DNS + `registry_external_url`: `<label>.<zone>` |
| `gitlab_docker_pages_enabled` | `false` | **`docker_compose`** / Proxmox-Docker: GitLab Pages (Traefik :8090, Wildcard-DNS); erfordert `gitlab_docker_traefik_acme_enabled`; siehe [pages.md](pages.md) |
| `gitlab_docker_pages_dns_label` | `pages` | Apex `pages.<zone>`; Projekt-URLs `<namespace>.pages.<zone>` |
| `gitlab_docker_traefik_acme_enabled` | `false` | `true`: Traefik Let’s Encrypt (DNS-01 via Hetzner); nur bei `gitlab_install_mode = docker_compose`; ACME-Mail über `gitlab_letsencrypt_email` bzw. Fallback `gitlab-acme@<zone>` |
| `gitlab_docker_backup_enabled` | `true` | **`docker_compose`**, **`hetzner_app`**, **`proxmox`** (bzw. Proxmox-Docker-Stack): `gitlab_rails` Backup in `gitlab.rb`, Host-Skripte; siehe [backup.md](backup.md) |
| `gitlab_docker_backup_auto_enabled` | `true` | Nur wenn `true`: `/etc/cron.d/gitlab-backup` auf dem GitLab-Host |
| `gitlab_docker_backup_time` | `03:00` | Tägliche Uhrzeit (HH:MM, 24h), wenn `gitlab_docker_backup_cron` leer |
| `gitlab_docker_backup_cron` | `""` | Optional: fünf Cron-Felder; leer = aus `gitlab_docker_backup_time` |
| `gitlab_docker_backup_keep_time` | `604800` | Aufbewahrung in Sekunden (Standard 7 Tage); `0` = alle Archive behalten ([Backup-Doku](https://docs.gitlab.com/omnibus/settings/backups.html)) |
| `gitlab_signup_enabled` | `false` | Nur **`docker_compose`**: `gitlab_rails['gitlab_signup_enabled']` — Registrierung auf der Anmeldeseite |
| `gitlab_docker_runner_enabled` | `false` | **`docker_compose`** / Proxmox-Docker: `gitlab/gitlab-runner` im gleichen Compose-Stack (Docker-Executor) |
| `gitlab_docker_runner_autoregister` | `true` | Leeres `gitlab_docker_runner_token`: Bootstrap-Skript legt Instance-Runner per API an (`glrt-…`); Log: `/var/log/gitlab-runner-autoregister.log` |
| `gitlab_docker_runner_token` | `""` | Optional `glrt-…` aus der UI; bei gesetztem Token wird Autoregister übersprungen |
| `gitlab_docker_runner_image` | `gitlab/gitlab-runner:alpine-v17.11.0` | Runner-Container-Image |
| `gitlab_docker_runner_tags` | `["docker"]` | Runner-Tags (`tag_list` in `config.toml`); ignoriert wenn `gitlab_docker_runner_buildah_enabled` |
| `gitlab_docker_runner_buildah_enabled` | `false` | Drei Buildah-Instance-Runner (`buildah-rootless`, `buildah-multiarch`, `buildah-privileged`); erfordert Autoregister + leeren Token; siehe [runner-buildah.md](runner-buildah.md) |
| `gitlab_docker_runner_buildah_default_image` | `quay.io/buildah/stable` | Empfohlenes Job-Image in CI; nicht in `config.toml` |
| `gitlab_admin` | `{ enabled = false, username = "gadmin" }` | Docker-Host-Admin (Cloud-Init): Home unter `/home/<username>`, Gruppen `sudo` + `docker`, SSH mit gleichem Key wie root; unabhängig vom GitLab-App-User `gadmin` in `gitlab.tf` |
| `gitlab_docker_traefik_proxy_ipv4` | `172.31.191.247` | Traefik-IP für `extra_hosts` am Runner-Container (FQDN → Traefik, damit Coordinator-API per HTTPS erreichbar ist) |
| `gitlab_docker_plantuml_enabled` | `true` | **`docker_compose`** / Proxmox-Docker: `plantuml/plantuml-server` im Stack, NGINX-Proxy `/-/plantuml/` ([PlantUML-Doku](https://docs.gitlab.com/administration/integration/plantuml/)) |
| `gitlab_docker_plantuml_image` | `plantuml/plantuml-server:tomcat` | PlantUML-Container-Image |
| `artifacts_enabled` | `true` | **`docker_compose`**: CI job artifacts in `gitlab.rb`; Host `./artifacts/data` → `artifacts_path` ([Doku](https://docs.gitlab.com/administration/cicd/job_artifacts/)) |
| `artifacts_path` | `/var/opt/gitlab/gitlab-rails/shared/artifacts` | Artifacts-Verzeichnis im GitLab-Container (muss unter `/var/opt/gitlab/` liegen) |
| `enable_gitlab_resources` | `false` | `true`: Gruppe/Projekte in [`gitlab.tf`](../terraform/gitlab.tf) per GitLab-Provider; erfordert **`gitlab_api_url` erreichbar** (nach erstem Apply/DNS) |
| `gitlab_early_auth_check` | `false` | `true`: Token-Check beim Plan (nur wenn GitLab schon läuft) |
| `gitlab_api_token` | `""` | GitLab API-Token (sensitiv); Pflicht bei `enable_gitlab_resources = true` (min. 8 Zeichen, keine Leerzeichen) |
| `gitlab_api_url` | `https://gitlab.com` | Basis-URL der GitLab-Instanz für den Provider (`https://gitlab.example.com` bei Self-Hosted) |
| `server_image` | `ubuntu-24.04` | Nur bei `gitlab_install_mode = none` (Hetzner-Image-Slug) |
| `gitlab_dns_record_name` | `gitlab` | Relativer A-Record bei GitLab: FQDN = `<name>.<zone>` |
| `gitlab_letsencrypt_email` | leer | ACME-Kontakt; leer → `gitlab-acme@<zone>` (nur relevant, wenn LE aktiv) |
| `gitlab_root_email` | leer | Nur **`docker_compose`** / Proxmox-Docker: `GITLAB_ROOT_EMAIL` für `root` beim ersten Start; leer → `gitlab_letsencrypt_email`, sonst `gitlab-root@<zone>` |
| `gitlab_smtp_enabled` | `false` | Nur **`docker_compose`**: `gitlab_rails['smtp_enable']` in `gitlab.rb` ([SMTP-Doku](https://docs.gitlab.com/omnibus/settings/smtp.html)) |
| `gitlab_smtp_address` | `""` | SMTP-Host; Pflicht bei `gitlab_smtp_enabled = true` |
| `gitlab_smtp_port` | `587` | SMTP-Port (587 STARTTLS, 465 SMTPS) |
| `gitlab_smtp_user_name` / `gitlab_smtp_password` | `""` | Optional (sensitiv); nur gesetzt wenn nicht leer |
| `gitlab_smtp_domain` | `""` | HELO-Domain; leer → `dns_domain` |
| `gitlab_smtp_authentication` | `login` | `login`, `plain`, `cram_md5`, `none` |
| `gitlab_smtp_enable_starttls_auto` | `true` | STARTTLS (typisch Port 587) |
| `gitlab_smtp_tls` | `false` | Implicit TLS (typisch Port 465) |
| `gitlab_email_from` | `""` | Absender; Pflicht bei aktiviertem SMTP |
| `gitlab_email_reply_to` | `""` | Optional Reply-To |
| `gitlab_letsencrypt_enabled` | `false` | Nur **`hetzner_app`**: `https` + integriertes LE (HTTP-01). Bei `docker_compose` **`gitlab_docker_traefik_acme_enabled`** verwenden. |
| `gitlab_bootstrap_wait_seconds` | `120` | Wartezeit im **per-instance**-Skript vor `gitlab-ctl reconfigure` (DNS) |
| `enable_gitlab_runner` | `false` | `true`: zweite VM (**cpx22**), Runner-Firewall, A-Record + PTR auf `<gitlab_runner_dns_label>.<zone>` |
| `gitlab_runner_install_package` | `true` | Bei aktivem Runner: Cloud-Init installiert **.deb**-Pakete von GitLab S3 (siehe [manuelle Installation](https://docs.gitlab.com/runner/install/linux-manually/)), Log `/var/log/gitlab-runner-terraform-bootstrap.log`; `false`: nur Ubuntu |
| `gitlab_runner_server_name` | `runner05` | Name des `hcloud_server` für den Runner |
| `gitlab_runner_dns_label` | `runner05` | Relativer A-Record-Name; FQDN = `<label>.<dns_domain>` (z. B. `runner05.cicd-showcase.de`; ursprünglich oft als Platzhalter `runner05.example.com` gedacht) |
| `gitlab_runner_image` | `ubuntu-24.04` | Hetzner-Image-Slug für die Runner-VM |
| `gitlab_runner_location` | `""` | Leer = gleiche Region wie `location`; sonst z. B. `fsn1`, `nbg1`, … |
| `create_hcloud_dns_zone` | `true` | `false`, wenn die Zone in Hetzner DNS schon existiert (vermeidet 409 *Zone already exists*) |
| `ssh_public_key_file` | `""` | Optional: Pfad zur `.pub`-Datei (z. B. `~/.ssh/id_ed25519.pub`), überschreibt `ssh_public_key` |
| `site_url` | `https://cicd-showcase.de` | Wird als Output `website_url` ausgegeben |
| `dns_domain` | `cicd-showcase.de` | DNS-Zonenname; bei GitLab auch Basis für `gitlab_fqdn` und PTR |
| `mail_server_ipv4` | IPv4 | Mail-**A**-Record (`module.dns`) |
| `mail_server_ipv6` | IPv6 | Mail-**AAAA**-Record |
| `mail_server_cname_target` | Hostname | CNAME-Ziel Autoconfig/Autodiscover |
| `dns_tlsa_name` | TLSA-Name | z. B. `_25._tcp.mail.example.com` |
| `mail_mx_value` | Priorität + Mail-Host | MX-Record in der Zone |
| `dmarc_value` | DMARC-String | muss `v=DMARC1` enthalten |
| `dkim_value` | DKIM-String | Lange Werte werden im DNS-Modul in Chunks aufgeteilt |
| `spf_value` | SPF-String | muss `v=spf1` enthalten |
| `tlsa_value` | TLSA-Felder | Für den TLSA-Record im Modul |
| `srv_value` | SRV-Ziel | Ziel-Hostnamen mit **trailing dot** |
| `iodef_value` / `contact_value` | `mailto:…` | CAA iodef/contact |

[`main.tf`](../terraform/main.tf) übergibt an `module.dns` u. a. **`mail_server_ipv4`**, **`mail_server_ipv6`**, **`mail_server_cname_target`**, **`dns_tlsa_name`** (Defaults in [`variables.tf`](../terraform/variables.tf)). **`spf_value`** ist separat; bei `ip4:` in SPF zur Mail-A-Record-IP passend halten.

## Outputs

| Output | Bedeutung |
|--------|-----------|
| `server_ip` | Öffentliche IPv4 des Servers |
| `server_ipv6` | Öffentliche IPv6 |
| `server_name` | Servername |
| `server_id` | Hetzner-Server-ID |
| `server_status` | Status des Servers |
| `firewall_id` / `firewall_name` | Firewall in Hetzner Cloud |
| `ssh_connection` | Vorschlag: `ssh root@<ipv4>` |
| `dns_zone_id` / `dns_zone_name` | DNS-Zone |
| `website_url` | Wert von `var.site_url` |
| `dns_domain` | Entspricht dem Zonennamen aus dem DNS-Modul |
| `gitlab_url` | Bei aktivem GitLab-Modus: `http://…` oder `https://…` (Omnibus: `gitlab_letsencrypt_enabled`; Docker: `gitlab_docker_traefik_acme_enabled`), sonst `null` |
| `gitlab_fqdn` | FQDN des GitLab-A-Records oder `null` |
| `gitlab_docker_initial_root_password` | Nur `docker_compose`: initiales `root`-Passwort (sensitiv; liegt im **Terraform State**) |
| `gitlab_docker_postgres_password` | Nur `docker_compose`: Passwort des DB-Users `gitlab` (sensitiv; State + `user_data`) |
| `renovate_fqdn` | Nur `docker_compose` + Renovate: FQDN des Renovate-A-Records (z. B. `renovate.example.com`) |
| `registry_fqdn` | Nur `docker_compose` + Registry: FQDN des Registry-A-Records (z. B. `registry.example.com`) |
| `registry_url` | Nur Registry aktiv: `http://…` oder `https://…` (wie `gitlab_url`, abhängig von `gitlab_docker_traefik_acme_enabled`) |
| `pages_fqdn` | Docker-/Proxmox-Stack + Pages: Apex-FQDN (z. B. `pages.example.com`) |
| `pages_wildcard_fqdn` | Pages aktiv: Wildcard-Muster (z. B. `*.pages.example.com`) |
| `pages_url` | Pages aktiv: `https://pages.<zone>` (bei ACME) |
| `gitlab_docker_renovate_webhook_secret` | Nur Renovate aktiv: Webhook-Token (sensitiv; muss mit `MEND_RNV_WEBHOOK_SECRET` und ggf. `gitlab_project_hook` übereinstimmen) |
| `gitlab_devops_group_id` | Nur `enable_gitlab_resources`: ID der Gruppe `devops` oder `null` |
| `gitlab_devops_project_id` | Nur `enable_gitlab_resources`: ID des Projekts `devops` (in der Gruppe) oder `null` |
| `gitlab_terraform_project_id` | Nur `enable_gitlab_resources`: ID des Projekts `terraform` (User-Namespace) oder `null` |
| `gitlab_runner_ipv4` | Öffentliche IPv4 der Runner-VM oder `null` |
| `gitlab_runner_fqdn` | FQDN des Runner-A-Records oder `null` |
| `gitlab_runner_ssh_connection` | `ssh root@<runner_ipv4>` oder `null` |
| `gitlab_runner_firewall_id` | ID der Runner-Firewall oder `null` |
