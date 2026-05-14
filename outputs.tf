# Server outputs
output "server_ip" {
  description = "Public IPv4 address of the server"
  value       = module.server.server_ipv4
}

output "server_ipv6" {
  description = "Public IPv6 address of the server"
  value       = module.server.server_ipv6
}

output "server_name" {
  description = "Name of the server"
  value       = module.server.server_name
}

output "server_id" {
  description = "ID of the server"
  value       = module.server.server_id
}

output "server_status" {
  description = "Status of the server"
  value       = module.server.server_status
}

# Firewall outputs
output "firewall_id" {
  description = "ID of the firewall"
  value       = module.firewall.firewall_id
}

output "firewall_name" {
  description = "Name of the firewall"
  value       = module.firewall.firewall_name
}

# SSH connection
output "ssh_connection" {
  description = "SSH connection command"
  value       = module.server.ssh_connection
}

# DNS outputs
output "dns_zone_id" {
  description = "ID of the DNS zone"
  value       = module.dns.zone_id
}

output "dns_zone_name" {
  description = "Name of the DNS zone"
  value       = module.dns.zone_name
}

# Other outputs
output "website_url" {
  description = "Website URL"
  value       = var.site_url
}

output "domain_cicd_showcase_de" {
  description = "Domain for the website cicd-showcase.de"
  value       = module.dns.zone_name
}

output "gitlab_url" {
  description = "GitLab HTTPS URL when enable_gitlab_app is true"
  value       = var.enable_gitlab_app ? "https://${local.gitlab_fqdn}" : null
}

output "gitlab_fqdn" {
  description = "GitLab hostname (A record target) when enable_gitlab_app is true"
  value       = var.enable_gitlab_app ? local.gitlab_fqdn : null
}
