
## server variables
variable "ssh_public_key_file" {
  description = "Path to your SSH public key file (e.g. ~/.ssh/id_ed25519.pub). If set, overrides ssh_public_key."
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "Public SSH key for server access (single line). Ignored if ssh_public_key_file is set."
  type        = string
  default     = ""

  validation {
    condition = (
      trimspace(var.ssh_public_key_file) != "" ||
      (trimspace(var.ssh_public_key) != "" && can(regex(
        "^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh\\.com|sk-ecdsa-sha2-nistp256@openssh\\.com)\\s+",
        var.ssh_public_key
      )))
    )
    error_message = "Set ssh_public_key_file to your .pub path, or set ssh_public_key to the full single-line key (supported OpenSSH types per Hetzner API)."
  }
}

variable "server_name" {
  description = "Name of the server"
  type        = string
  default     = "web1"

  validation {
    condition     = length(var.server_name) > 0 && length(var.server_name) <= 63
    error_message = "Server name must be 1–63 characters."
  }
}

variable "server_type" {
  description = "Server type for the main/GitLab host (e.g. cpx22 = 3 vCPU 4 GB, cx23 = 2 vCPU 4 GB)"
  type        = string
  default     = "cpx22"

  validation {
    condition     = can(regex("^(cx|cpx|ccx)[0-9]{2,3}$", var.server_type))
    error_message = "Server type must be a valid Hetzner type (e.g. cx11, cx22, cpx21, ccx23)."
  }
}

variable "location" {
  description = "Server location (fsn1 = Falkenstein, nbg1 = Nuremberg, hel1 = Helsinki)"
  type        = string
  default     = "fsn1"

  validation {
    condition     = contains(["fsn1", "nbg1", "hel1", "ash", "hil"], var.location)
    error_message = "Location must be one of: fsn1, nbg1, hel1, ash, hil."
  }
}

variable "server_image" {
  description = "hcloud server image slug when gitlab_install_mode is none (e.g. ubuntu-24.04)"
  type        = string
  default     = "ubuntu-24.04"
}
## GitLab variables
variable "gitlab_theme_id" {
  description = "Theme ID for GitLab (e.g. 2)"
  type        = number
  default     = 2

  validation {
    condition     = var.gitlab_theme_id > 0 && var.gitlab_theme_id <= 10
    error_message = "gitlab_theme_id must be between 1 and 10."
  }
}
variable "gitlab_color_mode" {
  description = "Color mode for GitLab (e.g. 3)"
  type        = number
  default     = 3

  validation {
    condition     = var.gitlab_color_mode > 0 && var.gitlab_color_mode <= 3
    error_message = "gitlab_color_mode must be between 1 and 3."
  }
}
variable "gitlab_time_zone" {
  description = "Time zone for GitLab (e.g. Europe/Berlin)"
  type        = string
  default     = "Europe/Berlin"

  validation {
    condition     = can(regex("^[a-zA-Z0-9/_-]+$", var.gitlab_time_zone))
    error_message = "gitlab_time_zone must be a valid time zone (e.g. Europe/Berlin)."
  }
}

variable "gitlab_install_mode" {
  description = "GitLab platform: none, hetzner_app, docker_compose (Hetzner), proxmox (Proxmox VMs + Docker Compose cloud-init; requires enable_proxmox_resources)"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "hetzner_app", "docker_compose", "proxmox"], var.gitlab_install_mode)
    error_message = "gitlab_install_mode must be one of: none, hetzner_app, docker_compose, proxmox."
  }

  validation {
    condition     = var.gitlab_install_mode != "proxmox" || var.enable_proxmox_resources
    error_message = "gitlab_install_mode = \"proxmox\" requires enable_proxmox_resources = true."
  }

  validation {
    condition     = var.gitlab_install_mode != "proxmox" || var.proxmox_gitlab_docker_compose_enabled
    error_message = "gitlab_install_mode = \"proxmox\" requires proxmox_gitlab_docker_compose_enabled = true."
  }
}

variable "gitlab_docker_host_image" {
  description = "hcloud image slug for the main server when gitlab_install_mode is docker_compose (default debian-13)"
  type        = string
  default     = "debian-13"

  validation {
    condition     = can(regex("^[a-z0-9]+([.-][a-z0-9]+)*$", var.gitlab_docker_host_image))
    error_message = "gitlab_docker_host_image must be a valid Hetzner image slug (e.g. debian-13, ubuntu-24.04)."
  }

  validation {
    condition     = var.gitlab_install_mode != "docker_compose" || length(trimspace(var.gitlab_docker_host_image)) > 0
    error_message = "gitlab_docker_host_image must not be empty when gitlab_install_mode is docker_compose."
  }
}

variable "gitlab_docker_traefik_image" {
  description = "Traefik container image (pin v3.7.x as required)"
  type        = string
  default     = "traefik:v3.7.1"

  validation {
    condition = can(regex(
      "^[a-z0-9]+([._-][a-z0-9]+)*(/[a-z0-9]+([._-][a-z0-9]+)*)*:[a-zA-Z0-9][a-zA-Z0-9._-]+$",
      var.gitlab_docker_traefik_image,
    ))
    error_message = "gitlab_docker_traefik_image must be a Docker image reference with a tag (e.g. traefik:v3.7.1)."
  }

  validation {
    condition = var.gitlab_install_mode != "docker_compose" || can(regex(
      "^([a-z0-9.-]+/)?traefik:[a-zA-Z0-9][a-zA-Z0-9._-]+$",
      var.gitlab_docker_traefik_image,
    ))
    error_message = "gitlab_docker_traefik_image must name the traefik image (repository traefik or …/traefik) when gitlab_install_mode is docker_compose."
  }
}

