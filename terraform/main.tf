locals {
  gitlab_fqdn                = "${var.gitlab_dns_record_name}.${var.domain_cicd_showcase_de}"
  renovate_fqdn              = "${var.gitlab_docker_renovate_dns_label}.${var.domain_cicd_showcase_de}"
  registry_fqdn              = "${var.gitlab_docker_registry_dns_label}.${var.domain_cicd_showcase_de}"
  gitlab_enabled             = var.gitlab_install_mode != "none"
  gitlab_letsencrypt_contact = var.gitlab_letsencrypt_email != "" ? var.gitlab_letsencrypt_email : "gitlab-acme@${var.domain_cicd_showcase_de}"
  gitlab_root_email_effective = (
    var.gitlab_root_email != "" ? var.gitlab_root_email :
    var.gitlab_letsencrypt_email != "" ? var.gitlab_letsencrypt_email :
    "gitlab-root@${var.domain_cicd_showcase_de}"
  )

  proxmox_gitlab_docker       = var.enable_proxmox_resources && var.proxmox_gitlab_docker_compose_enabled
  proxmox_gitlab_primary      = local.proxmox_gitlab_docker && var.gitlab_install_mode == "none"
  manage_hetzner_dns          = var.enable_hetzner_dns != null ? var.enable_hetzner_dns : !local.proxmox_gitlab_primary
  gitlab_docker_stack_enabled = var.gitlab_install_mode == "docker_compose" || local.proxmox_gitlab_docker

  gitlab_docker_external_url_scheme = var.gitlab_docker_traefik_acme_enabled ? "https" : "http"
  gitlab_api_v4_endpoint            = "${local.gitlab_docker_external_url_scheme}://${local.gitlab_fqdn}/api/v4/"
  gitlab_smtp_domain_effective      = var.gitlab_smtp_domain != "" ? var.gitlab_smtp_domain : var.domain_cicd_showcase_de

  gitlab_docker_cloud_init_vars = {
    gitlab_fqdn          = local.gitlab_fqdn
    hetzner_api_token    = var.hetzner_api_key
    renovate_fqdn        = local.renovate_fqdn
    gitlab_root_password = local.gitlab_docker_stack_enabled ? random_password.gitlab_docker_root[0].result : ""
    gitlab_root_email    = local.gitlab_root_email_effective
    postgres_password    = local.gitlab_docker_stack_enabled ? random_password.gitlab_docker_postgres[0].result : ""
    traefik_image        = var.gitlab_docker_traefik_image
    gitlab_ce_image      = var.gitlab_docker_gitlab_ce_image
    postgres_image       = var.gitlab_docker_postgres_image
    acme_enabled         = var.gitlab_docker_traefik_acme_enabled
    acme_email           = local.gitlab_letsencrypt_contact
    external_url_scheme  = local.gitlab_docker_external_url_scheme
    renovate_enabled     = var.gitlab_docker_renovate_enabled
    renovate_ce_image    = var.gitlab_docker_renovate_ce_image
    renovate_license_key = var.gitlab_docker_renovate_license_key
    renovate_gitlab_pat  = var.gitlab_docker_renovate_gitlab_pat
    renovate_webhook_secret = (
      var.gitlab_docker_renovate_enabled && local.gitlab_docker_stack_enabled ? random_password.gitlab_renovate_webhook[0].result : ""
    )
    renovate_server_api_secret = (
      var.gitlab_docker_renovate_enabled && local.gitlab_docker_stack_enabled ? random_password.gitlab_renovate_server_api[0].result : ""
    )
    registry_enabled          = var.gitlab_docker_registry_enabled
    registry_fqdn             = local.registry_fqdn
    gitlab_api_v4_endpoint    = local.gitlab_api_v4_endpoint
    smtp_enabled              = var.gitlab_smtp_enabled
    smtp_address              = var.gitlab_smtp_address
    smtp_port                 = var.gitlab_smtp_port
    smtp_user_name            = var.gitlab_smtp_user_name
    smtp_password             = var.gitlab_smtp_password
    smtp_domain               = local.gitlab_smtp_domain_effective
    smtp_authentication       = var.gitlab_smtp_authentication
    smtp_enable_starttls_auto = var.gitlab_smtp_enable_starttls_auto
    smtp_tls                  = var.gitlab_smtp_tls
    smtp_openssl_verify_mode  = var.gitlab_smtp_openssl_verify_mode
    gitlab_email_from         = var.gitlab_email_from
    gitlab_email_reply_to     = var.gitlab_email_reply_to
    gitlab_signup_enabled     = var.gitlab_signup_enabled
    backup_enabled            = var.gitlab_docker_backup_enabled
    backup_keep_time          = var.gitlab_docker_backup_keep_time
    backup_cron               = var.gitlab_docker_backup_cron
    runner_enabled            = var.gitlab_docker_runner_enabled
    runner_image              = var.gitlab_docker_runner_image
    runner_token              = var.gitlab_docker_runner_token
    runner_description        = var.gitlab_docker_runner_description
    runner_executor           = var.gitlab_docker_runner_executor
    runner_default_image      = var.gitlab_docker_runner_default_image
    runner_concurrent         = var.gitlab_docker_runner_concurrent
    runner_privileged         = var.gitlab_docker_runner_privileged
    runner_tag_list           = join(", ", [for t in var.gitlab_docker_runner_tags : "\"${t}\""])
    gitlab_url                = "${local.gitlab_docker_external_url_scheme}://${local.gitlab_fqdn}"
  }

  gitlab_docker_user_data = local.gitlab_docker_stack_enabled ? templatefile(
    "${path.module}/templates/gitlab-docker-cloud-init.yaml.tpl",
    local.gitlab_docker_cloud_init_vars,
  ) : ""

  # Hetzner one-click GitLab image slug (see https://github.com/hetznercloud/apps/tree/main/apps/hetzner/gitlab)
  server_image_effective = (
    var.gitlab_install_mode == "hetzner_app" ? "gitlab" :
    var.gitlab_install_mode == "docker_compose" ? coalesce(var.gitlab_docker_host_image, "debian-13") :
    var.server_image
  )

  gitlab_user_data = (
    var.gitlab_install_mode == "hetzner_app" ? templatefile("${path.module}/templates/gitlab-cloud-init.yaml.tpl", {
      gitlab_fqdn                = local.gitlab_fqdn
      letsencrypt_email          = local.gitlab_letsencrypt_contact
      bootstrap_wait             = var.gitlab_bootstrap_wait_seconds
      gitlab_letsencrypt_enabled = var.gitlab_letsencrypt_enabled
      backup_enabled             = var.gitlab_docker_backup_enabled
      backup_keep_time           = var.gitlab_docker_backup_keep_time
      backup_cron                = var.gitlab_docker_backup_cron
    }) :
    var.gitlab_install_mode == "docker_compose" ? local.gitlab_docker_user_data : ""
  )

  rdns_fqdn     = local.gitlab_enabled ? local.gitlab_fqdn : var.domain_cicd_showcase_de
  dns_ipv4_name = local.gitlab_enabled ? var.gitlab_dns_record_name : var.dns_ipv4_record_name

  gitlab_runner_fqdn = "${var.gitlab_runner_dns_label}.${var.domain_cicd_showcase_de}"
  gitlab_runner_location_effective = (
    var.gitlab_runner_location != "" ? var.gitlab_runner_location : var.location
  )
  gitlab_runner_user_data = var.enable_gitlab_runner ? templatefile("${path.module}/templates/gitlab-runner-cloud-init.yaml.tpl", {
    install_package = var.gitlab_runner_install_package
  }) : ""

  ssh_public_key_effective = trimspace(
    var.ssh_public_key_file != ""
    ? chomp(file(pathexpand(var.ssh_public_key_file)))
    : var.ssh_public_key
  )
}

