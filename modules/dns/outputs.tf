output "zone_id" {
  description = "ID of the created DNS zone"
  value       = hcloud_zone.main.id
}

output "zone_name" {
  description = "Name of the DNS zone"
  value       = hcloud_zone.main.name
}

output "zone_authoritative_nameservers" {
  description = "Authoritative nameservers for the DNS zone"
  value       = hcloud_zone.main.authoritative_nameservers
}

output "zone_primary_nameservers" {
  description = "Primary nameservers for the DNS zone"
  value       = hcloud_zone.main.primary_nameservers
}