variable "gitlab_docker_gitlab_ce_image" {
  description = "gitlab/gitlab-ce image tag for Docker Compose mode (official CE release tags: MAJOR.MINOR.PATCH-ce.0)"
  type        = string
  default     = "gitlab/gitlab-ce:18.11.4-ce.0"

  validation {
    condition = can(regex(
      "^gitlab/gitlab-ce:[0-9]+\\.[0-9]+\\.[0-9]+-ce\\.0$",
      var.gitlab_docker_gitlab_ce_image,
    ))
    error_message = "gitlab_docker_gitlab_ce_image must be an official CE tag: gitlab/gitlab-ce:MAJOR.MINOR.PATCH-ce.0 (e.g. gitlab/gitlab-ce:18.11.4-ce.0)."
  }

  validation {
    condition     = tonumber(regex("^gitlab/gitlab-ce:([0-9]+)", var.gitlab_docker_gitlab_ce_image)[0]) >= 16
    error_message = "gitlab_docker_gitlab_ce_image must use GitLab 16.0 or newer; see https://docs.gitlab.com/install/requirements/."
  }
}

variable "gitlab_docker_postgres_image" {
  description = "PostgreSQL container image for Docker Compose mode. GitLab 18.x: postgres:16+ or 17; GitLab 19.x: Terraform uses postgres:17 automatically (suffix from this variable, default -alpine). See https://docs.gitlab.com/install/requirements/"
  type        = string
  default     = "postgres:16-alpine"

  validation {
    condition = can(regex(
      "^postgres:(1[3-7])(\\.[0-9]+)?(-[a-zA-Z0-9._-]+)?$",
      var.gitlab_docker_postgres_image,
    ))
    error_message = "gitlab_docker_postgres_image must be postgres:<major> or postgres:<major>.<minor> with optional suffix (e.g. postgres:16-alpine, postgres:17.7-bookworm)."
  }

  validation {
    condition     = contains([13, 14, 15, 16, 17], tonumber(regex("^postgres:([0-9]+)", var.gitlab_docker_postgres_image)[0]))
    error_message = "gitlab_docker_postgres_image major version must be 13–17 (match GitLab CE requirements: https://docs.gitlab.com/install/requirements/)."
  }

  validation {
    condition = (
      tonumber(regex("^gitlab/gitlab-ce:([0-9]+)", var.gitlab_docker_gitlab_ce_image)[0]) != 19 ||
      tonumber(regex("^postgres:([0-9]+)", var.gitlab_docker_postgres_image)[0]) == 17
    )
    error_message = "When gitlab_docker_gitlab_ce_image is GitLab 19.x, set gitlab_docker_postgres_image to postgres:17 (e.g. postgres:17-alpine), or any postgres:17-* tag; otherwise Terraform overrides to postgres:17 with your tag suffix."
  }
}

variable "gitlab_docker_renovate_enabled" {
  description = "When gitlab_install_mode is docker_compose, deploy Mend Renovate CE (ghcr.io/mend/renovate-ce) in the same Compose stack"
  type        = bool
  default     = false

  validation {
    condition     = !var.gitlab_docker_renovate_enabled || var.gitlab_install_mode == "docker_compose"
    error_message = "gitlab_docker_renovate_enabled is only supported when gitlab_install_mode is docker_compose."
  }
}

variable "gitlab_docker_renovate_ce_image" {
  description = "Mend Renovate CE image (pin version; see https://github.com/mend/renovate-ce-ee/pkgs/container/renovate-ce)"
  type        = string
  default     = "ghcr.io/mend/renovate-ce:9.1.0"

  validation {
    condition = can(regex(
      "^ghcr\\.io/mend/renovate-ce:[a-zA-Z0-9][a-zA-Z0-9._-]+$",
      var.gitlab_docker_renovate_ce_image,
    ))
    error_message = "gitlab_docker_renovate_ce_image must be ghcr.io/mend/renovate-ce:<tag>."
  }
}

variable "gitlab_docker_renovate_dns_label" {
  description = "DNS A record label for Renovate CE (FQDN <label>.<zone>, Traefik Host rule and GitLab webhooks)"
  type        = string
  default     = "renovate"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.gitlab_docker_renovate_dns_label))
    error_message = "gitlab_docker_renovate_dns_label must be a valid DNS label."
  }
}

variable "gitlab_docker_renovate_license_key" {
  description = "Mend Renovate CE license key (MEND_RNV_LICENSE_KEY); obtain at https://www.mend.io/renovate-community/"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = !var.gitlab_docker_renovate_enabled || length(trimspace(var.gitlab_docker_renovate_license_key)) > 0
    error_message = "gitlab_docker_renovate_license_key is required when gitlab_docker_renovate_enabled is true."
  }
}

variable "gitlab_docker_renovate_gitlab_pat" {
  description = "GitLab PAT for the Renovate bot user (MEND_RNV_GITLAB_PAT); needs api scope on your GitLab instance"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = !var.gitlab_docker_renovate_enabled || length(trimspace(var.gitlab_docker_renovate_gitlab_pat)) >= 8
    error_message = "gitlab_docker_renovate_gitlab_pat is required when gitlab_docker_renovate_enabled is true."
  }
}