resource "random_password" "gitlab_docker_root" {
  count   = local.gitlab_docker_stack_enabled ? 1 : 0
  length  = 24
  special = false
}

resource "random_password" "gitlab_docker_postgres" {
  count   = local.gitlab_docker_stack_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "gitlab_renovate_webhook" {
  count   = local.gitlab_docker_stack_enabled && var.gitlab_docker_renovate_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "gitlab_renovate_server_api" {
  count   = local.gitlab_docker_stack_enabled && var.gitlab_docker_renovate_enabled ? 1 : 0
  length  = 32
  special = false
}

# Firewall Module
module "firewall" {
  source = "./modules/firewall"

  firewall_name      = "${var.server_name}-firewall"
  enable_egress_smtp = var.gitlab_smtp_enabled
  egress_smtp_port   = var.gitlab_smtp_port
}

# Server Module
module "server" {
  source = "./modules/server"

  server_name    = var.server_name
  server_type    = var.server_type
  location       = var.location
  image          = local.server_image_effective
  ssh_public_key = local.ssh_public_key_effective

  firewall_ids = [module.firewall.firewall_id]

  labels = {
    environment = "prod"
    managed_by  = "terraform"
    project     = "git"
  }

  user_data = local.gitlab_user_data

  enable_rdns      = true
  rdns_ipv4_domain = local.rdns_fqdn
  rdns_ipv6_domain = local.rdns_fqdn
}

module "firewall_runner" {
  count  = var.enable_gitlab_runner ? 1 : 0
  source = "./modules/firewall"

  firewall_name = "${var.gitlab_runner_server_name}-firewall"

  enable_http          = false
  enable_https         = false
  enable_dns           = false
  enable_node_exporter = false
  enable_icmp          = true
  enable_ssh_high      = false
  enable_egress_smtp   = false
}

module "gitlab_runner" {
  count  = var.enable_gitlab_runner ? 1 : 0
  source = "./modules/server"

  server_name = var.gitlab_runner_server_name
  server_type = "cpx22"
  location    = local.gitlab_runner_location_effective
  image       = var.gitlab_runner_image

  # Same fingerprint as module.server: Hetzner allows only one hcloud_ssh_key per key material.
  create_ssh_key     = false
  attach_ssh_key_ids = [module.server.ssh_key_id]
  ssh_public_key     = ""

  firewall_ids = [module.firewall_runner[0].firewall_id]

  labels = {
    role       = "gitlab-runner"
    managed_by = "terraform"
  }

  user_data = local.gitlab_runner_user_data

  enable_rdns      = true
  rdns_ipv4_domain = local.gitlab_runner_fqdn
  rdns_ipv6_domain = local.gitlab_runner_fqdn
}

# DNS Module (skipped when GitLab runs on Proxmox only; see local.manage_hetzner_dns)
module "dns" {
  count  = local.manage_hetzner_dns ? 1 : 0
  source = "./modules/dns"

  create_zone        = var.create_hcloud_dns_zone
  domain_name        = var.domain_cicd_showcase_de
  server_ipv4        = module.server.server_ipv4
  ipv4_a_record_name = local.dns_ipv4_name

  # Mail server configuration
  mail_ipv4         = var.mail_server_ipv4
  mail_ipv6         = var.mail_server_ipv6
  mail_cname_target = var.mail_server_cname_target
  mail_mx_value     = var.mail_mx_value

  # Security records
  dmarc_value = var.dmarc_value
  dkim_value  = var.dkim_value
  spf_value   = var.spf_value

  # CAA records
  enable_caa_records = true
  iodef_value        = var.iodef_value
  contact_value      = var.contact_value

  # TLSA and SRV records
  tlsa_name  = var.dns_tlsa_name
  tlsa_value = var.tlsa_value
  srv_name   = "_autodiscover._tcp"
  srv_value  = var.srv_value

  providers = {
    hcloud.dns = hcloud.dns
  }
}

resource "hcloud_zone_record" "gitlab_runner" {
  count    = var.enable_gitlab_runner && local.manage_hetzner_dns ? 1 : 0
  provider = hcloud.dns
  zone     = module.dns[0].zone_name
  name     = var.gitlab_runner_dns_label
  type     = "A"
  value    = module.gitlab_runner[0].server_ipv4
}

resource "hcloud_zone_record" "renovate" {
  count    = var.gitlab_install_mode == "docker_compose" && var.gitlab_docker_renovate_enabled && local.gitlab_enabled && local.manage_hetzner_dns ? 1 : 0
  provider = hcloud.dns
  zone     = module.dns[0].zone_name
  name     = var.gitlab_docker_renovate_dns_label
  type     = "A"
  value    = module.server.server_ipv4
}

resource "hcloud_zone_record" "registry" {
  count    = var.gitlab_install_mode == "docker_compose" && var.gitlab_docker_registry_enabled && local.gitlab_enabled && local.manage_hetzner_dns ? 1 : 0
  provider = hcloud.dns
  zone     = module.dns[0].zone_name
  name     = var.gitlab_docker_registry_dns_label
  type     = "A"
  value    = module.server.server_ipv4
}

check "ssh_public_key_configured" {
  assert {
    condition     = length(local.ssh_public_key_effective) > 0
    error_message = "Configure ssh_public_key_file or ssh_public_key so Hetzner can provision SSH access."
  }
}

check "gitlab_letsencrypt_implies_app" {
  assert {
    condition     = !var.gitlab_letsencrypt_enabled || var.gitlab_install_mode == "hetzner_app"
    error_message = "gitlab_letsencrypt_enabled is only for hetzner_app (Omnibus integrated LE); use gitlab_docker_traefik_acme_enabled for docker_compose."
  }
}

check "gitlab_runner_requires_hetzner_dns" {
  assert {
    condition     = !var.enable_gitlab_runner || local.manage_hetzner_dns
    error_message = "enable_gitlab_runner needs enable_hetzner_dns = true when GitLab runs on Proxmox only (Hetzner DNS manages the runner A record)."
  }
}
