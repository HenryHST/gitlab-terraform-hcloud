locals {
  gitlab_fqdn                = "${var.gitlab_dns_record_name}.${var.domain_cicd_showcase_de}"
  gitlab_enabled             = var.gitlab_install_mode != "none"
  gitlab_letsencrypt_contact = var.gitlab_letsencrypt_email != "" ? var.gitlab_letsencrypt_email : "gitlab-acme@${var.domain_cicd_showcase_de}"

  # Hetzner one-click GitLab image slug (see https://github.com/hetznercloud/apps/tree/main/apps/hetzner/gitlab)
  server_image_effective = (
    var.gitlab_install_mode == "hetzner_app" ? "gitlab" :
    var.gitlab_install_mode == "docker_compose" ? coalesce(var.gitlab_docker_host_image, "debian-13") :
    var.server_image
  )

  gitlab_docker_external_url_scheme = var.gitlab_docker_traefik_acme_enabled ? "https" : "http"

  gitlab_user_data = (
    var.gitlab_install_mode == "hetzner_app" ? templatefile("${path.module}/templates/gitlab-cloud-init.yaml.tpl", {
      gitlab_fqdn                = local.gitlab_fqdn
      letsencrypt_email          = local.gitlab_letsencrypt_contact
      bootstrap_wait             = var.gitlab_bootstrap_wait_seconds
      gitlab_letsencrypt_enabled = var.gitlab_letsencrypt_enabled
    }) :
    var.gitlab_install_mode == "docker_compose" ? templatefile("${path.module}/templates/gitlab-docker-cloud-init.yaml.tpl", {
      gitlab_fqdn          = local.gitlab_fqdn
      gitlab_root_password = random_password.gitlab_docker_root[0].result
      traefik_image        = var.gitlab_docker_traefik_image
      gitlab_ce_image      = var.gitlab_docker_gitlab_ce_image
      acme_enabled         = var.gitlab_docker_traefik_acme_enabled
      acme_email           = local.gitlab_letsencrypt_contact
      external_url_scheme  = local.gitlab_docker_external_url_scheme
    }) : ""
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
  count   = var.gitlab_install_mode == "docker_compose" ? 1 : 0
  length  = 24
  special = false
}

# Firewall Module
module "firewall" {
  source = "./modules/firewall"

  firewall_name = "${var.server_name}-firewall"
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

# DNS Module
module "dns" {
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
  count    = var.enable_gitlab_runner ? 1 : 0
  provider = hcloud.dns
  zone     = module.dns.zone_name
  name     = var.gitlab_runner_dns_label
  type     = "A"
  value    = module.gitlab_runner[0].server_ipv4
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