variable "gitlab_docker_runner_enabled" {
  description = "When docker_compose (or Proxmox GitLab Docker stack), deploy gitlab/gitlab-runner in the same Compose stack (Docker executor)"
  type        = bool
  default     = false

  validation {
    condition = !var.gitlab_docker_runner_enabled || var.gitlab_install_mode == "docker_compose" || (
      var.enable_proxmox_resources && var.proxmox_gitlab_docker_compose_enabled
    )
    error_message = "gitlab_docker_runner_enabled is only supported when gitlab_install_mode is docker_compose or Proxmox GitLab Docker stack is enabled."
  }
}

variable "gitlab_docker_runner_image" {
  description = "GitLab Runner image (pin version; see https://gitlab.com/gitlab-org/gitlab-runner/container_registry)"
  type        = string
  default     = "gitlab/gitlab-runner:alpine-v18.11.3"

  validation {
    condition = can(regex(
      "^gitlab/gitlab-runner:[a-zA-Z0-9][a-zA-Z0-9._-]+$",
      var.gitlab_docker_runner_image,
    ))
    error_message = "gitlab_docker_runner_image must be gitlab/gitlab-runner:<tag>."
  }
}

variable "gitlab_docker_runner_autoregister" {
  description = "When gitlab_docker_runner_enabled and gitlab_docker_runner_token is empty, create an instance runner via POST /api/v4/user/runners after GitLab bootstrap (https://docs.gitlab.com/tutorials/automate_runner_creation/)"
  type        = bool
  default     = true

  validation {
    condition = !var.gitlab_docker_runner_autoregister || var.gitlab_install_mode == "docker_compose" || (
      var.enable_proxmox_resources && var.proxmox_gitlab_docker_compose_enabled
    )
    error_message = "gitlab_docker_runner_autoregister is only supported when gitlab_install_mode is docker_compose or Proxmox GitLab Docker stack is enabled."
  }
}

variable "gitlab_docker_runner_token" {
  description = "Runner authentication token (glrt-…). Empty with gitlab_docker_runner_autoregister = true triggers API bootstrap; otherwise set manually from Admin -> CI/CD -> Runners"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition = !var.gitlab_docker_runner_enabled || (
      var.gitlab_docker_runner_autoregister && length(trimspace(var.gitlab_docker_runner_token)) == 0
    ) || length(trimspace(var.gitlab_docker_runner_token)) >= 20
    error_message = "gitlab_docker_runner_token must be glrt-… (min. 20 chars) when set, or leave empty with gitlab_docker_runner_autoregister = true."
  }
}

variable "gitlab_docker_runner_description" {
  description = "Runner name in GitLab and config.toml"
  type        = string
  default     = "docker-compose"

  validation {
    condition     = length(trimspace(var.gitlab_docker_runner_description)) > 0
    error_message = "gitlab_docker_runner_description must not be empty."
  }
}

variable "gitlab_docker_runner_executor" {
  description = "GitLab Runner executor (docker recommended for this stack)"
  type        = string
  default     = "docker"

  validation {
    condition     = contains(["docker", "shell"], var.gitlab_docker_runner_executor)
    error_message = "gitlab_docker_runner_executor must be docker or shell."
  }
}

variable "gitlab_docker_runner_default_image" {
  description = "Default Docker image for job containers when executor is docker"
  type        = string
  default     = "ruby:3.3"
}

variable "gitlab_docker_runner_concurrent" {
  description = "Maximum concurrent jobs for this runner"
  type        = number
  default     = 4

  validation {
    condition     = var.gitlab_docker_runner_concurrent >= 1 && var.gitlab_docker_runner_concurrent <= 64
    error_message = "gitlab_docker_runner_concurrent must be between 1 and 64."
  }
}

variable "gitlab_docker_runner_privileged" {
  description = "Privileged mode for Docker executor job containers (e.g. Docker-in-Docker)"
  type        = bool
  default     = false
}

variable "gitlab_docker_runner_buildah_enabled" {
  description = "When gitlab_docker_runner_enabled, register three instance runners (buildah-rootless, buildah-multiarch, buildah-privileged) instead of a single generic runner. Requires autoregister with empty token."
  type        = bool
  default     = false

  validation {
    condition     = !var.gitlab_docker_runner_buildah_enabled || var.gitlab_docker_runner_enabled
    error_message = "gitlab_docker_runner_buildah_enabled requires gitlab_docker_runner_enabled = true."
  }

  validation {
    condition = !var.gitlab_docker_runner_buildah_enabled || (
      var.gitlab_docker_runner_autoregister && length(trimspace(var.gitlab_docker_runner_token)) == 0
    )
    error_message = "gitlab_docker_runner_buildah_enabled requires gitlab_docker_runner_autoregister = true and an empty gitlab_docker_runner_token."
  }

  validation {
    condition     = !var.gitlab_docker_runner_buildah_enabled || var.gitlab_docker_runner_executor == "docker"
    error_message = "gitlab_docker_runner_buildah_enabled requires gitlab_docker_runner_executor = docker."
  }
}

variable "gitlab_docker_runner_buildah_default_image" {
  description = "Default Docker image for Buildah profile job containers when gitlab_docker_runner_buildah_enabled"
  type        = string
  default     = "quay.io/buildah/stable"
}

variable "gitlab_docker_runner_tags" {
  description = "Runner tags (tag_list in config.toml)"
  type        = list(string)
  default     = ["docker"]
}

variable "gitlab_docker_traefik_proxy_ipv4" {
  description = "Traefik static IPv4 on the Compose proxy network; used in gitlab-runner extra_hosts so the runner container reaches GitLab via HTTPS (FQDN → Traefik, not GitLab container :443)"
  type        = string
  default     = "172.31.191.247"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.gitlab_docker_traefik_proxy_ipv4))
    error_message = "gitlab_docker_traefik_proxy_ipv4 must be an IPv4 address."
  }
}

