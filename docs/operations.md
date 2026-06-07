# Betrieb, Module & CI

## Module im Detail

- **Firewall** ([`modules/firewall`](../terraform/modules/firewall)): Eingehend (SSH, **2424**, HTTP/HTTPS, DNS, …) und **ausgehend** (DNS/HTTP/HTTPS, optional SMTP) schaltbar. Haupt-Firewall: `enable_egress_smtp = gitlab_smtp_enabled`, `egress_smtp_port = gitlab_smtp_port`. Runner-Firewall ohne SMTP-Egress.
- **Server** ([`modules/server`](../terraform/modules/server)): Vollständigere Modul-Doku in [`modules/server/README.md`](../terraform/modules/server/README.md). In [`terraform/main.tf`](../terraform/main.tf) setzt Cloud-Init **`user_data`** bei `gitlab_install_mode` `hetzner_app` oder `docker_compose` (jeweils eigenes Template), sonst leer.
- **DNS** ([`modules/dns`](../terraform/modules/dns)): Zone + Records; DKIM-Längen >255 werden automatisch gesplittet.
- **Proxmox** ([`modules/proxmox`](../terraform/modules/proxmox)): QEMU-VMs, Cloud-Init-Snippet-Upload; Root-Aufruf nach `cp proxmox.tf.example proxmox.tf` (siehe [GitLab auf Proxmox](proxmox.md)).

## Sicherheit und Betrieb

- **Firewall:** Standard erlaubt eingehend und ausgehend typischerweise `0.0.0.0/0` und `::/0` auf die konfigurierten Ports. Für Produktion `ssh_source_ips` / `egress_destination_ips` einschränken oder `custom_rules` nutzen.
- **Token:** `hcloud_token`, `gitlab_api_token` und andere Secrets nur in `terraform.tfvars` oder CI-Secrets; nicht versionieren. Bei `docker_compose` liegen initiale Passwörter zusätzlich im **Terraform State** und in **`/opt/gitlab/data/config/gitlab.rb`** bzw. Traefik-`.env` auf der VM (Outputs sensitiv).
- **Backups:** Bei `docker_compose`: `/opt/gitlab/backups/` und `/opt/gitlab/data/config/config_backup/`; bei `hetzner_app`: `/var/opt/gitlab/backups/` und `/etc/gitlab/config_backup/` — regelmäßig offsite sichern; Archive sind nicht verschlüsselt, sofern nicht separat konfiguriert.
- **PTR/rDNS:** Wenn `gitlab_install_mode` **nicht** `none`, zeigt PTR auf die GitLab-FQDN, sonst auf `dns_domain`. Bei HTTPS (Omnibus-LE oder Traefik-ACME) sollte der Hostname zum Zertifikat passen.
- **Mail/DNS:** Über die Variablen **`mail_server_ipv4`**, **`mail_server_ipv6`**, **`mail_server_cname_target`**, **`dns_tlsa_name`** (und bestehende MX/SPF/DMARC/…) an die eigene Infrastruktur anpassen.

## Cloud-Init und user_data

Hetzner **`hcloud_server.user_data`** ist auf **32 KiB** begrenzt. Für `gitlab_install_mode = docker_compose` liefert Terraform **`base64gzip(...)`** der gerenderten Cloud-Init-Vorlage; cloud-init auf Debian dekodiert Base64 und entpackt Gzip beim ersten Boot. Proxmox nutzt weiterhin unkomprimiertes `local.gitlab_docker_user_data` als Snippet (kein Hetzner-Limit).

Hetzner wendet **`user_data` (Cloud-Init) in der Regel nur beim ersten Boot** einer neuen Server-Instanz an. Änderungen an den Cloud-Init-Templates wirken auf **bestehende** VMs oft **erst** nach **Server-Replace** — Ausnahme: Dateien unter **`/opt/gitlab`** (z. B. `gitlab.rb`, `docker-compose.yml`, Traefik-Configs, Backup-Skript/Cron) können manuell angepasst und per `docker compose up -d` / `gitlab-ctl reconfigure` aktiviert werden, sofern die Verzeichnisstruktur bereits existiert.

Mit **`gitlab_admin = { enabled = true }`** legt Cloud-Init beim Erst-Boot einen Linux-Benutzer (Standard **`gadmin`**) mit Home-Verzeichnis, **`sudo`** (NOPASSWD) und **`docker`** an — SSH mit dem gleichen Key wie root (`ssh_public_key_file` / `ssh_public_key`). Auf bereits laufenden Servern: manuell `useradd`/`usermod` oder Server-Replace. Output: `gitlab_docker_host_admin_username`.

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

