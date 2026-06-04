# gitlab-terraform-hcloud

Dieses Repository enthält Terraform-Code für **Hetzner Cloud**: einen Hauptserver mit Firewall, optionalem PTR und einer **Hetzner-DNS-Zone** inklusive Web- und Mail-Records. Über **`gitlab_install_mode`** steuerst du die **GitLab-Plattform**: aus (`none`), **Hetzner-App-Image** plus Omnibus-Cloud-Init (`hetzner_app`), **Debian-VM mit Docker Compose** auf Hetzner (`docker_compose`: GitLab CE, Traefik, PostgreSQL, **Container Registry**, optional **GitLab Runner** im Compose-Stack, optional **Mend Renovate CE**), oder **Proxmox QEMU-VMs** mit demselben Compose-Cloud-Init (`proxmox`). Optional eine **zweite VM als GitLab Runner** (`cpx22`) mit automatischer Installation der offiziellen GitLab-Runner-`.deb`-Pakete.

Unabhängig davon kann **`enable_gitlab_resources`** Gruppen und Projekte per **GitLab-API** in [`gitlab.tf`](terraform/gitlab.tf) anlegen (Provider [`gitlabhq/gitlab`](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs)).

Provider: [`hetznercloud/hcloud`](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs), [`hashicorp/random`](https://registry.terraform.io/providers/hashicorp/random/latest/docs), [`gitlabhq/gitlab`](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs) (siehe [`terraform/provider.tf`](terraform/provider.tf)).

## Repository-Layout

| Pfad | Inhalt |
|------|--------|
| [`terraform/`](terraform/) | Terraform/OpenTofu: `*.tf`, [`modules/`](terraform/modules/), [`templates/`](terraform/templates/), `terraform.tfvars.example`, Lockfile, TFLint |
| Root | Diese [`README.md`](README.md), [`CHANGELOG.md`](CHANGELOG.md), [`Makefile`](Makefile), [`.github/`](.github/), [`renovate.json`](renovate.json) |

Alle Befehle `terraform` / `tofu` und `terraform.tfvars` gehören in den Ordner **`terraform/`** (oder `make` vom Repo-Root aus).

**[Tech Stack](#tech-stack)** • **[Architektur](#architektur)** • **[Schnellstart](#schnellstart)** • **[GitLab-Installationsmodi](#gitlab-installationsmodi)**

## Tech Stack

<table>
  <tr>
    <th>Logo</th>
    <th>Name</th>
    <th>Beschreibung</th>
  </tr>
  <tr>
    <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/terraform/terraform-original.svg" alt="Terraform"></td>
    <td><a href="https://developer.hashicorp.com/terraform">Terraform</a> / <a href="https://opentofu.org/">OpenTofu</a></td>
    <td>Infrastructure as Code für Hetzner Cloud (Server, Firewall, DNS, optional GitLab-API-Ressourcen). Konfiguration unter <a href="terraform/">terraform/</a>; siehe auch <a href="#terraform-und-opentofu">Terraform und OpenTofu</a>.</td>
  </tr>
  <tr>
    <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/hetzner.png" alt="Hetzner Cloud"></td>
    <td><a href="https://www.hetzner.com/cloud">Hetzner Cloud</a></td>
    <td>Cloud-Provider für VM, Firewall und SSH-Keys (<code>hcloud_token</code>). Standard-Stack: ein <code>cpx*</code>-Server in <code>fsn1</code> / <code>nbg1</code> / …</td>
  </tr>
  <tr>
    <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/hetzner.png" alt="Hetzner DNS"></td>
    <td><a href="https://dns.hetzner.com/">Hetzner DNS</a></td>
    <td>Authoritative DNS-Zone (<code>dns_domain</code>), A-Records für GitLab/Registry/Renovate/Runner und Mail-Records. Separates API-Token <code>hetzner_api_key</code> (nicht <code>hcloud_token</code>).</td>
  </tr>
  <tr>
    <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/gitlab/gitlab-original.svg" alt="GitLab"></td>
    <td><a href="https://about.gitlab.com/install/">GitLab CE</a></td>
    <td>CI/CD-Plattform: <code>hetzner_app</code> (Hetzner App-Image + Omnibus) oder <code>docker_compose</code> (<code>gitlab/gitlab-ce</code> im Compose-Stack). Siehe <a href="#gitlab-installationsmodi">GitLab-Installationsmodi</a>.</td>
  </tr>
  <tr>
    <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/docker/docker-original.svg" alt="Docker"></td>
    <td><a href="https://docs.docker.com/compose/">Docker Compose</a></td>
    <td>Bei <code>gitlab_install_mode = docker_compose</code>: GitLab CE, Traefik, PostgreSQL, optional Runner, PlantUML und Renovate CE unter <code>/opt/gitlab</code> auf Debian (<code>gitlab_docker_host_image</code>).</td>
  </tr>
  <tr>
    <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/traefikproxy/traefikproxy-original.svg" alt="Traefik"></td>
    <td><a href="https://traefik.io/traefik">Traefik</a></td>
    <td>Reverse Proxy und TLS-Terminierung (HTTP/HTTPS, optional ACME DNS-01 über Hetzner). Image: <code>gitlab_docker_traefik_image</code> (Standard <code>traefik:v3.7.1</code>).</td>
  </tr>
  <tr>
    <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/postgresql/postgresql-original.svg" alt="PostgreSQL"></td>
    <td><a href="https://www.postgresql.org/">PostgreSQL</a></td>
    <td>Externe Datenbank für GitLab im Compose-Modus (<code>postgres:16-alpine</code>, nur internes Netz <code>socket_proxy</code>).</td>
  </tr>
  <tr>
    <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/gitlab/gitlab-original.svg" alt="GitLab Runner"></td>
    <td><a href="https://docs.gitlab.com/runner/">GitLab Runner</a></td>
    <td>Optional im Compose-Stack (<code>gitlab_docker_runner_enabled</code>, Autoregister per API) oder als eigene Hetzner-VM (<code>enable_gitlab_runner</code>, <code>.deb</code>-Installation). Siehe <a href="#gitlab-runner-im-compose-stack-autoregister">Autoregister</a>.</td>
  </tr>
  <tr>
    <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/debian/debian-original.svg" alt="Debian"></td>
    <td><a href="https://www.debian.org/">Debian</a></td>
    <td>Standard-Host-OS für <code>docker_compose</code> (<code>debian-13</code>). Cloud-Init installiert Docker Engine und startet den Stack.</td>
  </tr>
  <tr>
    <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/proxmox/proxmox-original-wordmark.svg" alt="Proxmox"></td>
    <td><a href="https://www.proxmox.com/en/products/proxmox-virtual-environment/overview">Proxmox VE</a> <em>(optional)</em></td>
    <td>Alternative Zielplattform: QEMU-VMs + Cloud-Init-Snippet aus demselben Compose-Template (<code>proxmox.tf.example</code>, <code>enable_proxmox_resources</code>). Siehe <a href="#gitlab-auf-proxmox">GitLab auf Proxmox</a>.</td>
  </tr>
  <tr>
    <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/gitlab/gitlab-original.svg" alt="GitLab Provider"></td>
    <td><a href="https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs">GitLab Terraform Provider</a></td>
    <td>Optionale API-Ressourcen (<code>enable_gitlab_resources</code>): Gruppe, Projekte, Bot-User, Renovate-Webhook in <a href="terraform/gitlab.tf">gitlab.tf</a> / Modul <a href="terraform/modules/gitlab-api/">gitlab-api</a>.</td>
  </tr>
  <tr>
    <td><img width="32" src="https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/renovatebot.svg" alt="Renovate" width="32"></td>
    <td><a href="https://docs.renovatebot.com/">Renovate</a></td>
    <td>Dependency-Updates: <a href="renovate.json">renovate.json</a> im Repo-Root (Mend GitHub App auf github.com); optional Mend Renovate CE im Compose-Stack (<code>gitlab_docker_renovate_enabled</code>).</td>
  </tr>
  <tr>
    <td><img width="32" src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/github/github-original.svg" alt="GitHub Actions"></td>
    <td><a href="https://docs.github.com/en/actions">GitHub Actions</a> / <a href="https://docs.gitlab.com/ee/ci/">GitLab CI</a></td>
    <td>Qualitätssicherung: <code>fmt</code>, <code>validate</code>, TFLint (<a href=".github/workflows/terraform.yml">.github/workflows/terraform.yml</a>, <a href=".gitlab-ci.yml">.gitlab-ci.yml</a>, <code>make ci</code>).</td>
  </tr>
</table>

Orientierung am Aufbau von <a href="https://github.com/phsaurav/Home-Lab/blob/main/README.md">PH's HomeLab — Tech Stack</a>.

## Inhaltsverzeichnis

- [gitlab-terraform-hcloud](#gitlab-terraform-hcloud)
  - [Repository-Layout](#repository-layout)
  - [Tech Stack](#tech-stack)
  - [Inhaltsverzeichnis](#inhaltsverzeichnis)
  - [Architektur](#architektur)
    - [Provider](#provider)
  - [Voraussetzungen](#voraussetzungen)
  - [Schnellstart](#schnellstart)
    - [Plan: GitLab-DNS oder Proxmox-401](#plan-gitlab-dns-oder-proxmox-401)
  - [Variablen (Root)](#variablen-root)
    - [Ohne Default (bei `apply` erforderlich)](#ohne-default-bei-apply-erforderlich)
    - [Mit Default (optional überschreibbar)](#mit-default-optional-überschreibbar)
  - [Outputs](#outputs)
  - [GitLab-Installationsmodi](#gitlab-installationsmodi)
    - [`hetzner_app` (Hetzner App-Image)](#hetzner_app-hetzner-app-image)
    - [`docker_compose` (GitLab CE + Traefik)](#docker_compose-gitlab-ce--traefik)
    - [Web IDE (`docker_compose`)](#web-ide-docker_compose)
    - [Container Registry (`docker_compose`)](#container-registry-docker_compose)
    - [Renovate CE (`docker_compose`)](#renovate-ce-docker_compose)
    - [GitLab Runner im Compose-Stack (Autoregister)](#gitlab-runner-im-compose-stack-autoregister)
      - [Automatisch (Autoregister, empfohlen)](#automatisch-autoregister-empfohlen)
      - [Manuell (Token aus der UI)](#manuell-token-aus-der-ui)
      - [Manuell auf einer bestehenden VM](#manuell-auf-einer-bestehenden-vm)
      - [Troubleshooting](#troubleshooting)
  - [GitLab-Provider-Ressourcen (`gitlab.tf`)](#gitlab-provider-ressourcen-gitlabtf)
  - [GitLab Runner (optionale zweite VM)](#gitlab-runner-optionale-zweite-vm)
  - [GitLab auf Proxmox](#gitlab-auf-proxmox)
    - [Voraussetzungen auf Proxmox](#voraussetzungen-auf-proxmox)
    - [Einrichtung in Proxmox (Checkliste)](#einrichtung-in-proxmox-checkliste)
    - [Terraform-Ressourcen](#terraform-ressourcen)
    - [Variablen (Proxmox)](#variablen-proxmox)
    - [Nach dem Apply](#nach-dem-apply)
    - [Abgrenzung zu Hetzner-Modi](#abgrenzung-zu-hetzner-modi)
    - [Bekannte Punkte / Troubleshooting](#bekannte-punkte--troubleshooting)
  - [Module im Detail](#module-im-detail)
  - [Sicherheit und Betrieb](#sicherheit-und-betrieb)
  - [Cloud-Init und user\_data](#cloud-init-und-user_data)
  - [Terraform und OpenTofu](#terraform-und-opentofu)
  - [Qualitätssicherung (lokal / CI)](#qualitätssicherung-lokal--ci)
  - [Bekannte Einschränkungen](#bekannte-einschränkungen)
  - [Weiterführende Links](#weiterführende-links)
- [Test for Renovate App](#test-for-renovate-app)

## Architektur

Die Wurzelkonfiguration [`main.tf`](terraform/main.tf) bindet die Module **Firewall** → **Server** → **DNS** (A-Record für den Haupt-Host). Optional zusätzlich: **Firewall (Runner)** → **Server (Runner)** und eine **`hcloud_zone_record`** für den Runner in derselben DNS-Zone. Alle Ressourcen nutzen dieselbe Hetzner-Cloud-API.

```mermaid
flowchart LR
  subgraph root [Root main.tf]
    FW[module.firewall]
    SRV[module.server]
    DNS[module.dns]
    FWR[module.firewall_runner]
    RUN[module.gitlab_runner]
    AR[hcloud_zone_record_runner]
    RNV[hcloud_zone_record_renovate]
    REG[hcloud_zone_record_registry]
  end
  FW -->|firewall_ids| SRV
  SRV -->|server_ipv4| DNS
  SRV -->|IPv4| RNV
  SRV -->|IPv4| REG
  FWR -->|firewall_ids| RUN
  DNS -->|zone_name| AR
  DNS -->|zone_name| RNV
  DNS -->|zone_name| REG
  RUN -->|IPv4| AR
  HCAPI[Hetzner_Cloud_API]
  GLAPI[GitLab_API]
  FW --> HCAPI
  SRV --> HCAPI
  DNS --> HCAPI
  FWR --> HCAPI
  RUN --> HCAPI
```

Optional (nur bei `enable_gitlab_resources = true`): [`gitlab.tf`](terraform/gitlab.tf) nutzt die **GitLab-API** (`gitlab_group`, `gitlab_project`) — unabhängig von `gitlab_install_mode`.

| Modul / Ressource | Inhalt (Kurz) |
|--------|----------------|
| [`modules/firewall`](terraform/modules/firewall) | `hcloud_firewall`: eingehend u. a. SSH 22, **TCP 2424**, HTTP/HTTPS 80/443, DNS 53 (TCP/UDP), ICMP, Node Exporter; **ausgehend** DNS 53 (TCP/UDP), HTTP 80, HTTPS 443; bei **`gitlab_smtp_enabled`** zusätzlich SMTP (**TCP `gitlab_smtp_port`**, z. B. 587/465). |
| [`modules/server`](terraform/modules/server) | `hcloud_ssh_key`, `hcloud_server` (Image z. B. Ubuntu 24.04, `gitlab` bei `hetzner_app`, oder `gitlab_docker_host_image` bei `docker_compose`), Firewall-IDs, optional `hcloud_rdns`, optional `user_data` (Cloud-Init für GitLab oder Runner). |
| [`modules/dns`](terraform/modules/dns) | `hcloud_zone` (primary) und Records: Web-A-Record, Mail-A/AAAA/MX, Autoconfig/Autodiscover, DMARC/DKIM/SPF, CAA, TLSA, SRV. |
| [`modules/proxmox`](terraform/modules/proxmox) | `proxmox_vm_qemu` GitLab (+ optional Runner), Snippet-Upload für Docker-Compose-Cloud-Init (`cicustom`). Nur bei `enable_proxmox_resources`. |
| `module.firewall_runner` + `module.gitlab_runner` + `hcloud_zone_record.gitlab_runner` | Nur bei `enable_gitlab_runner = true`: Firewall (SSH/ICMP ein, Egress DNS/HTTP/HTTPS), **cpx22**-Server, A-Record **`<gitlab_runner_dns_label>.<zone>`**. |
| `hcloud_zone_record.renovate` | Nur bei `docker_compose` + **`gitlab_docker_renovate_enabled`**: A-Record **`<gitlab_docker_renovate_dns_label>.<zone>`** (Standard: `renovate.<zone>`) → gleiche Server-IPv4 wie GitLab. |
| `hcloud_zone_record.registry` | Nur bei `docker_compose` + **`gitlab_docker_registry_enabled`** (Standard `true`): A-Record **`<gitlab_docker_registry_dns_label>.<zone>`** (Standard: `registry.<zone>`) → gleiche Server-IPv4 wie GitLab. |

### Provider

In [`provider.tf`](terraform/provider.tf):

- **`hcloud`** (Standard) und **`hcloud.dns`** (Alias, gleiches Token): Server, Firewall, DNS (`providers = { hcloud.dns = hcloud.dns }` im DNS-Modul).
- **`gitlab`**: `token = var.gitlab_api_token`, `base_url = var.gitlab_api_url`. Wird nur für Ressourcen in [`gitlab.tf`](terraform/gitlab.tf) benötigt, wenn **`enable_gitlab_resources = true`**.
- **`proxmox`** ([`telmate/proxmox`](https://registry.terraform.io/providers/telmate/proxmox/latest/docs), `<=3.0.2-rc07`): optional in [`provider_proxmox.tf`](terraform/provider_proxmox.tf) (Vorlage [`provider_proxmox.tf.example`](terraform/provider_proxmox.tf.example)); VMs über [`module.proxmox`](terraform/modules/proxmox) bei **`enable_proxmox_resources = true`**.
- **`random`**: Passwörter für `docker_compose` (GitLab-`root`, PostgreSQL, optional Renovate-Webhook und Server-API-Secret).

## Voraussetzungen

- [Terraform](https://developer.hashicorp.com/terraform/install) **>= 1.14.4** (empfohlen; CI nutzt 1.14.4) **oder** [OpenTofu](https://opentofu.org/docs/intro/install/) **>= 1.9.0** (z. B. 1.12.x) — siehe [Terraform und OpenTofu](#terraform-und-opentofu)
- Hetzner Cloud **API-Token** mit passenden Rechten (Server, Firewalls, SSH-Keys, DNS je nach Nutzung)
- Öffentlicher **SSH-Schlüssel** für den Root-Zugang auf dem Server
- Für DNS: Domain, die du in Hetzner DNS verwalten willst (Zonenname = Variable `dns_domain` bzw. dein Override)
- Für **`enable_gitlab_resources = true`**: GitLab-Instanz erreichbar unter **`gitlab_api_url`**, **Personal/Project Access Token** mit Rechten zum Anlegen von Gruppen und Projekten (`gitlab_api_token`)
- Für **`gitlab_docker_renovate_enabled = true`** (nur mit `gitlab_install_mode = docker_compose`): [Mend Renovate CE](https://www.mend.io/renovate-community/) **License Key**, GitLab-**PAT** für den Renovate-Bot (`gitlab_docker_renovate_gitlab_pat`, `api`-Scope auf deiner Instanz)
- Für **Proxmox** (optional): laufendes **Proxmox VE**, API-Token mit VM-Rechten, QEMU Guest Agent auf den VMs, Netzwerk-Bridge (z. B. `vmbr1`) — Details unter [GitLab auf Proxmox](#gitlab-auf-proxmox)

## Schnellstart

1. Repository klonen und ins Verzeichnis wechseln.
2. In **`terraform/`** wechseln und **`terraform.tfvars`** anlegen (wird per [`.gitignore`](.gitignore) ignoriert – keine Secrets committen):

   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   ```

   Orientierung: [`terraform/terraform.tfvars.example`](terraform/terraform.tfvars.example). Mindestens die in der Tabelle unten als **ohne Default** geführten Variablen setzen.

3. Module und Provider laden:

   ```bash
   terraform init
   ```

4. Plan und Apply:

   ```bash
   terraform plan
   terraform apply
   ```

Nach erfolgreichem Apply zeigen [`outputs.tf`](terraform/outputs.tf) u. a. öffentliche IPs, SSH-Befehl und DNS-Zoneninformationen an.

### Plan: GitLab-DNS oder Proxmox-401

| Fehler | Ursache | Maßnahme |
|--------|---------|----------|
| `lookup gitlab.cicd-showcase.de: no such host` | Terraform **refresht** GitLab-API-Ressourcen im State, bevor Server/DNS existieren | **Erst Apply** für Server + DNS (`enable_gitlab_resources = false`), danach `true`; oder `make plan-no-refresh` / `terraform plan -refresh=false`; bei totem Alt-State: `terraform state rm` für `gitlab_*` / `module.gitlab_api` |
| `401` / `connection refused` (Proxmox) | `proxmox.tf` / `provider_proxmox.tf` vorhanden, obwohl Proxmox aus ist | Dateien löschen/umbenennen; Hetzner-only: `enable_proxmox_resources = false` und keine kopierten `proxmox*.tf` |
| `Attribute redefined` (`proxmox_api_token`) | Token zweimal in `terraform.tfvars` | Nur eine Zeile; `proxmox_api_token_id` ist **nicht** das Secret |
| Proxmox 401 bei `enable_proxmox_resources = true` | Token/ID falsch | `proxmox_api_token` + `proxmox_api_token_id` in `terraform.tfvars` prüfen |

Empfohlene **Zwei-Phasen-Bootstrap** für neues Hetzner-`docker_compose`:

1. `enable_gitlab_resources = false` → `terraform apply` (Server, DNS, Compose)
2. Warten bis `https://gitlab.<zone>` erreichbar → `enable_gitlab_resources = true` → erneut `apply`

**GitLab Runner im Compose-Stack:** Mit **`gitlab_docker_runner_autoregister = true`** (Standard) und leerem **`gitlab_docker_runner_token`** läuft die Registrierung per Bootstrap-Skript automatisch nach GitLab-Start — kein manuelles `glrt-…` nötig (siehe [GitLab Runner im Compose-Stack (Autoregister)](#gitlab-runner-im-compose-stack-autoregister)).

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
| `gitlab_install_mode` | `none` | `none`: kein GitLab; `hetzner_app`: Image `gitlab` + [`templates/gitlab-cloud-init.yaml.tpl`](terraform/templates/gitlab-cloud-init.yaml.tpl); `docker_compose`: `gitlab_docker_host_image` (Standard `debian-13`) + [`templates/gitlab-docker-cloud-init.yaml.tpl`](terraform/templates/gitlab-docker-cloud-init.yaml.tpl), Stack unter `/opt/gitlab`; `proxmox`: QEMU-VM(s) via [`module.proxmox`](terraform/modules/proxmox) + gleiches Compose-Template (siehe [GitLab auf Proxmox](#gitlab-auf-proxmox)) |
| `proxmox_gitlab_vmid` / `proxmox_runner_vmid` | `0` | Nur bei `gitlab_install_mode = proxmox`: feste Proxmox-VM-ID (100–999999999); `0` = nächste freie ID (kein Plan-Check). Bei ID > 0: Verfügbarkeit per Proxmox-API bei `plan` ([`proxmox_data.tf`](terraform/proxmox_data.tf.example)) |
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
| `gitlab_docker_traefik_acme_enabled` | `false` | `true`: Traefik Let’s Encrypt (DNS-01 via Hetzner); nur bei `gitlab_install_mode = docker_compose`; ACME-Mail über `gitlab_letsencrypt_email` bzw. Fallback `gitlab-acme@<zone>` |
| `gitlab_docker_backup_enabled` | `true` | **`docker_compose`** oder **`hetzner_app`**: `gitlab_rails` Backup in `gitlab.rb`, Host-Cron + Backup-Skript |
| `gitlab_docker_backup_keep_time` | `604800` | Aufbewahrung in Sekunden (Standard 7 Tage); `0` = alle Archive behalten ([Backup-Doku](https://docs.gitlab.com/omnibus/settings/backups.html)) |
| `gitlab_docker_backup_cron` | `0 3 * * *` | Cron-Zeitplan auf dem GitLab-Host für `gitlab-backup create` (fünf Felder) |
| `gitlab_signup_enabled` | `false` | Nur **`docker_compose`**: `gitlab_rails['gitlab_signup_enabled']` — Registrierung auf der Anmeldeseite |
| `gitlab_docker_runner_enabled` | `false` | **`docker_compose`** / Proxmox-Docker: `gitlab/gitlab-runner` im gleichen Compose-Stack (Docker-Executor) |
| `gitlab_docker_runner_autoregister` | `true` | Leeres `gitlab_docker_runner_token`: Bootstrap-Skript legt Instance-Runner per API an (`glrt-…`); Log: `/var/log/gitlab-runner-autoregister.log` |
| `gitlab_docker_runner_token` | `""` | Optional `glrt-…` aus der UI; bei gesetztem Token wird Autoregister übersprungen |
| `gitlab_docker_runner_image` | `gitlab/gitlab-runner:alpine-v17.11.0` | Runner-Container-Image |
| `gitlab_docker_runner_tags` | `["docker"]` | Runner-Tags (`tag_list` in `config.toml`) |
| `gitlab_docker_traefik_proxy_ipv4` | `172.31.191.247` | Traefik-IP für `extra_hosts` am Runner-Container (FQDN → Traefik, damit Coordinator-API per HTTPS erreichbar ist) |
| `gitlab_docker_plantuml_enabled` | `true` | **`docker_compose`** / Proxmox-Docker: `plantuml/plantuml-server` im Stack, NGINX-Proxy `/-/plantuml/` ([PlantUML-Doku](https://docs.gitlab.com/administration/integration/plantuml/)) |
| `gitlab_docker_plantuml_image` | `plantuml/plantuml-server:tomcat` | PlantUML-Container-Image |
| `artifacts_enabled` | `true` | **`docker_compose`**: CI job artifacts in `gitlab.rb`; Host `./artifacts/data` → `artifacts_path` ([Doku](https://docs.gitlab.com/administration/cicd/job_artifacts/)) |
| `artifacts_path` | `/var/opt/gitlab/gitlab-rails/shared/artifacts` | Artifacts-Verzeichnis im GitLab-Container (muss unter `/var/opt/gitlab/` liegen) |
| `enable_gitlab_resources` | `false` | `true`: Gruppe/Projekte in [`gitlab.tf`](terraform/gitlab.tf) per GitLab-Provider; erfordert **`gitlab_api_url` erreichbar** (nach erstem Apply/DNS) |
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

[`main.tf`](terraform/main.tf) übergibt an `module.dns` u. a. **`mail_server_ipv4`**, **`mail_server_ipv6`**, **`mail_server_cname_target`**, **`dns_tlsa_name`** (Defaults in [`variables.tf`](terraform/variables.tf)). **`spf_value`** ist separat; bei `ip4:` in SPF zur Mail-A-Record-IP passend halten.

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
| `gitlab_docker_renovate_webhook_secret` | Nur Renovate aktiv: Webhook-Token (sensitiv; muss mit `MEND_RNV_WEBHOOK_SECRET` und ggf. `gitlab_project_hook` übereinstimmen) |
| `gitlab_devops_group_id` | Nur `enable_gitlab_resources`: ID der Gruppe `devops` oder `null` |
| `gitlab_devops_project_id` | Nur `enable_gitlab_resources`: ID des Projekts `devops` (in der Gruppe) oder `null` |
| `gitlab_terraform_project_id` | Nur `enable_gitlab_resources`: ID des Projekts `terraform` (User-Namespace) oder `null` |
| `gitlab_runner_ipv4` | Öffentliche IPv4 der Runner-VM oder `null` |
| `gitlab_runner_fqdn` | FQDN des Runner-A-Records oder `null` |
| `gitlab_runner_ssh_connection` | `ssh root@<runner_ipv4>` oder `null` |
| `gitlab_runner_firewall_id` | ID der Runner-Firewall oder `null` |

## GitLab-Installationsmodi

Steuerung über **`gitlab_install_mode`**: `none` | `hetzner_app` | `docker_compose` | `proxmox` (Default: `none`).

**Migration** von der früheren Variable `enable_gitlab_app`: `enable_gitlab_app = true` → `gitlab_install_mode = "hetzner_app"`; `false` → `"none"`.

### `hetzner_app` (Hetzner App-Image)

Wenn `gitlab_install_mode = "hetzner_app"`:

- Server-Image: **`gitlab`** (vgl. [hetznercloud/apps – GitLab](https://github.com/hetznercloud/apps/tree/main/apps/hetzner/gitlab)).
- Automatisierung: **systemd-Oneshot** `gitlab-terraform-bootstrap.service` + Hintergrund-**Scheduler** `/usr/local/sbin/gitlab-terraform-schedule-bootstrap.sh` (wartet bis `gitlab_setup` in `/root/.bashrc` sichtbar ist oder Timeout, dann `systemctl start`), damit der Dienst auch startet, wenn `enable` bei bereits aktivem `multi-user` nicht ausreicht. Zusätzlich wird **`/opt/hcloud/gitlab_setup.sh`** durch ein No-Op-Skript ersetzt (Fallback, falls noch ein Aufruf in der Shell-RC bleibt).
- DNS: A-Record **`gitlab_dns_record_name`** (Standard `gitlab`) → Server-IPv4; PTR (IPv4/IPv6) auf dieselbe FQDN, damit Zertifikatsprüfungen konsistent bleiben.
- **Let’s Encrypt:** Mit `gitlab_letsencrypt_enabled = false` (Standard) setzt Cloud-Init `external_url` auf **http**, schreibt **`letsencrypt['enable'] = false`** und **`letsencrypt['auto_enabled'] = false`**, setzt **`nginx['listen_https'] = false`**, und setzt in **`/etc/gitlab/gitlab-secrets.json`** ebenfalls **`letsencrypt.auto_enabled`** auf **`false`**. Grund: Omnibus kann LE sonst über die Auto-Enable-Heuristik und den in den Secrets persistierten `auto_enabled`-Schalter wieder aktivieren (siehe [MR !2353](https://gitlab.com/gitlab-org/omnibus-gitlab/-/merge_requests/2353)), selbst wenn zuvor schon Zeilen in `gitlab.rb` angepasst wurden.
- **Bootstrap erneut:** War früher `ExecStartPost` mit `touch` aktiv, kann **`/var/lib/gitlab-terraform/.bootstrap-done`** trotz fehlgeschlagenem `reconfigure` existieren — entfernen und `systemctl start gitlab-terraform-bootstrap.service` erneut ausführen (oder Server mit neuem `user_data` ersetzen). Aktuelles Template setzt `.bootstrap-done` **nur nach erfolgreichem** `gitlab-ctl reconfigure`.
- **Backups:** Mit **`gitlab_docker_backup_enabled = true`** (Standard) schreibt der Bootstrap `gitlab_rails['manage_backup_path']`, `backup_path` (`/var/opt/gitlab/backups`) und `backup_keep_time` in **`/etc/gitlab/gitlab.rb`**. Cron **`/etc/cron.d/gitlab-backup`** ruft **`/usr/local/sbin/gitlab-backup.sh`** auf (`gitlab-backup create CRON=1`, `gitlab-ctl backup-etc --delete-old-backups`). Log: **`/var/log/gitlab-backup.log`**; Config-Archive: **`/etc/gitlab/config_backup/`**. Manuell: `/usr/local/sbin/gitlab-backup.sh`. **Restore:** `/usr/local/sbin/gitlab-restore.sh --list` · `gitlab-restore.sh <BACKUP_ID>` · `gitlab-restore.sh --config-only` (siehe [Restore-Doku](https://docs.gitlab.com/administration/backup_restore/restore_gitlab/)).

Offizielle App-Doku: [Hetzner Cloud Apps – GitLab CE](https://docs.hetzner.com/cloud/apps/list/gitlab-ce/).

### `docker_compose` (GitLab CE + Traefik)

Wenn `gitlab_install_mode = "docker_compose"`:

- Server-Image: **`gitlab_docker_host_image`** (Standard **`debian-13`**). Vor Produktion den Slug mit `hcloud image list` / Konsole prüfen.
- Cloud-Init ([`templates/gitlab-docker-cloud-init.yaml.tpl`](terraform/templates/gitlab-docker-cloud-init.yaml.tpl)): installiert Docker Engine + Compose-Plugin, legt den Stack unter **`/opt/gitlab`** an und startet **`docker compose up -d`**. Log: **`/var/log/gitlab-docker-bootstrap.log`**.

**Persistenz auf dem Host** (Bind-Mounts statt anonymer Docker-Volumes):

| Host-Pfad | Container / Zweck |
|-----------|-------------------|
| `/opt/gitlab/traefik/traefik.yml` | Traefik-Statikconfig |
| `/opt/gitlab/traefik/.env` | Traefik-Umgebung (`HETZNER_API_TOKEN`, `ACME_EMAIL`, …) |
| `/opt/gitlab/traefik/dynamic_conf/` | Traefik File-Provider (Middlewares, `tls.yml`) |
| `/opt/gitlab/traefik/certs/` | ACME-Speicher (`acme_letsencrypt.json`, `tls_letsencrypt.json`) → `/certs` im Traefik-Container |
| `/opt/gitlab/postgres/data/` | PostgreSQL-Daten → `/var/lib/postgresql/data` |
| `/opt/gitlab/data/config/` | GitLab Omnibus → `/etc/gitlab` (inkl. **`gitlab.rb`**) |
| `/opt/gitlab/data/logs/` | GitLab-Logs → `/var/log/gitlab` |
| `/opt/gitlab/data/gitlab/` | GitLab-Anwendungsdaten → `/var/opt/gitlab` |
| `/opt/gitlab/backups/` | GitLab-Backup-Archive → `/var/opt/gitlab/backups` (wenn **`gitlab_docker_backup_enabled`**) |
| `/opt/gitlab/artifacts/data/` | CI job artifacts → `artifacts_path` (wenn **`artifacts_enabled`**) |
| `/opt/gitlab/scripts/gitlab-backup.sh` | Host-Skript für Cron (Application + `gitlab-ctl backup-etc`) |
| `/opt/gitlab/scripts/gitlab-restore.sh` | Restore: `--list`, `<BACKUP_ID>`, `--config-only` |
| `/opt/gitlab/registry/data/` | Registry-Blobs → `/var/opt/gitlab/gitlab-rails/shared/registry` (wenn **`gitlab_docker_registry_enabled`**) |
| `/opt/gitlab/registry/certs/` | Omnibus-Registry-Zertifikatsverzeichnis → `/etc/gitlab/ssl/registry` (öffentliches TLS via Traefik/ACME in `traefik/certs/`) |
| `/opt/gitlab/gitlab-runner/` | `config.toml` für **`gitlab/gitlab-runner`** (wenn **`gitlab_docker_runner_enabled`**) |
| `/opt/gitlab/scripts/gitlab-runner-autoregister.sh` | Bootstrap: Instance-Runner per API anlegen (wenn Autoregister aktiv) |

**GitLab-Konfiguration** folgt der [GitLab-Docker-Doku](https://docs.gitlab.com/install/docker/configuration/): Cloud-Init schreibt **`/opt/gitlab/data/config/gitlab.rb`** (im Container `/etc/gitlab/gitlab.rb`). Dort u. a. `external_url`, externe PostgreSQL, NGINX nur HTTP (TLS bei Traefik), `gitlab_rails['gitlab_shell_ssh_port'] = 2424`, **`gitlab_rails['gitlab_signup_enabled']`** (Terraform: **`gitlab_signup_enabled`**, Standard `false`). **`GITLAB_OMNIBUS_CONFIG`** wird nicht verwendet. Änderungen auf der VM:

```bash
editor /opt/gitlab/data/config/gitlab.rb
docker compose exec gitlab gitlab-ctl reconfigure
```

Initiales **`root`**: Umgebungsvariable **`GITLAB_ROOT_PASSWORD`** (Wert aus Terraform-`random_password`; Output **`gitlab_docker_initial_root_password`**, sensitiv, im **State**).

**E-Mail (SMTP):** Mit **`gitlab_smtp_enabled = true`** schreibt Terraform die [Omnibus-SMTP-Einstellungen](https://docs.gitlab.com/omnibus/settings/smtp.html) in `gitlab.rb` (`smtp_enable`, Adresse, Port, Auth, `gitlab_email_from`, …) und öffnet in der **Hetzner-Firewall** ausgehend **TCP auf `gitlab_smtp_port`**. Bei `false` wird `gitlab_rails['smtp_enable'] = false` gesetzt (keine SMTP-Egress-Regel). Nach Änderung: `gitlab-ctl reconfigure`.

**Backups (`docker_compose`):** Mit **`gitlab_docker_backup_enabled = true`** (Standard) setzt Cloud-Init in `gitlab.rb`:

- `gitlab_rails['manage_backup_path'] = true`
- `gitlab_rails['backup_path'] = "/var/opt/gitlab/backups"`
- `gitlab_rails['backup_keep_time']` aus **`gitlab_docker_backup_keep_time`**

Zusätzlich: Cron **`/etc/cron.d/gitlab-backup`** (Zeitplan **`gitlab_docker_backup_cron`**) ruft **`/opt/gitlab/scripts/gitlab-backup.sh`** auf. Das Skript führt aus:

1. `docker compose exec -T gitlab gitlab-backup create CRON=1` — Application-Backup (inkl. DB-Dump über die in `gitlab.rb` konfigurierte externe PostgreSQL)
2. `docker compose exec -T gitlab gitlab-ctl backup-etc --delete-old-backups` — Archiv von `gitlab.rb` / Secrets unter `/etc/gitlab/config_backup/` (auf dem Host: `/opt/gitlab/data/config/config_backup/`)

Archive liegen auf dem Host unter **`/opt/gitlab/backups/`**; Log: **`/var/log/gitlab-backup.log`**. Manuell:

```bash
cd /opt/gitlab
/opt/gitlab/scripts/gitlab-backup.sh
# oder nur Application-Backup:
docker compose exec -T gitlab gitlab-backup create
```

**Restore:** `/opt/gitlab/scripts/gitlab-restore.sh --list` · `/opt/gitlab/scripts/gitlab-restore.sh <BACKUP_ID>` · `--config-only` für `gitlab.rb`/Secrets aus `config_backup/`. Optional `GITLAB_RESTORE_FORCE=1` ohne Rückfrage.

**Wichtig:** `gitlab-secrets.json` und `gitlab.rb` separat sichern ([Backup-Doku](https://docs.gitlab.com/administration/backup_restore/backup_gitlab/#data-not-included-in-a-backup)). Backups enthalten sensible Daten — Zugriff auf `/opt/gitlab/backups` einschränken und offsite kopieren.

**Traefik:** Image über **`gitlab_docker_traefik_image`**. Docker-Provider mit **`allowEmptyServices: true`**, damit der Router nicht fehlt, während der GitLab-Container startet (sonst kurz **404 page not found**). GitLab-Image-Healthcheck ist deaktiviert (`healthcheck: disable: true`), damit Traefik den Service nicht wegen `starting`/`unhealthy` ausblendet. Router für GitLab, **Registry** und Renovate mit Middleware **`default@file`** (gzip, Security-Headers, fail2ban-Plugin); Registry zusätzlich **Buffering** ohne Body-Limit für große `docker push`-Layer. Bei **`gitlab_docker_traefik_acme_enabled`**: Zertifikate per **DNS-01** (Resolver `hetzner`, Hetzner-API-Token in `.env`), optional TLS-01-Resolver `tls`; `letsencrypt` in `gitlab.rb` bleibt aus. Ohne ACME: **`gitlab_url`** und **`registry_url`** sind **`http://…`** — produktives `docker push`/`pull` über HTTPS erfordert ACME.

**Stack (Compose):**

| Service | Netze | Ports / Zugriff |
|---------|--------|-----------------|
| **traefik** | `proxy`, `socket_proxy` | Host **80/443**; statische IPs im `proxy`-Subnetz (`172.31.128.0/18`) |
| **postgres** | `socket_proxy` | nur intern; DB-Host `postgres` für GitLab |
| **gitlab** | `proxy`, `socket_proxy` | HTTP **:80** hinter Traefik (`gitlab`); optional Registry **:5050** (`registry`-Router); Git/SSH **Host 2424** → Container 22 |
| **gitlab-runner** | `proxy`, `socket_proxy` | Nur mit **`gitlab_docker_runner_enabled`**; bei Autoregister zunächst Compose-Profil **`runner`** (Start durch Skript) |
| **plantuml** | `socket_proxy` | Nur mit **`gitlab_docker_plantuml_enabled`**; Proxy `/-/plantuml/` über GitLab-NGINX |

Die **Hetzner-Firewall** öffnet **TCP 2424** (`enable_ssh_high`, Standard `true`) zusätzlich zu SSH 22 — passend zum Port-Mapping und `gitlab_shell_ssh_port`.

**Secrets:** DB-Passwort steht in `gitlab.rb` und im Terraform State (**`gitlab_docker_postgres_password`**). Traefik- und ACME-Werte: **`hetzner_api_key`**, **`gitlab_letsencrypt_email`**.

**TLS:** **`gitlab_docker_traefik_acme_enabled`** für HTTPS über Traefik; **`gitlab_letsencrypt_enabled`** nur für Omnibus (`hetzner_app`).

**DNS/PTR:** wie bei `hetzner_app` (A-Record `gitlab_dns_record_name`, PTR auf `gitlab_fqdn`).

### Web IDE (`docker_compose`)

Die [Web IDE](https://docs.gitlab.com/user/project/web_ide/) ist in GitLab CE 18.x enthalten (kein eigener Container). Voraussetzungen im Stack: **HTTPS** (`gitlab_docker_traefik_acme_enabled`), korrektes **`external_url`** in `gitlab.rb`, **Workhorse** im Omnibus-Image.

**Öffnen:** Im Projekt **Code → Open in Web IDE** oder Tastenkürzel **`.`** (Punkt).

**Admin (einmalig nach Deploy):**

| Thema | Wo / Was |
|--------|-----------|
| OAuth-Callback | **Admin → Applications → GitLab Web IDE** — Redirect-URL muss `https://<gitlab-fqdn>/-/ide/oauth_redirect` sein (passt zu `external_url`). |
| Extension Marketplace | **Admin → Settings → General → VS Code Extension Marketplace** aktivieren (optional, für Extensions). |
| Extension-Host | Im Admin-Feld **nur die Basis-Domain** (ohne `*.`, ohne `https://`), z. B. `cdn.web-ide.gitlab-static.net` — **nicht** `*.cdn.web-ide.gitlab-static.net` (liefert „not a valid domain name“). Wildcard-Subdomains entstehen automatisch; ausgehendes HTTPS zu `*.cdn.web-ide.gitlab-static.net` muss erlaubt sein. Eigene Domain (z. B. `web-ide.example.com`) nur mit DNS `*.web-ide…` + Traefik/nginx — siehe [Admin-Doku](https://docs.gitlab.com/administration/settings/web_ide/). |

Auf einer frischen Instanz OAuth-App und Callback per Rails anlegen (falls Admin-UI noch leer):

```bash
cd /opt/gitlab
docker compose exec -T gitlab gitlab-rails runner \
  'WebIde::DefaultOauthApplication.ensure_oauth_application!'
docker compose exec -T gitlab gitlab-rails runner \
  'ApplicationSetting.current.update!(vscode_extension_marketplace_enabled: true)'
```

**Nutzer:** **Preferences → Integrate with the Extension Marketplace** (wenn Extensions genutzt werden).

**Troubleshooting:**

| Symptom | Maßnahme |
|---------|----------|
| „Cannot open Web IDE“ / OAuth-Mismatch | Callback-URL in **Admin → Applications** prüfen; `external_url` muss dieselbe Origin nutzen ([Doku](https://docs.gitlab.com/user/project/web_ide/#update-the-oauth-callback-url)). |
| Leerer Editor / Asset-Fehler | Ausgehendes HTTPS zu `*.cdn.web-ide.gitlab-static.net` erlauben; Offline: [eigener Extension-Host](https://docs.gitlab.com/administration/settings/web_ide/). |
| HTTPS/SSL-Fehler | Traefik-ACME und Router (kein `tls.options=default@file` an Docker-Labels) — siehe Abschnitt Traefik oben. |

Weitere Details: [Web IDE](https://docs.gitlab.com/user/project/web_ide/), [Admin Web IDE](https://docs.gitlab.com/administration/settings/web_ide/), [Extension Marketplace](https://docs.gitlab.com/administration/settings/vscode_extension_marketplace/).

### Container Registry (`docker_compose`)

Standardmäßig aktiv über **`gitlab_docker_registry_enabled = true`** (nur mit `gitlab_install_mode = docker_compose`). Die Registry läuft im **GitLab-Omnibus-Container** (kein separater Service); Traefik terminiert TLS wie für die GitLab-Weboberfläche.

```mermaid
flowchart LR
  client[Client_docker_CLI]
  traefik[Traefik_443]
  gitlab[GitLab_Omnibus]
  reg[Registry_5050]

  client -->|"Host gitlab_fqdn"| traefik
  client -->|"Host registry_fqdn"| traefik
  traefik -->|"port 80"| gitlab
  traefik -->|"port 5050"| reg
  reg --- gitlab
```

Quelldateien: [`docs/diagrams/registry-architecture.mmd`](docs/diagrams/registry-architecture.mmd), [`docs/diagrams/registry-request-flow.mmd`](docs/diagrams/registry-request-flow.mmd).

| Thema | Details |
|--------|---------|
| DNS | **`hcloud_zone_record.registry`** — A-Record **`<gitlab_docker_registry_dns_label>.<zone>`** (Standard `registry.<zone>`) → GitLab-Server-IPv4 |
| `gitlab.rb` | `registry_external_url`, `gitlab_rails['registry_enabled']`, `registry_nginx['enable'] = false`, `registry['registry_http_addr'] = "0.0.0.0:5050"` |
| Traefik | Router **`registry`** auf dem `gitlab`-Service → Port **5050**, `certresolver=hetzner` bei ACME |
| Volumes | `/opt/gitlab/registry/data`, `/opt/gitlab/registry/certs` |
| Deaktivieren | `gitlab_docker_registry_enabled = false` — kein DNS, keine Traefik-Labels, keine Registry-Einträge in `gitlab.rb` |

**Voraussetzung für HTTPS:** **`gitlab_docker_traefik_acme_enabled = true`** und gültiger **`hetzner_api_key`** (DNS-01). Nach Deploy:

```bash
dig +short registry.example.com
curl -sI https://registry.example.com/v2/
docker login registry.example.com
docker tag myimage:latest registry.example.com/group/project:latest
docker push registry.example.com/group/project:latest
```

Outputs: **`registry_fqdn`**, **`registry_url`**.

**Migration bestehender VMs:** Cloud-Init-Änderung → oft **Server-Replace** (`terraform apply -replace=module.server.hcloud_server.main`) oder manuell `gitlab.rb`, Volumes, Compose-Labels und `docker compose up -d` nachziehen, danach `gitlab-ctl reconfigure`.

Doku: [Container Registry](https://docs.gitlab.com/administration/packages/container_registry/), [Registry hinter Reverse Proxy](https://docs.gitlab.com/administration/packages/container_registry/#use-an-external-reverse-proxy).

### Renovate CE (`docker_compose`)

Optional über **`gitlab_docker_renovate_enabled = true`** (nur zusammen mit `gitlab_install_mode = docker_compose`). Orientierung am offiziellen [Docker-Compose-Beispiel](https://github.com/mend/renovate-ce-ee/blob/main/examples/docker-compose/docker-compose-renovate-community.yml).

**Container-Stack auf der VM** (`/opt/gitlab/docker-compose.yml`):

| Service | Rolle |
|---------|--------|
| `renovate-ce` | Mend Renovate Community Edition (Server + Worker, SQLite unter `/db`) |
| Traefik | Reverse Proxy für `renovate.<zone>` → Container-Port **8080** |

**Cloud-Init schreibt zusätzlich:**

- `/opt/gitlab/renovate/mend-renovate.env` — Lizenz, TOS, API-Secret, Webhook-URL
- `/opt/gitlab/renovate/gitlab.env` — `MEND_RNV_PLATFORM=gitlab`, API-Endpoint (`https://<gitlab-fqdn>/api/v4/`), PAT, Webhook-Secret

**Terraform erzeugt:**

- `random_password.gitlab_renovate_webhook` → `MEND_RNV_WEBHOOK_SECRET` und (bei `enable_gitlab_resources`) Token des **`gitlab_project_hook`**
- `random_password.gitlab_renovate_server_api` → `MEND_RNV_SERVER_API_SECRET`
- **`hcloud_zone_record.renovate`** — A-Record auf die GitLab-Server-IPv4

**Beispiel `terraform.tfvars`:**

```hcl
gitlab_install_mode                = "docker_compose"
gitlab_docker_renovate_enabled     = true
gitlab_docker_renovate_license_key = "…"   # https://www.mend.io/renovate-community/
gitlab_docker_renovate_gitlab_pat  = "glpat-…" # PAT des Renovate-Bot-Users (api)

# Optional: GitLab-Projekt + Webhook per Provider
enable_gitlab_resources = true
gitlab_api_url          = "https://gitlab.example.com"
gitlab_api_token        = "glpat-…"
```

**Webhook:** GitLab sendet Events an `https://renovate.<zone>/webhook`. Der Hook auf Projekt `terraform` wird nur angelegt, wenn **`enable_gitlab_resources`**, **`docker_compose`** und **Renovate** gemeinsam aktiv sind ([`gitlab.tf`](terraform/gitlab.tf)).

**Logs auf der VM:** `docker logs renovate-ce`; Bootstrap: `/var/log/gitlab-docker-bootstrap.log`.

### GitLab Runner im Compose-Stack (Autoregister)

Optionaler **`gitlab/gitlab-runner`** im **gleichen** Compose-Stack wie GitLab (nicht die separate Runner-VM unter [`enable_gitlab_runner`](#gitlab-runner-optionale-zweite-vm)). Orientierung: [Tutorial: Automate runner creation](https://docs.gitlab.com/tutorials/automate_runner_creation/).

**Steuerung in `terraform.tfvars`:**

| Variable | Standard | Bedeutung |
|----------|----------|-----------|
| `gitlab_docker_runner_enabled` | `false` | `true`: Runner-Service in `docker-compose.yml` |
| `gitlab_docker_runner_autoregister` | `true` | `true` + leerer Token → API-Bootstrap; `false` → Token manuell (`glrt-…`) |
| `gitlab_docker_runner_token` | `""` | `glrt-…` aus **Admin → CI/CD → Runners → New instance runner**; leer = Autoregister |
| `gitlab_docker_runner_description` | `docker-compose` | Name in GitLab und `config.toml` |
| `gitlab_docker_runner_tags` | `["docker"]` | Runner-Tags (API: kommagetrennt) |
| `gitlab_docker_traefik_proxy_ipv4` | `172.31.191.247` | Traefik-IP für Runner-`extra_hosts` (Coordinator-HTTPS vom Runner-Container) |
| `gitlab_docker_runner_executor` | `docker` | `docker` oder `shell` |
| `gitlab_docker_runner_image` | `gitlab/gitlab-runner:alpine-v17.11.0` | Runner-Container-Image |

**Zwei Betriebsarten:**

```mermaid
flowchart TD
  enabled[gitlab_docker_runner_enabled true]
  token{gitlab_docker_runner_token gesetzt?}
  auto[Autoregister-Skript]
  static[Statisches config.toml aus Cloud-Init]
  api[POST /api/v4/user/runners]
  compose[docker compose --profile runner up -d]
  enabled --> token
  token -->|nein autoregister true| auto
  token -->|ja glrt| static
  auto --> api
  api --> compose
  static --> compose
```

#### Automatisch (Autoregister, empfohlen)

Cloud-Init legt **`/opt/gitlab/scripts/gitlab-runner-autoregister.sh`** an und startet es im Hintergrund (`nohup`). Das Skript:

1. wartet, bis der GitLab-Container `running` ist (bis zu ~20 Minuten),
2. erzeugt kurz ein Root-PAT (`runner-bootstrap-terraform`, Scope `api`) per `gitlab-rails runner`,
3. ruft **`POST http://localhost/api/v4/user/runners`** im GitLab-Container auf (`runner_type=instance_type`, `description`, `tag_list`),
4. widerruft das Bootstrap-PAT,
5. schreibt **`/opt/gitlab/gitlab-runner/config.toml`** mit dem zurückgegebenen **`glrt-…`**-Token,
6. startet **`docker compose --profile runner up -d gitlab-runner`**.

Der Runner-Container nutzt bis dahin das Compose-Profil **`runner`** und wird **nicht** beim ersten `docker compose up -d` mitgestartet.

**Beispiel `terraform.tfvars`:**

```hcl
gitlab_install_mode                  = "docker_compose"
gitlab_docker_runner_enabled         = true
gitlab_docker_runner_autoregister    = true
gitlab_docker_runner_token           = ""   # leer lassen
gitlab_docker_runner_description     = "docker-compose"
gitlab_docker_runner_tags            = ["docker"]
gitlab_docker_runner_executor        = "docker"
gitlab_docker_runner_default_image   = "ruby:3.3"
```

**Logs:** `/var/log/gitlab-runner-autoregister.log` (auch bei manuellem Start unten).

**Erfolg prüfen:**

```bash
ssh root@<server_ip>
tail -30 /var/log/gitlab-runner-autoregister.log   # Zeile: runner autoregister ok
cd /opt/gitlab && docker compose ps gitlab-runner
```

In GitLab: **Admin → CI/CD → Runners** — Instance-Runner mit Beschreibung aus `gitlab_docker_runner_description`, Tags aus `gitlab_docker_runner_tags`.

#### Manuell (Token aus der UI)

Wenn du den Token selbst setzen willst:

```hcl
gitlab_docker_runner_enabled      = true
gitlab_docker_runner_autoregister = false   # optional; bei gesetztem Token wird Autoregister ohnehin übersprungen
gitlab_docker_runner_token        = "glrt-xxxxxxxxxxxxxxxxxxxx"
```

Cloud-Init schreibt dann direkt **`/opt/gitlab/gitlab-runner/config.toml`**; der Runner startet mit dem normalen **`docker compose up -d`** (ohne Profil-Verzögerung).

**Wichtig:** Nur **`glrt-…`** (Instance Runner), **kein** `glpat-…` (Personal Access Token).

#### Manuell auf einer bestehenden VM

Cloud-Init läuft nur beim **ersten** Boot. Auf einem bereits laufenden Server (z. B. nach Template-Update ohne Replace):

```bash
ssh root@<server_ip>
install -m 0700 -d /opt/gitlab/gitlab-runner
# Skript muss existieren (sonst erneut deployen oder aus aktuellem Cloud-Init kopieren):
ls -l /opt/gitlab/scripts/gitlab-runner-autoregister.sh
sudo /opt/gitlab/scripts/gitlab-runner-autoregister.sh
# parallel Log:
sudo tail -f /var/log/gitlab-runner-autoregister.log
```

Voraussetzungen: GitLab-Container läuft; `python3` auf dem Host (JSON-Auswertung); in `terraform.tfvars` war **`gitlab_docker_runner_enabled = true`** beim letzten Render des User-Data.

#### Troubleshooting

| Symptom | Maßnahme |
|---------|----------|
| Kein Container `gitlab-runner` | `docker compose ps` — nur mit Profil `runner` nach Skript; Log auf `user/runners API failed` prüfen |
| `attempt N: gitlab not running yet` | GitLab-Stack noch am Starten; warten oder `docker compose logs gitlab` |
| API-Fehler im Log | GitLab erreichbar? Root-User vorhanden? PAT-Erstellung in Log; GitLab-Version ≥ 16 (neuer Runner-Workflow) |
| Runner in UI, Jobs pending | Tags in `.gitlab-ci.yml` (`tags: [docker]`) müssen zu `gitlab_docker_runner_tags` passen |
| Artifacts/`pages` Upload schlägt fehl (`no such host` für `gitlab`) | `config.toml` → `url` muss die **öffentliche** Instanz-URL sein (`https://<fqdn>`), nicht `http://gitlab`. Der Runner-Container braucht `extra_hosts: [<fqdn>:<traefik-proxy-ip>]` (Terraform: `gitlab_docker_traefik_proxy_ipv4`), damit Coordinator-HTTPS intern über Traefik läuft |
| `connection refused` bei `https://<fqdn>` (Runner-Container) | FQDN zeigt intern auf GitLab-Container-IP ohne :443 — `extra_hosts` am `gitlab-runner`-Service setzen (siehe oben) |
| Skript fehlt | Server mit neuem `user_data` ersetzen oder Snippet/Cloud-Init erneut einspielen |

**Abgrenzung:** [`enable_gitlab_runner`](#gitlab-runner-optionale-zweite-vm) = **eigene Hetzner-VM** (`cpx22`) mit `.deb`-Installation; **kein** Autoregister-Skript aus diesem Abschnitt.

## GitLab-Provider-Ressourcen (`gitlab.tf`)

Steuerung über **`enable_gitlab_resources`** (Default: `false`). Das ist **unabhängig** von **`gitlab_install_mode`**: Du kannst z. B. nur Infrastruktur provisionieren, nur API-Ressourcen anlegen, oder beides kombinieren (Self-Hosted GitLab auf Hetzner + Projekte per Terraform).

Wenn **`enable_gitlab_resources = true`**:

| Ressource | Inhalt |
|-----------|--------|
| `gitlab_group.devops_group` | Gruppe mit Pfad `devops`, Name `DevOps` |
| `gitlab_project.devops` | Projekt `devops` in der Gruppe (`namespace_id`), `visibility_level = public` |
| `gitlab_project.terraform` | Projekt `terraform` im User-Namespace, `visibility_level = public` |
| `gitlab_user.renovate-bot` | Benutzer `renovate-bot` (E-Mail `renovate-bot@<zone>`) |
| `gitlab_group_membership.renovate-bot` | Bot als **Maintainer** in Gruppe `devops` |
| `gitlab_project_hook.renovate_bot` | Webhook auf Projekt `terraform` → `https://renovate.<zone>/webhook` (nur bei `docker_compose` + **`gitlab_docker_renovate_enabled`**) |

**Konfiguration** in `terraform.tfvars` (Beispiel):

```hcl
enable_gitlab_resources = true
gitlab_api_url          = "https://gitlab.example.com"  # oder https://gitlab.com
gitlab_api_token        = "glpat-…"                     # nicht committen
```

**Validierung** ([`variables.tf`](terraform/variables.tf)): Ohne `enable_gitlab_resources` darf `gitlab_api_token` leer sein; mit `true` ist ein Token mit mindestens 8 Zeichen Pflicht. Image-Variablen für `docker_compose` haben Format-Checks (Hetzner-Slug, `traefik:…`, `gitlab/gitlab-ce:…`, `postgres:…`).

**Outputs:** `gitlab_devops_group_id`, `gitlab_devops_project_id`, `gitlab_terraform_project_id` (siehe [Outputs](#outputs)).

**Hinweise:**

- Der GitLab-Provider (v18) nutzt `visibility_level` statt `visibility`; Gruppenprojekte über `namespace_id`.
- Webhooks heißen im Provider **`gitlab_project_hook`** (nicht `gitlab_webhook`).
- Das Passwort des Bot-Users wird **nicht** per Terraform gesetzt (`#password` auskommentiert) — PAT manuell anlegen und in `gitlab_docker_renovate_gitlab_pat` eintragen.

## GitLab Runner (optionale zweite VM)

Für einen Runner **auf dem gleichen Host** wie GitLab (Docker Compose) siehe [GitLab Runner im Compose-Stack (Autoregister)](#gitlab-runner-im-compose-stack-autoregister) (`gitlab_docker_runner_*`). Dieser Abschnitt beschreibt eine **zweite Hetzner-VM**.

Wenn `enable_gitlab_runner = true`:

- **Server:** Zweites [`modules/server`](terraform/modules/server) mit festem Typ **`cpx22`**, Image `gitlab_runner_image` (Standard Ubuntu 24.04), Region `gitlab_runner_location` oder wie `location`.
- **Firewall:** [`module.firewall_runner`](terraform/modules/firewall) mit **SSH (22)** und **ICMP** eingehend; **ausgehend** DNS/HTTP/HTTPS (Defaults). Kein eingehendes HTTP/HTTPS/DNS/Node-Exporter.
- **DNS:** [`hcloud_zone_record.gitlab_runner`](terraform/main.tf) in derselben Zone wie `dns_domain`; PTR zeigt auf **`gitlab_runner_fqdn`** (Standard `runner05.<zone>`).
- **Paket-Install:** `gitlab_runner_install_package` steuert Cloud-Init ([`templates/gitlab-runner-cloud-init.yaml.tpl`](terraform/templates/gitlab-runner-cloud-init.yaml.tpl)): bei `true` [manuelle .deb-Installation](https://docs.gitlab.com/runner/install/linux-manually/) inkl. Arch-Mapping (`armhf`→`arm`), `dpkg`/`apt-get install -f`, `systemctl enable --now gitlab-runner`; bei `false` bleibt die VM ohne Runner-Paket.
- **Registrierung:** Kein `gitlab-runner register` in Terraform (Token würde im State landen). Nach dem Apply per SSH auf die Runner-VM verbinden und [Runner registrieren](https://docs.gitlab.com/runner/register/) (URL z. B. `terraform output -raw gitlab_url`, Token aus GitLab UI / CI-Variable).

```mermaid
flowchart TD
  boot[Cloud-Init]
  dec{gitlab_runner_install_package}
  install[Deb von S3 dpkg und systemd]
  skip[Nur Basis-OS]
  reg[Manuell gitlab-runner register]
  boot --> dec
  dec -->|true| install
  dec -->|false| skip
  install --> reg
  skip --> reg
```

## GitLab auf Proxmox

Dieser Abschnitt dokumentiert die **Proxmox-Schienen** im Repo: Vorbereitung, Terraform-Variablen und geplante Schritte für **GitLab CE mit Docker Compose** auf einer QEMU-VM in Proxmox VE. Er wird bei neuen Anpassungen erweitert.

**Aktueller Stand:** Mit **`proxmox_gitlab_docker_compose_enabled = true`** (Default) lädt das Modul [`modules/proxmox`](terraform/modules/proxmox) dasselbe Cloud-Init wie bei `gitlab_install_mode = docker_compose` als **Snippet** auf den Node und hängt es per **`cicustom = user=local:snippets/…`** an die GitLab-VM — Traefik, GitLab CE, PostgreSQL und optional Registry/Renovate wie auf Hetzner.

**Wichtig:** Proxmox und Hetzner sind **getrennte Schalter**. Für reines Proxmox empfohlen: **`gitlab_install_mode = "proxmox"`** + `enable_proxmox_resources = true` + `proxmox_gitlab_docker_compose_enabled = true` (inkl. kopiertem [`proxmox_data.tf`](terraform/proxmox_data.tf.example) für VM-ID-Plan-Check). Legacy: `gitlab_install_mode = "none"` + `enable_proxmox_resources = true`. Dann ist **`module.dns` standardmäßig aus** (`local.manage_hetzner_dns = false`) — keine Hetzner-DNS-Zone/-Records per Terraform. DNS für GitLab/Registry legst du extern an oder Traefik ACME nutzt die Hetzner-DNS-**API** im Cloud-Init (`hetzner_api_key`), ohne Terraform-Records. Override: `enable_hetzner_dns = true` (z. B. Mail-Zone oder Runner-A-Record auf Hetzner).

```mermaid
flowchart TB
  subgraph pve [Proxmox_VE]
    vm[proxmox_vm_qemu_gitlab]
    runner[proxmox_vm_qemu_gitlab_runner]
  end
  tf[Terraform_proxmox_provider]
  snippet[Snippet_gitlab_docker_cloud_init]
  tf --> snippet
  snippet --> vm
  tf --> runner
```

### Voraussetzungen auf Proxmox

| Thema | Empfehlung |
|--------|------------|
| **Proxmox VE** | Getestet mit Provider `telmate/proxmox` `<=3.0.2-rc07` ([`provider.tf`](terraform/provider.tf)) |
| **API-Token** | Unter **Datacenter → Permissions → API Tokens** anlegen; Token-ID und Secret in Terraform (siehe unten) |
| **QEMU Guest Agent** | In der VM aktiv (`agent = 1` im Modul); im Gast-OS installiert und laufend |
| **Netzwerk** | Bridge `vm_default_bridge` (Default `vmbr0`); VLAN-Tag `-1` = kein Tag |
| **Ressourcen GitLab-VM** | `vm_host_cores` (Default **4**), `vm_host_memory` (Default **12288** MiB) |
| **SSH** | `ssh_public_key` / `ssh_public_key_file` → `sshkeys` in Cloud-Init |
| **Snippet-Storage** | `proxmox_snippet_storage` (Default `local`); Upload per API bei Apply |
| **Template / Clone** | Optional `proxmox_enable_clone = true` + `clone_template`; sonst leere SCSI-Disk (`vm_default_disk_size`) |

### Einrichtung in Proxmox (Checkliste)

1. **API-Token** erstellen (Beispiel-Benutzer `terraform@pve`, Token-Name `terraform`):
   - Rechte mindestens zum Anlegen/Ändern von VMs auf dem Ziel-Node
   - Secret sicher notieren → `proxmox_api_token` in `terraform.tfvars`
2. **`proxmox_api_token_id`** setzen, falls abweichend (Default: `terraform@pve!terraform` = `USER@REALM!TOKENID`)
3. **`proxmox_api_url`** setzen: `https://<pve-host>:8006/api2/json` (exakt dieses Suffix, siehe Validierung in [`variables.tf`](terraform/variables.tf))
4. **`proxmox_node`** auf den Cluster-Node-Namen setzen (`target_node` für die GitLab-VM)
5. **Netzwerk & Cloud-Init** per Variablen anpassen:
   - `proxmox_gitlab_ipconfig0`, `proxmox_runner_ipconfig0` (Runner nur mit `proxmox_enable_runner = true`)
   - `nameserver`, `ciuser`, `cipassword`
   - Für Traefik ACME (DNS-01): `hetzner_api_key` und `gitlab_docker_traefik_acme_enabled = true` wie bei Hetzner
6. **Terraform** (Proxmox-Dateien ins Working Tree kopieren, nicht committen — siehe `.gitignore`):
   ```bash
   cd terraform
   cp proxmox.tf.example proxmox.tf
   cp provider_proxmox.tf.example provider_proxmox.tf
   cp proxmox_variables.tf.example proxmox_variables.tf
   cp outputs_proxmox.tf.example outputs_proxmox.tf
   cp proxmox_data.tf.example proxmox_data.tf   # Pflicht bei gitlab_install_mode = "proxmox" (VM-ID-Check bei plan)
   terraform init    # lädt telmate/proxmox nur mit provider_proxmox.tf
   ```
7. In **`terraform.tfvars`** (Beispiel):
   ```hcl
   enable_proxmox_resources              = true
   proxmox_gitlab_docker_compose_enabled = true
   proxmox_api_url                       = "https://pve01.example.com:8006/api2/json"
   proxmox_api_token                     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   proxmox_api_token_id                  = "terraform@pve!terraform"
   proxmox_node                          = "pve01"
   proxmox_gitlab_ipconfig0              = "ip=10.20.0.10/16,gw=10.20.0.1"
   pm_tls_insecure                       = true   # nur Lab; Produktion: gültiges TLS
   ciuser                                = "admin"
   cipassword                            = "…"
   ssh_public_key_file                   = "~/.ssh/id_ed25519.pub"
   gitlab_install_mode                   = "proxmox"   # oder Legacy: "none"
   proxmox_gitlab_vmid                   = 0         # 0 = auto; z. B. 120 = feste ID (Plan prüft Freiheit)
   proxmox_runner_vmid                   = 0
   dns_domain                            = "example.com"
   hetzner_api_key                       = "…"   # Traefik ACME DNS-01 (API, kein module.dns)
   # enable_hetzner_dns = null            # Default: kein Terraform-Hetzner-DNS bei Proxmox-only
   ```
8. **`terraform plan`** / **`apply`** — bei `gitlab_install_mode = "proxmox"` und VM-ID > 0: Proxmox-API muss für `plan` erreichbar sein ([`scripts/proxmox-check-vmids.sh`](scripts/proxmox-check-vmids.sh)); lädt Cloud-Init-Snippet, erzeugt `proxmox_vm_qemu.gitlab`; Runner nur mit `proxmox_enable_runner = true`

### Terraform-Ressourcen

| Ressource | Ort | Zweck |
|-----------|-----|--------|
| `module.proxmox` | [`proxmox.tf`](terraform/proxmox.tf) (Kopie von [`proxmox.tf.example`](terraform/proxmox.tf.example)) | Wrapper mit Root-Variablen |
| `null_resource.upload_cloud_init_snippet` | [`modules/proxmox`](terraform/modules/proxmox) | Upload `gitlab-docker-cloud-init.yaml.tpl` nach `snippets/` |
| `proxmox_vm_qemu.gitlab` | Modul | GitLab-VM mit `cicustom` + Cloud-Init-Netz |
| `proxmox_vm_qemu.gitlab_runner` | Modul | Optional (`proxmox_enable_runner`) |

**Lifecycle:** Änderungen an `disk` und `sshkeys` werden ignoriert (`ignore_changes`), damit manuelle Anpassungen in der UI nicht sofort zurückgedreht werden. `vm_state` ist **nicht** im `ignore_changes` (vom Provider nicht unterstützt).

### Variablen (Proxmox)

Steuerung: **`enable_proxmox_resources`** (Default `false`). Weitere Variablen in [`variables.tf`](terraform/variables.tf) (Abschnitt „Proxmox variables“):

| Variable | Default (Kurz) | Rolle |
|----------|----------------|--------|
| `enable_proxmox_resources` | `false` | Schaltet `module.proxmox` |
| `proxmox_api_token` | `""` | API-Token-Secret; Pflicht wenn Proxmox aktiv |
| `proxmox_api_url` | `https://pve01…/api2/json` | Proxmox-API-Endpunkt |
| `proxmox_node` | `pve01` | Node für GitLab-VM |
| `proxmox_api_token_id` | `terraform@pve!terraform` | Token-ID für Provider + Snippet-Upload |
| `proxmox_gitlab_docker_compose_enabled` | `true` | Docker-Stack-Cloud-Init auf Proxmox |
| `proxmox_gitlab_ipconfig0` | `ip=10.20.0.10/16,…` | Statische IP GitLab-VM |
| `proxmox_enable_runner` | `false` | Zweite VM für Runner |
| `proxmox_enable_clone` | `false` | Klon aus `clone_template` statt leerer Disk |
| `proxmox_gitlab_vmid` / `proxmox_runner_vmid` | `0` | VM-ID; `0` = Auto; bei `proxmox`-Modus und ID > 0 Plan-Check gegen Cluster-VMs |
| `enable_hetzner_dns` | `null` (auto) | `null`/`false`: kein `module.dns` bei Proxmox-only GitLab; `true`: Zone/Records trotzdem |
| `pm_tls_insecure` | `true` | TLS-Verify für API aus |
| `pm_timeout` | `300` | API-Timeout in Sekunden ([telmate/proxmox](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)); 30–86400 |
| `pm_parallel` | `1` | Parallele Provider-Operationen; 1–32 (Integer), Standard 1 |
| `ciuser` / `cipassword` | `admin` / `""` | Cloud-Init (Passwort min. 8 Zeichen wenn aktiv) |
| `vm_host_cores` / `vm_host_memory` | `4` / `12288` | GitLab-VM |
| `vm_default_*` / `clone_*` / `scsihw` / `bootdisk` | siehe `variables.tf` | Runner-VM und Disk/Bridge/Storage |

Validierungen (Auszug): `proxmox_api_url` muss `https://…:PORT/api2/json` sein; `vm_default_bridge` z. B. `vmbr0`; `vm_default_disk_size` Format `20G` / `512M`.

### Nach dem Apply

1. Erster Boot: Cloud-Init installiert Docker und startet den Stack (wie `docker_compose` auf Hetzner).
2. **DNS:** A-Record `gitlab.<zone>` (und ggf. `registry.<zone>`) auf die erreichbare IP der VM — **manuell/extern**, wenn `enable_hetzner_dns` aus ist (Standard bei Proxmox-only).
3. **`gitlab_api_url`** für [`gitlab.tf`](terraform/gitlab.tf) auf die erreichbare GitLab-URL setzen.
4. Root-Passwort: Output `gitlab_docker_initial_root_password` (sensitiv).
5. Optional **`enable_gitlab_resources = true`** für Gruppen/Projekte per API.

Snippet deaktivieren (nur Basis-Cloud-Init): `proxmox_gitlab_docker_compose_enabled = false`.

### Abgrenzung zu Hetzner-Modi

| | Hetzner (`gitlab_install_mode`) | Proxmox (`enable_proxmox_resources`) |
|--|--------------------------------|--------------------------------------|
| Compute | `hcloud_server` | `proxmox_vm_qemu` |
| Firewall | `hcloud_firewall` | Eigenes Netzwerk / Firewall am Host |
| DNS | `module.dns` / Records | Aus bei Proxmox-only (`enable_hetzner_dns` auto); sonst Hetzner DNS oder intern |
| GitLab-Stack | Cloud-Init-Template automatisch | Gleiches Template per Snippet + `cicustom` |
| Runner | `enable_gitlab_runner` (Hetzner) | `proxmox_enable_runner` (eigene VM, Runner-Install manuell) |

### Bekannte Punkte / Troubleshooting

- **`terraform init`:** Provider `telmate/proxmox` Version `<=3.0.2-rc07` (siehe Lockfile); neuere Provider-Versionen können abweichen.
- **Snippet-Upload schlägt fehl:** Token braucht Recht auf `proxmox_snippet_storage`; Storage muss `snippets` unterstützen (`local` auf dem Node).
- **Gleiche IP:** `proxmox_gitlab_ipconfig0` und `proxmox_runner_ipconfig0` müssen unterschiedlich sein, wenn Runner aktiv.
- **VM-ID belegt (Check `proxmox_vmid_available`):** Andere ID wählen oder `proxmox_gitlab_vmid` / `proxmox_runner_vmid = 0` für Auto; nur bei `gitlab_install_mode = "proxmox"` und kopiertem `proxmox_data.tf`.
- **Ohne Clone:** `proxmox_enable_clone = false` erzeugt eine leere SCSI-Disk — Gast-OS muss per ISO/anderem Weg installiert werden, oder Clone aktivieren.
- **Paralleles Apply** mit vollem Hetzner-GitLab (`gitlab_install_mode = docker_compose`) erzeugt **zwei** GitLab-Umgebungen — in der Regel nur eine aktivieren.

Weitere Links: [Proxmox VE API](https://pve.proxmox.com/pve-docs/api-viewer/index.html), [telmate/terraform-provider-proxmox](https://github.com/Telmate/terraform-provider-proxmox).

## Module im Detail

- **Firewall** ([`modules/firewall`](terraform/modules/firewall)): Eingehend (SSH, **2424**, HTTP/HTTPS, DNS, …) und **ausgehend** (DNS/HTTP/HTTPS, optional SMTP) schaltbar. Haupt-Firewall: `enable_egress_smtp = gitlab_smtp_enabled`, `egress_smtp_port = gitlab_smtp_port`. Runner-Firewall ohne SMTP-Egress.
- **Server** ([`modules/server`](terraform/modules/server)): Vollständigere Modul-Doku in [`modules/server/README.md`](terraform/modules/server/README.md). In [`terraform/main.tf`](terraform/main.tf) setzt Cloud-Init **`user_data`** bei `gitlab_install_mode` `hetzner_app` oder `docker_compose` (jeweils eigenes Template), sonst leer.
- **DNS** ([`modules/dns`](terraform/modules/dns)): Zone + Records; DKIM-Längen >255 werden automatisch gesplittet.
- **Proxmox** ([`modules/proxmox`](terraform/modules/proxmox)): QEMU-VMs, Cloud-Init-Snippet-Upload; Root-Aufruf nach `cp proxmox.tf.example proxmox.tf` (siehe [GitLab auf Proxmox](#gitlab-auf-proxmox)).

## Sicherheit und Betrieb

- **Firewall:** Standard erlaubt eingehend und ausgehend typischerweise `0.0.0.0/0` und `::/0` auf die konfigurierten Ports. Für Produktion `ssh_source_ips` / `egress_destination_ips` einschränken oder `custom_rules` nutzen.
- **Token:** `hcloud_token`, `gitlab_api_token` und andere Secrets nur in `terraform.tfvars` oder CI-Secrets; nicht versionieren. Bei `docker_compose` liegen initiale Passwörter zusätzlich im **Terraform State** und in **`/opt/gitlab/data/config/gitlab.rb`** bzw. Traefik-`.env` auf der VM (Outputs sensitiv).
- **Backups:** Bei `docker_compose`: `/opt/gitlab/backups/` und `/opt/gitlab/data/config/config_backup/`; bei `hetzner_app`: `/var/opt/gitlab/backups/` und `/etc/gitlab/config_backup/` — regelmäßig offsite sichern; Archive sind nicht verschlüsselt, sofern nicht separat konfiguriert.
- **PTR/rDNS:** Wenn `gitlab_install_mode` **nicht** `none`, zeigt PTR auf die GitLab-FQDN, sonst auf `dns_domain`. Bei HTTPS (Omnibus-LE oder Traefik-ACME) sollte der Hostname zum Zertifikat passen.
- **Mail/DNS:** Über die Variablen **`mail_server_ipv4`**, **`mail_server_ipv6`**, **`mail_server_cname_target`**, **`dns_tlsa_name`** (und bestehende MX/SPF/DMARC/…) an die eigene Infrastruktur anpassen.

## Cloud-Init und user_data

Hetzner wendet **`user_data` (Cloud-Init) in der Regel nur beim ersten Boot** einer neuen Server-Instanz an. Änderungen an den Cloud-Init-Templates wirken auf **bestehende** VMs oft **erst** nach **Server-Replace** — Ausnahme: Dateien unter **`/opt/gitlab`** (z. B. `gitlab.rb`, `docker-compose.yml`, Traefik-Configs, Backup-Skript/Cron) können manuell angepasst und per `docker compose up -d` / `gitlab-ctl reconfigure` aktiviert werden, sofern die Verzeichnisstruktur bereits existiert.

Vorgehen (Beispiel Runner):

```bash
terraform apply -replace='module.gitlab_runner[0].hcloud_server.main'
```

Entsprechend für den Hauptserver `module.server.hcloud_server.main`, falls dort `user_data` geändert wurde. **Hinweis:** Replace löscht die Root-Disk der VM (keine Daten auf zusätzlichen Volumes, sofern nicht separat angebunden).

**Troubleshooting:** `sudo tail -n 200 /var/log/cloud-init-output.log` auf der VM; Runner zusätzlich `/var/log/gitlab-runner-terraform-bootstrap.log`. Typischer Fehler: falsche **.deb-URL** (z. B. Bindestrich statt Unterstrich im Dateinamen) → `curl` **403**.

## Terraform und OpenTofu

| Tool | Version | Befehle |
|------|---------|---------|
| **Terraform** (empfohlen) | **>= 1.14.4** | `terraform init`, `plan`, `apply` |
| **OpenTofu** | **>= 1.9.0** (z. B. 1.12.x) | `tofu init`, `plan`, `apply` |

[`provider.tf`](terraform/provider.tf) setzt `required_version = ">= 1.9.0"`, damit dieselbe HCL mit OpenTofu lauffähig ist. Provider (`hetznercloud/hcloud`, `hashicorp/random`, `gitlabhq/gitlab`) kommen aus der Registry; [`.terraform.lock.hcl`](terraform/.terraform.lock.hcl) funktioniert mit `terraform init` und `tofu init`.

**Hinweis:** OpenTofu und Terraform teilen sich die Versionsnummern nicht 1:1 (Stand 2026: OpenTofu ~1.12, Terraform ~1.14). CI testet **Terraform 1.14.4** und zusätzlich **`tofu validate`** (OpenTofu 1.12).

**Remote State:** Es ist kein `backend` im Repo konfiguriert — State liegt standardmäßig lokal unter **`terraform/terraform.tfstate`**. Für Teams: S3-kompatiblen Object Storage, Terraform Cloud oder Hetzner Object Storage mit State-Lock dokumentieren und in einer lokalen `terraform/backend.tf` ergänzen (nicht committen, wenn umgebungsspezifisch).

## Qualitätssicherung (lokal / CI)

- **Makefile** (vom Repo-Root): `make fmt` / `make validate` führt Befehle in **`terraform/`** aus (vorher einmal `cd terraform && terraform init`).
- **Docker-Image-Versionen:** `make check-images` vergleicht die gepinnten Tags **`gitlab_docker_gitlab_ce_image`** und **`gitlab_docker_traefik_image`** (Defaults in [`variables.tf`](terraform/variables.tf), optional Override in `terraform.tfvars`) mit Docker Hub (`curl`, `jq` erforderlich). `make check-images-strict` beendet mit Exit-Code 1, wenn neuere Tags verfügbar sind. Nach einem Update: Variablen anpassen, `terraform plan`/`apply`, auf dem Host `docker compose pull` und betroffene Services neu starten. Nicht Teil von `make ci` (Netzwerk, Rate-Limits).
- **GitLab CI:** [`.gitlab-ci.yml`](.gitlab-ci.yml) – dieselben Checks wie GitHub Actions (`fmt`, `terraform validate`, `tofu validate`, `tflint`); keine Secrets/`apply` in der Pipeline.
- **GitHub Actions:** [`.github/workflows/terraform.yml`](.github/workflows/terraform.yml) – `working-directory: terraform`; bei Push/PR: `terraform fmt -check`, `terraform validate`, `tofu validate`, `tflint` (ohne Cloud-Token für `apply`).

## Bekannte Einschränkungen

1. **`hetzner_api_key` vs. `hcloud_token`:** Zwei verschiedene Tokens (DNS vs. Cloud). Vertauschen führt zu fehlgeschlagenem Traefik-ACME (DNS-01).
2. **`site_url`:** Nur für Output `website_url`; nicht an Module gebunden.
3. **DNS-A-Record vs. `server_name`:** Der relative A-Record-Name kommt aus `dns_ipv4_record_name` bzw. bei GitLab aus `gitlab_dns_record_name` – nicht automatisch aus `server_name`. Bei Bedarf Werte angleichen.
4. **Cloud-Init / `user_data`:** Änderungen an Templates erfordern oft **Server-Replace** (`terraform apply -replace=module.server.hcloud_server.main`), nicht nur erneutes Apply.
5. **Unabhängige Schalter:** `gitlab_install_mode` (Server/Compose), `enable_gitlab_resources` ([`gitlab.tf`](terraform/gitlab.tf), Modul [`modules/gitlab-api`](terraform/modules/gitlab-api/)), `gitlab_docker_registry_enabled` (Container Registry, Standard an), `gitlab_docker_renovate_enabled` (Renovate-Container). Runner-Registrierung bleibt manuell.
6. **Renovate:** Lizenz und GitLab-PAT liegen in `terraform.tfvars` (sensitiv). Webhook-Secret steht im State; nach Änderung ggf. Hook in GitLab und Env auf der VM anpassen.
7. **Proxmox:** GitLab-Docker-Stack per Cloud-Init-Snippet; siehe [GitLab auf Proxmox](#gitlab-auf-proxmox).



## Weiterführende Links

- [OpenTofu](https://opentofu.org/docs/)
- [Hetzner Cloud Terraform Provider (Registry)](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs)
- [GitLab Terraform Provider (Registry)](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs)
- [Mend Renovate CE – Docker Compose Beispiel](https://github.com/mend/renovate-ce-ee/blob/main/examples/docker-compose/docker-compose-renovate-community.yml)
- [Renovate Community Edition – Lizenz](https://www.mend.io/renovate-community/)
- [Hetzner Dokumentation](https://docs.hetzner.com/)
- [GitLab – Backup (Omnibus)](https://docs.gitlab.com/omnibus/settings/backups.html)
- [GitLab – Backup in Docker](https://docs.gitlab.com/administration/backup_restore/backup_gitlab/)
- [GitLab – Container Registry](https://docs.gitlab.com/administration/packages/container_registry/)
- [Proxmox VE API](https://pve.proxmox.com/pve-docs/api-viewer/index.html)
- [Terraform Provider telmate/proxmox (Registry)](https://registry.terraform.io/providers/telmate/proxmox/latest/docs)


# Test for Renovate App