variable "gitlab_docker_plantuml_enabled" {
  description = "When docker_compose (or Proxmox GitLab Docker stack), deploy plantuml/plantuml-server and proxy /-/plantuml/ via bundled GitLab NGINX"
  type        = bool
  default     = true

  validation {
    condition = !var.gitlab_docker_plantuml_enabled || var.gitlab_install_mode == "docker_compose" || (
      var.enable_proxmox_resources && var.proxmox_gitlab_docker_compose_enabled
    )
    error_message = "gitlab_docker_plantuml_enabled is only supported when gitlab_install_mode is docker_compose or Proxmox GitLab Docker stack is enabled."
  }
}

variable "gitlab_docker_plantuml_image" {
  description = "PlantUML server image (https://docs.gitlab.com/administration/integration/plantuml/)"
  type        = string
  default     = "plantuml/plantuml-server:tomcat"

  validation {
    condition = can(regex(
      "^plantuml/plantuml-server:[a-zA-Z0-9][a-zA-Z0-9._-]+$",
      var.gitlab_docker_plantuml_image,
    ))
    error_message = "gitlab_docker_plantuml_image must be plantuml/plantuml-server:<tag>."
  }
}
variable "gitlab_docker_registry_enabled" {
  description = "When gitlab_install_mode is docker_compose, enable GitLab Container Registry (Traefik + DNS A record registry.<zone>)"
  type        = bool
  default     = true

  validation {
    condition     = !var.gitlab_docker_registry_enabled || var.gitlab_install_mode == "docker_compose"
    error_message = "gitlab_docker_registry_enabled is only supported when gitlab_install_mode is docker_compose."
  }
}

variable "gitlab_docker_registry_dns_label" {
  description = "DNS A record label for Container Registry (FQDN <label>.<zone>, Traefik Host rule and registry_external_url)"
  type        = string
  default     = "registry"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.gitlab_docker_registry_dns_label))
    error_message = "gitlab_docker_registry_dns_label must be a valid DNS label."
  }
}

variable "gitlab_docker_pages_enabled" {
  description = "When docker_compose or Proxmox GitLab Docker stack, enable GitLab Pages (Traefik, wildcard DNS, pages_external_url). Requires gitlab_docker_traefik_acme_enabled."
  type        = bool
  default     = false

  validation {
    condition = !var.gitlab_docker_pages_enabled || var.gitlab_install_mode == "docker_compose" || (
      var.enable_proxmox_resources && var.proxmox_gitlab_docker_compose_enabled
    )
    error_message = "gitlab_docker_pages_enabled is only supported when gitlab_install_mode is docker_compose or Proxmox GitLab Docker stack is enabled."
  }

  validation {
    condition     = !var.gitlab_docker_pages_enabled || var.gitlab_docker_traefik_acme_enabled
    error_message = "gitlab_docker_pages_enabled requires gitlab_docker_traefik_acme_enabled = true (HTTPS and DNS-01 wildcard certificate)."
  }
}

variable "gitlab_docker_pages_dns_label" {
  description = "DNS label for GitLab Pages (FQDN <label>.<zone>; project URLs use <namespace>.<label>.<zone>)"
  type        = string
  default     = "pages"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.gitlab_docker_pages_dns_label))
    error_message = "gitlab_docker_pages_dns_label must be a valid DNS label."
  }
}

variable "enable_gitlab_resources" {
  description = "If true, create GitLab provider resources in gitlab.tf (groups, projects). Requires gitlab_api_token."
  type        = bool
  default     = false
}

variable "gitlab_early_auth_check" {
  description = "If true with enable_gitlab_resources, GitLab provider validates the token at plan/apply (gitlab_api_url must resolve and be reachable)."
  type        = bool
  default     = false
}

variable "gitlab_api_token" {
  description = "GitLab API token for the GitLab provider (required when enable_gitlab_resources is true)"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.gitlab_api_token == "" || (!can(regex("\\s", var.gitlab_api_token)) && length(var.gitlab_api_token) >= 8)
    error_message = "gitlab_api_token must be empty or at least 8 characters without spaces."
  }

  validation {
    condition     = !var.enable_gitlab_resources || length(trimspace(var.gitlab_api_token)) >= 8
    error_message = "gitlab_api_token is required when enable_gitlab_resources is true."
  }
}

variable "gitlab_api_url" {
  description = "GitLab instance URL for the Terraform provider (self-hosted root URL, e.g. https://gitlab.cicd-showcase.de — not gitlab.com when GitLab runs on your server)"
  type        = string
  default     = "https://gitlab.com"

  validation {
    condition     = can(regex("^https?://[^\\s/]+(/[^\\s]*)?$", var.gitlab_api_url))
    error_message = "gitlab_api_url must be an http or https URL without spaces (e.g. https://gitlab.example.com)."
  }
}
variable "gitlab_docker_traefik_acme_enabled" {
  description = "When gitlab_install_mode is docker_compose, enable Let's Encrypt on Traefik (HTTP-01 on port 80). Requires DNS A record pointing to this server."
  type        = bool
  default     = false

  validation {
    condition     = !var.gitlab_docker_traefik_acme_enabled || var.gitlab_install_mode == "docker_compose"
    error_message = "gitlab_docker_traefik_acme_enabled is only supported when gitlab_install_mode is docker_compose."
  }
}

