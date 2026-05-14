locals {
  gitlab_fqdn = "${var.gitlab_dns_record_name}.${var.domain_cicd_showcase_de}"
  # Hetzner one-click GitLab image slug (see https://github.com/hetznercloud/apps/tree/main/apps/hetzner/gitlab)
  server_image_effective     = var.enable_gitlab_app ? "gitlab" : var.server_image
  gitlab_letsencrypt_contact = var.gitlab_letsencrypt_email != "" ? var.gitlab_letsencrypt_email : "gitlab-acme@${var.domain_cicd_showcase_de}"
  gitlab_user_data = var.enable_gitlab_app ? templatefile("${path.module}/templates/gitlab-cloud-init.yaml.tpl", {
    gitlab_fqdn       = local.gitlab_fqdn
    letsencrypt_email = local.gitlab_letsencrypt_contact
    bootstrap_wait    = var.gitlab_bootstrap_wait_seconds
  }) : ""
  rdns_fqdn     = var.enable_gitlab_app ? local.gitlab_fqdn : var.domain_cicd_showcase_de
  dns_ipv4_name = var.enable_gitlab_app ? var.gitlab_dns_record_name : var.dns_ipv4_record_name

  ssh_public_key_effective = trimspace(
    var.ssh_public_key_file != ""
    ? chomp(file(pathexpand(var.ssh_public_key_file)))
    : var.ssh_public_key
  )
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

# DNS Module
module "dns" {
  source = "./modules/dns"

  create_zone        = var.create_hcloud_dns_zone
  domain_name        = var.domain_cicd_showcase_de
  server_ipv4        = module.server.server_ipv4
  ipv4_a_record_name = local.dns_ipv4_name

  # Mail server configuration
  mail_ipv4         = "91.107.238.126"
  mail_ipv6         = "2a01:4f8:1c0c:5bc1::1"
  mail_cname_target = "mail.henrystadthagen.de"
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
  tlsa_name  = "_25._tcp.mail.henrystadthagen.de"
  tlsa_value = var.tlsa_value
  srv_name   = "_autodiscover._tcp"
  srv_value  = var.srv_value

  providers = {
    hcloud.dns = hcloud.dns
  }
}
