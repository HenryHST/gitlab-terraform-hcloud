# TXT records >255 chars: API expects one record per chunk (each chunk quoted, max 255 chars)
locals {
  dkim_chunks = [for i in range(ceil(length(var.dkim_value) / 255)) : substr(var.dkim_value, i * 255, 255)]
  zone_name   = var.create_zone ? hcloud_zone.main[0].name : data.hcloud_zone.existing[0].name
}

resource "hcloud_zone" "main" {
  count    = var.create_zone ? 1 : 0
  provider = hcloud.dns
  name     = var.domain_name
  mode     = "primary"
}

data "hcloud_zone" "existing" {
  count    = var.create_zone ? 0 : 1
  provider = hcloud.dns
  name     = var.domain_name
}

resource "hcloud_zone_record" "web-web1" {
  provider = hcloud.dns
  zone     = local.zone_name
  name     = var.ipv4_a_record_name
  type     = "A"
  value    = var.server_ipv4
}

resource "hcloud_zone_record" "web-dmarc" {
  provider = hcloud.dns
  zone     = local.zone_name
  name     = "_dmarc"
  type     = "TXT"
  value    = "\"${var.dmarc_value}\""
}

resource "hcloud_zone_record" "web-mailipv4" {
  provider = hcloud.dns
  zone     = local.zone_name
  name     = "mail"
  type     = "A"
  value    = var.mail_ipv4
}

resource "hcloud_zone_record" "web-mail-mx" {
  provider = hcloud.dns
  zone     = local.zone_name
  name     = "mail"
  type     = "MX"
  value    = var.mail_mx_value
}

resource "hcloud_zone_record" "web-autoconfig" {
  provider = hcloud.dns
  zone     = local.zone_name
  name     = "autoconfig"
  type     = "CNAME"
  value    = var.mail_cname_target
}

resource "hcloud_zone_record" "web-autodiscover" {
  provider = hcloud.dns
  zone     = local.zone_name
  name     = "autodiscover"
  type     = "CNAME"
  value    = var.mail_cname_target
}

resource "hcloud_zone_record" "web-mailipv6" {
  provider = hcloud.dns
  zone     = local.zone_name
  name     = "mail"
  type     = "AAAA"
  value    = var.mail_ipv6
}

resource "hcloud_zone_record" "web-dkim" {
  count    = length(local.dkim_chunks)
  provider = hcloud.dns
  zone     = local.zone_name
  name     = "dkim"
  type     = "TXT"
  value    = "\"${local.dkim_chunks[count.index]}\""
}

resource "hcloud_zone_record" "web-caa-selector" {
  count    = var.enable_caa_records ? 1 : 0
  provider = hcloud.dns
  zone     = local.zone_name
  name     = "@"
  type     = "CAA"
  value    = "0 issue \"letsencrypt.org\""
}

resource "hcloud_zone_record" "web-caa-wildcard" {
  count    = var.enable_caa_records ? 1 : 0
  provider = hcloud.dns
  zone     = local.zone_name
  name     = "@"
  type     = "CAA"
  value    = "0 issuewild \"letsencrypt.org\""
}

resource "hcloud_zone_record" "web-caa-iodef" {
  count    = var.enable_caa_records ? 1 : 0
  provider = hcloud.dns
  zone     = local.zone_name
  name     = "@"
  type     = "CAA"
  value    = "0 iodef \"${var.iodef_value}\""
}

resource "hcloud_zone_record" "web-caa-contact" {
  count    = var.enable_caa_records ? 1 : 0
  provider = hcloud.dns
  zone     = local.zone_name
  name     = "@"
  type     = "CAA"
  value    = "0 contact \"${var.contact_value}\""
}

resource "hcloud_zone_record" "web-spf" {
  provider = hcloud.dns
  zone     = local.zone_name
  name     = "@"
  type     = "TXT"
  value    = "\"${var.spf_value}\""
}

resource "hcloud_zone_record" "web-tlsa-selector" {
  provider = hcloud.dns
  zone     = local.zone_name
  name     = var.tlsa_name
  type     = "TLSA"
  value    = var.tlsa_value
}

resource "hcloud_zone_record" "web-srv-selector" {
  provider = hcloud.dns
  zone     = local.zone_name
  name     = var.srv_name
  type     = "SRV"
  value    = var.srv_value
}
