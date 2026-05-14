output "server_id" {
  description = "ID of the created server"
  value       = hcloud_server.main.id
}

output "server_name" {
  description = "Name of the server"
  value       = hcloud_server.main.name
}

output "server_ipv4" {
  description = "Public IPv4 address of the server"
  value       = hcloud_server.main.ipv4_address
}

output "server_ipv6" {
  description = "Public IPv6 address of the server"
  value       = hcloud_server.main.ipv6_address
}

output "server_status" {
  description = "Status of the server"
  value       = hcloud_server.main.status
}

output "ssh_key_id" {
  description = "ID of the created SSH key"
  value       = hcloud_ssh_key.default.id
}

output "ssh_key_name" {
  description = "Name of the SSH key"
  value       = hcloud_ssh_key.default.name
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh root@${hcloud_server.main.ipv4_address}"
}
