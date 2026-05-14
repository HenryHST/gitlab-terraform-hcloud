# SSH Key für Server-Zugriff (optional: reuse an existing key via attach_ssh_key_ids)
resource "hcloud_ssh_key" "default" {
  count = var.create_ssh_key ? 1 : 0

  name       = var.ssh_key_name != "" ? var.ssh_key_name : "${var.server_name}-key"
  public_key = var.ssh_public_key

  lifecycle {
    ignore_changes = [name]
  }
}

# Server
resource "hcloud_server" "main" {
  name        = var.server_name
  server_type = var.server_type
  location    = var.location
  image       = var.image
  labels      = var.labels
  ssh_keys    = var.create_ssh_key ? [hcloud_ssh_key.default[0].id] : var.attach_ssh_key_ids

  firewall_ids = var.firewall_ids

  user_data = var.user_data

  public_net {
    ipv4_enabled = var.enable_ipv4
    ipv6_enabled = var.enable_ipv6
  }
}

# Reverse DNS (optional)
resource "hcloud_rdns" "ipv4" {
  count      = var.enable_rdns && var.rdns_ipv4_domain != "" ? 1 : 0
  server_id  = hcloud_server.main.id
  ip_address = hcloud_server.main.ipv4_address
  dns_ptr    = var.rdns_ipv4_domain
}

resource "hcloud_rdns" "ipv6" {
  count      = var.enable_rdns && var.rdns_ipv6_domain != "" ? 1 : 0
  server_id  = hcloud_server.main.id
  ip_address = hcloud_server.main.ipv6_address
  dns_ptr    = var.rdns_ipv6_domain
}