variable "gitlab_letsencrypt_enabled" {
  description = "If true (only when gitlab_install_mode is hetzner_app), bootstrap sets https + integrated Let's Encrypt (HTTP-01). Ignored for docker_compose (use gitlab_docker_traefik_acme_enabled there)."
  type        = bool
  default     = false

  validation {
    condition     = !var.gitlab_letsencrypt_enabled || var.gitlab_install_mode == "hetzner_app"
    error_message = "gitlab_letsencrypt_enabled is only supported when gitlab_install_mode is hetzner_app (use gitlab_docker_traefik_acme_enabled for docker_compose)."
  }
}

variable "gitlab_docker_backup_enabled" {
  description = "When Docker Compose / Omnibus GitLab stack is active, configure gitlab_rails backup settings, host backup/restore scripts, and optional scheduled backups."
  type        = bool
  default     = true

  validation {
    condition = !var.gitlab_docker_backup_enabled || var.gitlab_install_mode == "docker_compose" || var.gitlab_install_mode == "hetzner_app" || var.gitlab_install_mode == "proxmox" || (
      var.enable_proxmox_resources && var.proxmox_gitlab_docker_compose_enabled
    )
    error_message = "gitlab_docker_backup_enabled is only supported when gitlab_install_mode is docker_compose, hetzner_app, proxmox, or Proxmox GitLab Docker stack is enabled."
  }
}

variable "gitlab_docker_backup_auto_enabled" {
  description = "When gitlab_docker_backup_enabled is true, install /etc/cron.d/gitlab-backup for scheduled gitlab-backup create on the host."
  type        = bool
  default     = true

  validation {
    condition     = !var.gitlab_docker_backup_auto_enabled || var.gitlab_docker_backup_enabled
    error_message = "gitlab_docker_backup_auto_enabled requires gitlab_docker_backup_enabled = true."
  }
}

variable "gitlab_docker_backup_time" {
  description = "Daily backup time (HH:MM, 24h, host timezone) when gitlab_docker_backup_cron is empty."
  type        = string
  default     = "03:00"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.gitlab_docker_backup_time))
    error_message = "gitlab_docker_backup_time must be HH:MM in 24h format (e.g. 03:00)."
  }
}

variable "gitlab_docker_backup_cron" {
  description = "Optional cron override (minute hour dom month dow). Empty = derive from gitlab_docker_backup_time."
  type        = string
  default     = ""

  validation {
    condition     = trimspace(var.gitlab_docker_backup_cron) == "" || can(regex("^[^\\s]+ [^\\s]+ [^\\s]+ [^\\s]+ [^\\s]+$", trimspace(var.gitlab_docker_backup_cron)))
    error_message = "gitlab_docker_backup_cron must be empty or five cron fields (e.g. 0 3 * * *)."
  }
}

variable "gitlab_docker_backup_keep_time" {
  description = "gitlab_rails backup_keep_time in seconds (0 = keep all archives). See https://docs.gitlab.com/omnibus/settings/backups.html"
  type        = number
  default     = 604800

  validation {
    condition     = var.gitlab_docker_backup_keep_time >= 0
    error_message = "gitlab_docker_backup_keep_time must be >= 0."
  }
}

variable "gitlab_dns_record_name" {
  description = "DNS A record (relative to zone) for GitLab when gitlab_install_mode is hetzner_app or docker_compose"
  type        = string
  default     = "gitlab"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.gitlab_dns_record_name))
    error_message = "gitlab_dns_record_name must be a valid DNS label (lowercase letters, digits, hyphen)."
  }
}

variable "gitlab_letsencrypt_email" {
  description = "ACME contact for Omnibus LE (hetzner_app) and Traefik ACME (docker_compose); if empty, gitlab-acme@<zone> is used"
  type        = string
  default     = ""

  validation {
    condition     = var.gitlab_letsencrypt_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.gitlab_letsencrypt_email))
    error_message = "gitlab_letsencrypt_email must be empty or a simple email without spaces or quotes."
  }
}

variable "gitlab_root_email" {
  description = "Email for GitLab root on first boot (GITLAB_ROOT_EMAIL in docker_compose / Proxmox Docker stack). Empty: gitlab_letsencrypt_email, else gitlab-root@<zone>. Only applied on initial install (empty data dir)."
  type        = string
  default     = ""

  validation {
    condition     = var.gitlab_root_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.gitlab_root_email))
    error_message = "gitlab_root_email must be empty or a simple email without spaces or quotes."
  }

  validation {
    condition = var.gitlab_root_email == "" || var.gitlab_install_mode == "docker_compose" || (
      var.enable_proxmox_resources && var.proxmox_gitlab_docker_compose_enabled
    )
    error_message = "gitlab_root_email is only supported when gitlab_install_mode is docker_compose or Proxmox GitLab Docker stack is enabled."
  }
}

variable "gitlab_signup_enabled" {
  description = "When gitlab_install_mode is docker_compose, set gitlab_rails['gitlab_signup_enabled'] in gitlab.rb (allow new users to register on the sign-in page)"
  type        = bool
  default     = false

  validation {
    condition     = var.gitlab_install_mode == "docker_compose" || !var.gitlab_signup_enabled
    error_message = "gitlab_signup_enabled is only supported when gitlab_install_mode is docker_compose."
  }
}
variable "gitlab_display_initial_root_password" {
  description = "If true, display the initial root password in gitlab.rb (gitlab_rails['display_initial_root_password'])"
  type        = bool
  default     = false

  validation {
    condition     = !var.gitlab_display_initial_root_password || var.gitlab_install_mode == "docker_compose"
    error_message = "gitlab_display_initial_root_password is only supported when gitlab_install_mode is docker_compose."
  }
}

