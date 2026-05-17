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
  description = "ID of the SSH key created in this module, or the first entry in attach_ssh_key_ids when create_ssh_key is false"
  value       = var.create_ssh_key ? hcloud_ssh_key.default[0].id : var.attach_ssh_key_ids[0]
}

output "ssh_key_name" {
  description = "Name of the created SSH key (empty when an existing key was attached)"
  value       = var.create_ssh_key ? hcloud_ssh_key.default[0].name : ""
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh root@${hcloud_server.main.ipv4_address}"
}
