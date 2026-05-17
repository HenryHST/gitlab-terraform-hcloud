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
  description = "GitLab URL when gitlab_install_mode is hetzner_app or docker_compose (https when Omnibus LE or Traefik ACME is enabled)"
  value = (
    var.gitlab_install_mode == "hetzner_app" ? (
      var.gitlab_letsencrypt_enabled ? "https://${local.gitlab_fqdn}" : "http://${local.gitlab_fqdn}"
    ) :
    var.gitlab_install_mode == "docker_compose" ? (
      var.gitlab_docker_traefik_acme_enabled ? "https://${local.gitlab_fqdn}" : "http://${local.gitlab_fqdn}"
    ) : null
  )
}

output "gitlab_fqdn" {
  description = "GitLab hostname (A record target) when gitlab_install_mode is hetzner_app or docker_compose"
  value       = local.gitlab_enabled ? local.gitlab_fqdn : null
}

output "renovate_fqdn" {
  description = "Renovate CE hostname when docker_compose and gitlab_docker_renovate_enabled"
  value = (
    var.gitlab_install_mode == "docker_compose" && var.gitlab_docker_renovate_enabled ? local.renovate_fqdn : null
  )
}

output "registry_fqdn" {
  description = "Container Registry hostname when docker_compose and gitlab_docker_registry_enabled"
  value = (
    var.gitlab_install_mode == "docker_compose" && var.gitlab_docker_registry_enabled ? local.registry_fqdn : null
  )
}

output "registry_url" {
  description = "Container Registry URL when docker_compose and gitlab_docker_registry_enabled (https when Traefik ACME is enabled)"
  value = (
    var.gitlab_install_mode == "docker_compose" && var.gitlab_docker_registry_enabled ?
    "${local.gitlab_docker_external_url_scheme}://${local.registry_fqdn}" : null
  )
}

output "gitlab_docker_renovate_webhook_secret" {
  description = "Webhook secret for Renovate CE and GitLab project hooks (sensitive; in Terraform state)"
  value       = var.gitlab_install_mode == "docker_compose" && var.gitlab_docker_renovate_enabled ? random_password.gitlab_renovate_webhook[0].result : null
  sensitive   = true
}

output "gitlab_docker_initial_root_password" {
  description = "Initial GitLab root password in docker_compose mode (stored in Terraform state; rotate after first login)."
  value       = var.gitlab_install_mode == "docker_compose" ? random_password.gitlab_docker_root[0].result : null
  sensitive   = true
}

output "gitlab_docker_postgres_password" {
  description = "PostgreSQL password for the GitLab application DB in docker_compose mode (stored in Terraform state and cloud-init user_data)."
  value       = var.gitlab_install_mode == "docker_compose" ? random_password.gitlab_docker_postgres[0].result : null
  sensitive   = true
}

output "gitlab_devops_group_id" {
  description = "GitLab group ID from gitlab.tf when enable_gitlab_resources is true"
  value       = var.enable_gitlab_resources ? module.gitlab_api[0].devops_group_id : null
}

output "gitlab_devops_project_id" {
  description = "GitLab devops project ID from gitlab.tf when enable_gitlab_resources is true"
  value       = var.enable_gitlab_resources ? module.gitlab_api[0].devops_project_id : null
}

output "gitlab_terraform_project_id" {
  description = "GitLab terraform project ID from gitlab.tf when enable_gitlab_resources is true"
  value       = var.enable_gitlab_resources ? module.gitlab_api[0].terraform_project_id : null
}

output "gitlab_runner_ipv4" {
  description = "Public IPv4 of the GitLab Runner server when enable_gitlab_runner is true"
  value       = var.enable_gitlab_runner ? module.gitlab_runner[0].server_ipv4 : null
}

output "gitlab_runner_fqdn" {
  description = "FQDN of the GitLab Runner A record (<gitlab_runner_dns_label>.<zone>) when enable_gitlab_runner is true"
  value       = var.enable_gitlab_runner ? local.gitlab_runner_fqdn : null
}

output "gitlab_runner_ssh_connection" {
  description = "SSH command for the GitLab Runner host when enable_gitlab_runner is true"
  value       = var.enable_gitlab_runner ? module.gitlab_runner[0].ssh_connection : null
}

output "gitlab_runner_firewall_id" {
  description = "Firewall ID attached to the GitLab Runner when enable_gitlab_runner is true"
  value       = var.enable_gitlab_runner ? module.firewall_runner[0].firewall_id : null
}