variable "artifacts_enabled" {
  description = "When docker_compose (or Proxmox GitLab Docker stack), enable CI job artifacts in gitlab.rb (gitlab_rails['artifacts_enabled'])"
  type        = bool
  default     = true

  validation {
    condition = !var.artifacts_enabled || var.gitlab_install_mode == "docker_compose" || (
      var.enable_proxmox_resources && var.proxmox_gitlab_docker_compose_enabled
    )
    error_message = "artifacts_enabled is only supported when gitlab_install_mode is docker_compose or Proxmox GitLab Docker stack is enabled."
  }
}

variable "artifacts_path" {
  description = "Job artifacts directory inside the GitLab CE container (bind-mount host path ./artifacts/data when artifacts_enabled)"
  type        = string
  default     = "/var/opt/gitlab/gitlab-rails/shared/artifacts"

  validation {
    condition     = can(regex("^/[^\\s]+$", var.artifacts_path))
    error_message = "artifacts_path must be an absolute path without spaces."
  }

  validation {
    condition     = !var.artifacts_enabled || can(regex("^/var/opt/gitlab/", var.artifacts_path))
    error_message = "artifacts_path must be under /var/opt/gitlab/ when artifacts_enabled (matches ./artifacts/data bind-mount)."
  }
}

###! Docs: https://docs.gitlab.com/ee/administration/terraform_state
variable "gitlab_terraform_enabled" {
  description = "If true, enable Terraform in gitlab.rb (gitlab_rails['terraform_enabled'])"
  type        = bool
  default     = false

  validation {
    condition     = !var.gitlab_terraform_enabled || var.gitlab_install_mode == "docker_compose"
    error_message = "gitlab_terraform_enabled is only supported when gitlab_install_mode is docker_compose."
  }
}
variable "gitlab_terraform_state_path" {
  description = "GitLab Terraform state directory inside the CE container (bind-mount host path ./data/terraform/state)"
  type        = string
  default     = "/var/opt/gitlab/data/terraform/state"

  validation {
    condition     = can(regex("^/[^\\s]+$", var.gitlab_terraform_state_path))
    error_message = "gitlab_terraform_state_path must be an absolute path without spaces."
  }
}
variable "gitlab_terraform_state_file" {
  description = "Terraform state file name under gitlab_terraform_state_path"
  type        = string
  default     = "terraform.tfstate"

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._-]*$", var.gitlab_terraform_state_file))
    error_message = "gitlab_terraform_state_file must be a valid file name (e.g. terraform.tfstate)."
  }
}


variable "gitlab_smtp_enabled" {
  description = "If true (only docker_compose), enable outbound email in gitlab.rb (gitlab_rails SMTP settings)"
  type        = bool
  default     = false

  validation {
    condition     = !var.gitlab_smtp_enabled || var.gitlab_install_mode == "docker_compose"
    error_message = "gitlab_smtp_enabled is only supported when gitlab_install_mode is docker_compose."
  }
}

variable "gitlab_smtp_address" {
  description = "SMTP server hostname (required when gitlab_smtp_enabled is true)"
  type        = string
  default     = ""

  validation {
    condition     = !var.gitlab_smtp_enabled || length(trimspace(var.gitlab_smtp_address)) > 0
    error_message = "gitlab_smtp_address is required when gitlab_smtp_enabled is true."
  }
}

variable "gitlab_smtp_port" {
  description = "SMTP port (e.g. 587 for STARTTLS, 465 for SMTPS)"
  type        = number
  default     = 587

  validation {
    condition     = var.gitlab_smtp_port > 0 && var.gitlab_smtp_port <= 65535
    error_message = "gitlab_smtp_port must be between 1 and 65535."
  }
}

variable "gitlab_smtp_user_name" {
  description = "SMTP authentication username (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "gitlab_smtp_password" {
  description = "SMTP authentication password (optional, sensitive)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "gitlab_smtp_domain" {
  description = "HELO/EHLO domain for SMTP; if empty, dns_domain is used"
  type        = string
  default     = ""
}

variable "gitlab_smtp_authentication" {
  description = "SMTP auth method: login, plain, cram_md5, or none"
  type        = string
  default     = "login"

  validation {
    condition     = contains(["login", "plain", "cram_md5", "none"], var.gitlab_smtp_authentication)
    error_message = "gitlab_smtp_authentication must be one of: login, plain, cram_md5, none."
  }
}

variable "gitlab_smtp_enable_starttls_auto" {
  description = "Enable STARTTLS when connecting to SMTP (typical for port 587)"
  type        = bool
  default     = true
}

variable "gitlab_smtp_tls" {
  description = "Use SMTPS (implicit TLS, typical for port 465)"
  type        = bool
  default     = false
}

variable "gitlab_smtp_openssl_verify_mode" {
  description = "OpenSSL verify mode for SMTP TLS: none, peer, client_once, fail_if_no_peer_cert"
  type        = string
  default     = "peer"

  validation {
    condition     = contains(["none", "peer", "client_once", "fail_if_no_peer_cert"], var.gitlab_smtp_openssl_verify_mode)
    error_message = "gitlab_smtp_openssl_verify_mode must be none, peer, client_once, or fail_if_no_peer_cert."
  }
}

variable "gitlab_email_from" {
  description = "From address for GitLab emails (required when gitlab_smtp_enabled is true)"
  type        = string
  default     = ""

  validation {
    condition     = var.gitlab_email_from == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.gitlab_email_from))
    error_message = "gitlab_email_from must be empty or a simple email address."
  }

  validation {
    condition     = !var.gitlab_smtp_enabled || length(trimspace(var.gitlab_email_from)) > 0
    error_message = "gitlab_email_from is required when gitlab_smtp_enabled is true."
  }
}

