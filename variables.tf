variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

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

variable "ssh_private_key_path" {
  description = "Path to private SSH key"
  type        = string
  default     = "~/.ssh/id_rsa"
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
  description = "Server type (e.g. cx22 = 2 vCPU 4GB, cpx22 = 3 vCPU 4GB)"
  type        = string
  default     = "cx23"

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

variable "gitlab_install_mode" {
  description = "GitLab platform: none (no GitLab), hetzner_app (Hetzner GitLab image + Omnibus cloud-init), docker_compose (Debian VM + Docker Compose GitLab CE + Traefik v3.7)"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "hetzner_app", "docker_compose"], var.gitlab_install_mode)
    error_message = "gitlab_install_mode must be one of: none, hetzner_app, docker_compose."
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
  description = "gitlab/gitlab-ce image tag for Docker Compose mode"
  type        = string
  default     = "gitlab/gitlab-ce:18.10.5-ce.0"

  validation {
    condition = can(regex(
      "^gitlab/gitlab-ce:[a-zA-Z0-9][a-zA-Z0-9._-]+$",
      var.gitlab_docker_gitlab_ce_image,
    ))
    error_message = "gitlab_docker_gitlab_ce_image must be gitlab/gitlab-ce:<tag> (e.g. gitlab/gitlab-ce:18.10.5-ce.0)."
  }
}

variable "gitlab_docker_postgres_image" {
  description = "PostgreSQL container image for Docker Compose mode (pin major version, e.g. postgres:16-alpine)"
  type        = string
  default     = "postgres:16-alpine"

  validation {
    condition = can(regex(
      "^postgres:[a-zA-Z0-9][a-zA-Z0-9._-]+$",
      var.gitlab_docker_postgres_image,
    ))
    error_message = "gitlab_docker_postgres_image must be postgres:<tag> (e.g. postgres:16-alpine)."
  }
}

variable "gitlab_api_token" {
  description = "GitLab API token for the GitLab API"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.gitlab_api_token == "" || (!can(regex("\\s", var.gitlab_api_token)) && length(var.gitlab_api_token) >= 8)
    error_message = "gitlab_api_token must be empty or at least 8 characters without spaces."
  }
}

variable "gitlab_api_url" {
  description = "GitLab API URL for the GitLab API"
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
  description = "Relative DNS name (A record) for the runner in domain_cicd_showcase_de; FQDN becomes <label>.<zone> (e.g. runner05.cicd-showcase.de)"
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

variable "create_hcloud_dns_zone" {
  description = "If false, use an existing Hetzner DNS zone named domain_cicd_showcase_de (no hcloud_zone create; avoids 409 uniqueness_error)"
  type        = bool
  default     = true
}

variable "github_repo" {
  description = "GitHub repository URL to clone"
  type        = string
  default     = "https://github.com/HenryHST/astro-deploy.git"

  validation {
    condition     = can(regex("^https://", var.github_repo))
    error_message = "GitHub repo must be an HTTPS URL."
  }
}

variable "hetzner_api_key" {
  description = "Hetzner DNS API Key for Traefik Let's Encrypt"
  type        = string
  sensitive   = true
}

variable "traefik_dashboard_credentials" {
  description = "BasicAuth credentials for Traefik dashboard (format: user:$$apr1$$hash$$)"
  type        = string
  sensitive   = true

  validation {
    condition     = strcontains(var.traefik_dashboard_credentials, ":")
    error_message = "Traefik credentials must be in format user:password_or_hash."
  }
}

variable "site_url" {
  description = "Main URL of the website"
  type        = string
  default     = "https://cicd-showcase.de"

  validation {
    condition     = can(regex("^https://", var.site_url))
    error_message = "Site URL must start with https://."
  }
}



variable "domain_cicd_showcase_de" {
  description = "Domain for the website (e.g. cicd-showcase.de)"
  type        = string
  default     = "cicd-showcase.de"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.domain_cicd_showcase_de)) && strcontains(var.domain_cicd_showcase_de, ".")
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