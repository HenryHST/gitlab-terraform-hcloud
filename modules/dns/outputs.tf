output "zone_id" {
  description = "ID of the DNS zone (created or existing)"
  value       = var.create_zone ? hcloud_zone.main[0].id : data.hcloud_zone.existing[0].id
}

output "zone_name" {
  description = "Name of the DNS zone"
  value       = local.zone_name
}

output "zone_authoritative_nameservers" {
  description = "Authoritative nameservers for the DNS zone"
  value       = var.create_zone ? hcloud_zone.main[0].authoritative_nameservers : data.hcloud_zone.existing[0].authoritative_nameservers
}

output "zone_primary_nameservers" {
  description = "Primary nameservers for the DNS zone"
  value       = var.create_zone ? hcloud_zone.main[0].primary_nameservers : data.hcloud_zone.existing[0].primary_nameservers
}