[`provider.tf`](../terraform/provider.tf) setzt `required_version = ">= 1.9.0"`, damit dieselbe HCL mit OpenTofu lauffähig ist. Provider (`hetznercloud/hcloud`, `hashicorp/random`, `gitlabhq/gitlab`) kommen aus der Registry; [`.terraform.lock.hcl`](../terraform/.terraform.lock.hcl) funktioniert mit `terraform init` und `tofu init`.

**Hinweis:** OpenTofu und Terraform teilen sich die Versionsnummern nicht 1:1 (Stand 2026: OpenTofu ~1.12, Terraform ~1.14). CI testet **Terraform 1.14.4** und zusätzlich **`tofu validate`** (OpenTofu 1.12).

**Remote State:** Es ist kein `backend` im Repo konfiguriert — State liegt standardmäßig lokal unter **`terraform/terraform.tfstate`**. Für Teams: S3-kompatiblen Object Storage, Terraform Cloud oder Hetzner Object Storage mit State-Lock dokumentieren und in einer lokalen `terraform/backend.tf` ergänzen (nicht committen, wenn umgebungsspezifisch).

## Qualitätssicherung (lokal / CI)

- **Makefile** (vom Repo-Root): `make fmt` / `make validate` führt Befehle in **`terraform/`** aus (vorher einmal `cd terraform && terraform init`).
- **Docker-Image-Versionen:** `make check-images` vergleicht die gepinnten Tags **`gitlab_docker_gitlab_ce_image`** und **`gitlab_docker_traefik_image`** (Defaults in [`variables.tf`](../terraform/variables.tf), optional Override in `terraform.tfvars`) mit Docker Hub (`curl`, `jq` erforderlich). `make check-images-strict` beendet mit Exit-Code 1, wenn neuere Tags verfügbar sind. Nach einem Update: Variablen anpassen, `terraform plan`/`apply`, auf dem Host `docker compose pull` und betroffene Services neu starten. Nicht Teil von `make ci` (Netzwerk, Rate-Limits).
- **GitLab CI:** [`.gitlab-ci.yml`](../.gitlab-ci.yml) – dieselben Checks wie GitHub Actions (`fmt`, `terraform validate`, `tofu validate`, `tflint`); keine Secrets/`apply` in der Pipeline.
- **GitHub Actions:** [`.github/workflows/terraform.yml`](../.github/workflows/terraform.yml) – `working-directory: terraform`; bei Push/PR: `terraform fmt -check`, `terraform validate`, `tofu validate`, `tflint` (ohne Cloud-Token für `apply`).

## Bekannte Einschränkungen

1. **`hetzner_api_key` vs. `hcloud_token`:** Zwei verschiedene Tokens (DNS vs. Cloud). Vertauschen führt zu fehlgeschlagenem Traefik-ACME (DNS-01).
2. **`site_url`:** Nur für Output `website_url`; nicht an Module gebunden.
3. **DNS-A-Record vs. `server_name`:** Der relative A-Record-Name kommt aus `dns_ipv4_record_name` bzw. bei GitLab aus `gitlab_dns_record_name` – nicht automatisch aus `server_name`. Bei Bedarf Werte angleichen.
4. **Cloud-Init / `user_data`:** Änderungen an Templates erfordern oft **Server-Replace** (`terraform apply -replace=module.server.hcloud_server.main`), nicht nur erneutes Apply.
5. **Unabhängige Schalter:** `gitlab_install_mode` (Server/Compose), `enable_gitlab_resources` ([`gitlab.tf`](../terraform/gitlab.tf), Modul [`modules/gitlab-api`](../terraform/modules/gitlab-api/)), `gitlab_docker_registry_enabled` (Container Registry, Standard an), `gitlab_docker_renovate_enabled` (Renovate-Container). Runner-Registrierung bleibt manuell.
6. **Renovate:** Lizenz und GitLab-PAT liegen in `terraform.tfvars` (sensitiv). Webhook-Secret steht im State; nach Änderung ggf. Hook in GitLab und Env auf der VM anpassen.
7. **Proxmox:** GitLab-Docker-Stack per Cloud-Init-Snippet; siehe [GitLab auf Proxmox](proxmox.md).



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
