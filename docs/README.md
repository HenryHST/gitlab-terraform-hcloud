# Dokumentation

Ausführliche Anleitungen und Referenz für **gitlab-terraform-hcloud**. Kurzüberblick und Schnellstart: [Repository-README](../README.md).

## Inhaltsverzeichnis

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

- [Installationsmodi](gitlab-install-modes.md)
  - [`hetzner_app`](gitlab-install-modes.md#hetzner_app-hetzner-app-image)
  - [`docker_compose`](gitlab-install-modes.md#docker_compose-gitlab-ce--traefik)
  - [Web IDE](gitlab-install-modes.md#web-ide-docker_compose)
  - [Container Registry](gitlab-install-modes.md#container-registry-docker_compose)
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