variable "gitlab_email_reply_to" {
  description = "Reply-To for GitLab emails; if empty, only gitlab_email_from is set"
  type        = string
  default     = ""

  validation {
    condition     = var.gitlab_email_reply_to == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.gitlab_email_reply_to))
    error_message = "gitlab_email_reply_to must be empty or a simple email address."
  }
}

variable "gitlab_bootstrap_wait_seconds" {
  description = "Seconds to wait in bootstrap script before gitlab-ctl reconfigure (DNS propagation)"
  type        = number
  default     = 120

  validation {
    condition     = var.gitlab_bootstrap_wait_seconds >= 0 && var.gitlab_bootstrap_wait_seconds <= 3600
    error_message = "gitlab_bootstrap_wait_seconds must be between 0 and 3600."
  }
}

variable "enable_gitlab_runner" {
  description = "If true, provision a dedicated GitLab Runner VM (cpx22), runner firewall, and A record in the same DNS zone"
  type        = bool
  default     = false
}

variable "gitlab_runner_install_package" {
  description = "If true (and enable_gitlab_runner), cloud-init installs GitLab Runner from the official .deb packages (helper + arch-specific) per https://docs.gitlab.com/runner/install/linux-manually/ and enables the systemd unit. If false, only Ubuntu is provisioned (install manually)."
  type        = bool
  default     = true
}

variable "gitlab_runner_server_name" {
  description = "hcloud_server name for the GitLab Runner host"
  type        = string
  default     = "runner05"

  validation {
    condition     = length(var.gitlab_runner_server_name) > 0 && length(var.gitlab_runner_server_name) <= 63
    error_message = "gitlab_runner_server_name must be 1–63 characters."
  }
}

variable "gitlab_runner_dns_label" {
  description = "Relative DNS name (A record) for the runner in dns_domain; FQDN becomes <label>.<zone> (e.g. runner05.cicd-showcase.de)"
  type        = string
  default     = "runner05"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.gitlab_runner_dns_label))
    error_message = "gitlab_runner_dns_label must be a valid DNS label (lowercase letters, digits, hyphen)."
  }
}

variable "gitlab_runner_image" {
  description = "Hetzner image slug for the GitLab Runner server (e.g. ubuntu-24.04)"
  type        = string
  default     = "ubuntu-24.04"
}

variable "gitlab_runner_location" {
  description = "Hetzner location for the GitLab Runner server; if empty, uses var.location"
  type        = string
  default     = ""

  validation {
    condition     = var.gitlab_runner_location == "" || contains(["fsn1", "nbg1", "hel1", "ash", "hil"], var.gitlab_runner_location)
    error_message = "gitlab_runner_location must be empty or one of: fsn1, nbg1, hel1, ash, hil."
  }
}

variable "dns_ipv4_record_name" {
  description = "DNS A record name when gitlab_install_mode is none (points to server public IPv4)"
  type        = string
  default     = "web1"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.dns_ipv4_record_name))
    error_message = "dns_ipv4_record_name must be a valid DNS label."
  }
}
# Hetzner DNS variables
variable "create_hcloud_dns_zone" {
  description = "If false, use an existing Hetzner DNS zone named dns_domain (no hcloud_zone create; avoids 409 uniqueness_error)"
  type        = bool
  default     = true
}

variable "enable_hetzner_dns" {
  description = "Manage Hetzner DNS (module.dns and GitLab-related A records). null = auto: false when Proxmox is the only GitLab target (enable_proxmox_resources + proxmox_gitlab_docker_compose_enabled + gitlab_install_mode = none)."
  type        = bool
  default     = null
}

variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "hetzner_api_key" {
  description = "Hetzner DNS API token from https://dns.hetzner.com/ (DNS-01 for Traefik ACME). Not the Hetzner Cloud API token (hcloud_token)."
  type        = string
  sensitive   = true
}
## site variables
variable "site_url" {
  description = "Main URL of the website"
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^https://", var.site_url))
    error_message = "Site URL must start with https://."
  }
}

## domain variables

variable "dns_domain" {
  description = "Hetzner DNS zone name (e.g. example.com); base for gitlab_fqdn, mail records, and PTR when GitLab is disabled"
  type        = string
  default     = "cicd-showcase.de"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.dns_domain)) && strcontains(var.dns_domain, ".")
    error_message = "Domain must be a valid hostname with at least one dot (e.g. example.com)."
  }
}

