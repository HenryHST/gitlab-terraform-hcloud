# Dokumentation

Ausführliche Anleitungen und Referenz für **gitlab-terraform-hcloud**. Kurzüberblick und Schnellstart: [Repository-README](../README.md).

**[Inhaltsverzeichnis](#inhaltsverzeichnis)** • **[Verzeichnisübersicht](#verzeichnisübersicht)** • [Repository-README](../README.md)

## Verzeichnisübersicht

Nur versionierte Pfade; lokale Secrets (`terraform.tfvars`), `.terraform/` und Plan-Artefakte sind ausgelassen.

```txt
gitlab-terraform-hcloud/
├── README.md                              # Einstieg: Tech Stack, Architektur, Schnellstart
├── CHANGELOG.md
├── Makefile                               # fmt, validate, ci, check-images
├── renovate.json                          # Mend Renovate (Repo-Root)
├── LICENSE
├── .github/
│   ├── workflows/
│   │   └── terraform.yml                  # CI: terraform/tofu fmt, validate, tflint
│   └── ISSUE_TEMPLATE/                    # Bug- und Feature-Templates
├── docs/                                  # Erweiterte Doku (dieses Verzeichnis)
│   ├── README.md                          # Inhaltsverzeichnis + Verzeichnisübersicht
│   ├── reference.md                       # Root-Variablen & Outputs
│   ├── gitlab-install-modes.md            # hetzner_app, docker_compose, Registry, Runner, …
│   ├── proxmox.md                         # Proxmox-Checkliste, VM-IDs, Troubleshooting
│   ├── operations.md                      # Module, Sicherheit, Cloud-Init, CI
│   ├── backup.md                          # Backups: Variablen, Cron, CI, Restore
│   ├── pages.md                           # GitLab Pages: Wildcard-DNS, Traefik, CI
│   ├── examples/
│   │   └── gitlab-backup-ci.yml.example   # GitLab CI: manuelles/scheduled Backup
│   └── diagrams/
│       ├── registry-architecture.mmd      # Registry-Topologie (Mermaid-Quelle)
│       ├── registry-request-flow.mmd      # Registry-Request-Flow (Mermaid-Quelle)
│       └── pages-architecture.mmd         # Pages-Topologie (Mermaid-Quelle)
├── scripts/
│   ├── check-compose-image-versions.sh    # Docker-Hub-Vergleich (make check-images)
│   └── proxmox-check-vmids.sh             # Plan-Check: freie Proxmox-VM-IDs
└── terraform/                             # Working Directory für terraform/tofu und make
    ├── main.tf                            # Module firewall → server → dns, Locals
    ├── variables.tf                       # Root-Variablen inkl. gitlab_install_mode
    ├── outputs.tf
    ├── provider.tf                        # hcloud, gitlab, random
    ├── gitlab.tf                          # Optional: Gruppe/Projekte per GitLab-API
    ├── dns_moved.tf                       # State-Migration DNS
    ├── checks_proxmox.tf                  # Proxmox-Datei-Checks, VM-ID-Querbezug
    ├── checks_gitlab_docker.tf            # GitLab CE / PostgreSQL-Validierung
    ├── proxmox.tf.example                 # → proxmox.tf (kopieren, in .gitignore)
    ├── provider_proxmox.tf.example        # → provider_proxmox.tf
    ├── proxmox_variables.tf.example       # → proxmox_variables.tf
    ├── proxmox_data.tf.example            # → proxmox_data.tf (VM-ID-Check bei Modus proxmox)
    ├── proxmox_moved.tf.example           # → proxmox_moved.tf (State-Migration)
    ├── outputs_proxmox.tf.example         # → outputs_proxmox.tf
    ├── terraform.tfvars.example           # Vorlage für terraform.tfvars (nicht committen)
    ├── .tflint.hcl
    ├── .terraform.lock.hcl
    ├── templates/
    │   ├── gitlab-cloud-init.yaml.tpl     # gitlab_install_mode = hetzner_app
    │   ├── gitlab-docker-cloud-init.yaml.tpl  # docker_compose / Proxmox-Docker
    │   └── gitlab-runner-cloud-init.yaml.tpl  # enable_gitlab_runner (Hetzner-VM)
    └── modules/
        ├── firewall/                      # hcloud_firewall (Hetzner)
        ├── server/                        # hcloud_server, SSH, user_data
        ├── dns/                           # hcloud_zone, Mail/Web-Records
        ├── gitlab-api/                    # gitlab_group, gitlab_project (optional)
        └── proxmox/                       # proxmox_vm_qemu, Cloud-Init-Snippet
```

Terraform- und OpenTofu-Befehle werden in **`terraform/`** ausgeführt (oder per **`make`** vom Repo-Root). Kurzreferenz im Arbeitsverzeichnis: [terraform/README.md](../terraform/README.md) (u. a. Pages-Fehler „domains and certificates disabled“). Details zu Installationsmodi und Proxmox: [gitlab-install-modes.md](gitlab-install-modes.md), [proxmox.md](proxmox.md).

## Inhaltsverzeichnis

- [Verzeichnisübersicht](#verzeichnisübersicht)

### Referenz & Betrieb

- [Variablen & Outputs](reference.md)
  - [Variablen (Root)](reference.md#variablen-root)
  - [Ohne Default](reference.md#ohne-default-bei-apply-erforderlich)
  - [Mit Default](reference.md#mit-default-optional-überschreibbar)
  - [Outputs](reference.md#outputs)
- [Betrieb, Module & CI](operations.md)
  - [Module im Detail](operations.md#module-im-detail)
  - [Sicherheit und Betrieb](operations.md#sicherheit-und-betrieb)
  - [Cloud-Init und user_data](operations.md#cloud-init-und-user_data)
  - [Terraform und OpenTofu](operations.md#terraform-und-opentofu)
  - [Qualitätssicherung (lokal / CI)](operations.md#qualitätssicherung-lokal--ci)
  - [Bekannte Einschränkungen](operations.md#bekannte-einschränkungen)
  - [Weiterführende Links](operations.md#weiterführende-links)

### GitLab

- [Backups](backup.md) — Variablen, Auto-Cron, manuell, GitLab CI
- [GitLab Pages](pages.md) — Wildcard-DNS, Traefik, CI
- [Installationsmodi](gitlab-install-modes.md)
  - [`hetzner_app`](gitlab-install-modes.md#hetzner_app-hetzner-app-image)
  - [`docker_compose`](gitlab-install-modes.md#docker_compose-gitlab-ce--traefik)
  - [Web IDE](gitlab-install-modes.md#web-ide-docker_compose)
  - [Container Registry](gitlab-install-modes.md#container-registry-docker_compose)
  - [GitLab Pages](gitlab-install-modes.md#gitlab-pages-docker_compose--proxmox-docker)
  - [Renovate CE](gitlab-install-modes.md#renovate-ce-docker_compose)
  - [Runner im Compose-Stack (Autoregister)](gitlab-install-modes.md#gitlab-runner-im-compose-stack-autoregister)
  - [GitLab-Provider-Ressourcen (`gitlab.tf`)](gitlab-install-modes.md#gitlab-provider-ressourcen-gitlabtf)
  - [GitLab Runner (optionale zweite VM)](gitlab-install-modes.md#gitlab-runner-optionale-zweite-vm)
- [GitLab auf Proxmox](proxmox.md)
  - [Voraussetzungen](proxmox.md#voraussetzungen-auf-proxmox)
  - [Einrichtung (Checkliste)](proxmox.md#einrichtung-in-proxmox-checkliste)
  - [Terraform-Ressourcen](proxmox.md#terraform-ressourcen)
  - [Variablen (Proxmox)](proxmox.md#variablen-proxmox)
  - [Nach dem Apply](proxmox.md#nach-dem-apply)
  - [Troubleshooting](proxmox.md#bekannte-punkte--troubleshooting)

### Diagramme

- [Registry-Architektur](diagrams/registry-architecture.mmd)
- [Registry-Request-Flow](diagrams/registry-request-flow.mmd)
- [Pages-Architektur](diagrams/pages-architecture.mmd)
