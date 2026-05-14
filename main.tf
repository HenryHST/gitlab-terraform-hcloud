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
  image          = "ubuntu-24.04"
  ssh_public_key = var.ssh_public_key

  firewall_ids = [module.firewall.firewall_id]

  labels = {
    environment = "prod"
    managed_by  = "terraform"
    project     = "git"
  }

  

  enable_rdns      = true
  rdns_ipv4_domain = var.domain_cicd_showcase_de
  rdns_ipv6_domain = var.domain_cicd_showcase_de
}

# DNS Module
module "dns" {
  source = "./modules/dns"

  domain_name = var.domain_cicd_showcase_de
  server_ipv4 = module.server.server_ipv4

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