variable "mail_mx_value" {
  description = "MX record value: priority and hostname (e.g. 10 mail.example.com)"
  type        = string
  default     = "10 mail.henrystadthagen.de"

  validation {
    condition     = can(regex("^[0-9]+\\s+[a-z0-9]([a-z0-9.-]*[a-z0-9])?(\\.?)$", var.mail_mx_value))
    error_message = "MX value must be 'priority hostname' (e.g. 10 mail.example.com)."
  }
}
variable "dmarc_value" {
  description = "DMARC TXT record value (must contain v=DMARC1)"
  type        = string
  default     = "v=DMARC1;p=quarantine;pct=100;rua=mailto:info@henrystadthagen.de"

  validation {
    condition     = strcontains(var.dmarc_value, "v=DMARC1")
    error_message = "DMARC value must contain v=DMARC1."
  }
}
variable "dkim_value" {
  description = "DKIM TXT record value for the domain"
  type        = string
  default     = "v=DKIM1;k=rsa;t=s;s=email;p=MMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2nXMiln1XG9H6pS7bspMDR9PLnm9FjzMwpy1U7ocBZhh/vQmTAZerL2Az3FLKmy4INqAQkz7E9TtkZQaScB6acwOPdPu34oHU9iYgXSvIOXbKmjapUboBvejEjN9wAPWMiy7oTEkUHmY7ZhrAkdKN2H77Tvj4L5ay3v6afyBWyX1hGx/aU/qvwSRVOkQ8LVOaaJsvGxsji1sYvhYKb6ksLkEhccnfXItisNmUBJt2Fkjd0aGj4IFx+Hbl+Ws0ENdbVZuQzxK4RMfgiwjHfi4gmvHICsWbvV7oWbG2HZXRj+6WiTplei1y63Ls3IkSZwVI524EKCXzg8+vcn/yBW1LwIDAQAB"
}
variable "spf_value" {
  description = "SPF TXT record value for the domain"
  type        = string
  default     = "v=spf1 ip4:91.107.238.126 mx -all"

  validation {
    condition     = strcontains(var.spf_value, "v=spf1")
    error_message = "SPF value must contain v=spf1."
  }
}
variable "tlsa_value" {
  description = "TLSA record value (usage selector matching cert)"
  type        = string
  default     = "3 1 1 aed2a71af8346edd13e4c0e36a9662a329cbb59cf1283573ea75d69ef9600b4f"
}
variable "srv_value" {
  description = "SRV value: priority weight port target (target must end with a dot)"
  type        = string
  default     = "0 0 443 mail.henrystadthagen.de."

  validation {
    condition     = can(regex("^[0-9]+\\s+[0-9]+\\s+[0-9]+\\s+.+\\.$", var.srv_value))
    error_message = "SRV value must be 'priority weight port target.' (target must end with a dot)."
  }
}
variable "iodef_value" {
  description = "CAA IODEF record value (e.g. mailto:)"
  type        = string
  default     = "mailto:info@henrystadthagen.de"
}

variable "contact_value" {
  description = "CAA contact record value (e.g. mailto:)"
  type        = string
  default     = "mailto:info@henrystadthagen.de"
}

variable "mail_server_ipv4" {
  description = "IPv4 for the mail A record in module.dns (align SPF ip4: with this host if you use ip4: in spf_value)"
  type        = string
  default     = "91.107.238.126"

  validation {
    condition = can(regex(
      "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",
      var.mail_server_ipv4
    ))
    error_message = "mail_server_ipv4 must be a dotted IPv4 address."
  }
}

variable "mail_server_ipv6" {
  description = "IPv6 for the mail AAAA record in module.dns"
  type        = string
  default     = "2a01:4f8:1c0c:5bc1::1"

  validation {
    condition = (
      can(regex(":", var.mail_server_ipv6))
      && length(trimspace(var.mail_server_ipv6)) <= 128
      && !strcontains(var.mail_server_ipv6, " ")
    )
    error_message = "mail_server_ipv6 must look like an IPv6 address (contain ':', no spaces, max 128 chars)."
  }
}

variable "mail_server_cname_target" {
  description = "CNAME target for autoconfig/autodiscover in module.dns (FQDN hostname)"
  type        = string
  default     = "mail.henrystadthagen.de"

  validation {
    condition = can(regex(
      "^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$",
      var.mail_server_cname_target
    ))
    error_message = "mail_server_cname_target must be a valid DNS hostname (no scheme, no trailing dot required)."
  }
}

variable "dns_tlsa_name" {
  description = "TLSA record name (e.g. _25._tcp.mail.example.com) passed to module.dns"
  type        = string
  default     = "_25._tcp.mail.henrystadthagen.de"

  validation {
    condition = can(regex(
      "^[a-zA-Z0-9_][a-zA-Z0-9_.-]*[a-zA-Z0-9]$|^[a-zA-Z0-9_]$",
      var.dns_tlsa_name
    ))
    error_message = "dns_tlsa_name must be a non-empty DNS name (labels, dots, underscores)."
  }
}
## Proxmox variables

variable "enable_proxmox_resources" {
  description = "If true, create Proxmox VMs via module.proxmox. Requires proxmox_api_token."
  type        = bool
  default     = false
}

variable "proxmox_gitlab_docker_compose_enabled" {
  description = "When enable_proxmox_resources is true, bootstrap GitLab via the same cloud-init as docker_compose (Traefik + GitLab CE + PostgreSQL)"
  type        = bool
  default     = false

  validation {
    condition     = !var.proxmox_gitlab_docker_compose_enabled || var.enable_proxmox_resources
    error_message = "proxmox_gitlab_docker_compose_enabled requires enable_proxmox_resources."
  }
}

variable "proxmox_gitlab_vmid" {
  description = "Proxmox VM ID for GitLab VM; 0 = next free ID (no plan-time availability check). Used when gitlab_install_mode = proxmox."
  type        = number
  default     = 0

  validation {
    condition     = var.proxmox_gitlab_vmid == 0 || (var.proxmox_gitlab_vmid >= 100 && var.proxmox_gitlab_vmid <= 999999999)
    error_message = "proxmox_gitlab_vmid must be 0 (auto) or between 100 and 999999999."
  }
}

variable "proxmox_runner_vmid" {
  description = "Proxmox VM ID for optional Runner VM; 0 = next free ID (no plan-time availability check)"
  type        = number
  default     = 0

  validation {
    condition     = var.proxmox_runner_vmid == 0 || (var.proxmox_runner_vmid >= 100 && var.proxmox_runner_vmid <= 999999999)
    error_message = "proxmox_runner_vmid must be 0 (auto) or between 100 and 999999999."
  }
}
# Proxmox VM/provider variables: copy proxmox_variables.tf.example → proxmox_variables.tf with proxmox.tf.

