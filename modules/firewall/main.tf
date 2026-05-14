resource "hcloud_firewall" "main" {
  name = var.firewall_name

  # SSH
  dynamic "rule" {
    for_each = var.enable_ssh ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "22"
      source_ips = var.ssh_source_ips
    }
  }

  # HTTP
  dynamic "rule" {
    for_each = var.enable_http ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "80"
      source_ips = var.http_source_ips
    }
  }

  # HTTPS
  dynamic "rule" {
    for_each = var.enable_https ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "443"
      source_ips = var.https_source_ips
    }
  }

  # DNS (TCP)
  dynamic "rule" {
    for_each = var.enable_dns ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "53"
      source_ips = var.dns_source_ips
    }
  }

  # DNS (UDP)
  dynamic "rule" {
    for_each = var.enable_dns ? [1] : []
    content {
      direction  = "in"
      protocol   = "udp"
      port       = "53"
      source_ips = var.dns_source_ips
    }
  }

  # Node Exporter Metrics
  dynamic "rule" {
    for_each = var.enable_node_exporter ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = tostring(var.node_exporter_port)
      source_ips = var.node_exporter_source_ips
    }
  }

  # ICMP (Ping)
  dynamic "rule" {
    for_each = var.enable_icmp ? [1] : []
    content {
      direction  = "in"
      protocol   = "icmp"
      source_ips = var.icmp_source_ips
    }
  }

  # Custom rules
  dynamic "rule" {
    for_each = var.custom_rules
    content {
      direction       = rule.value.direction
      protocol        = rule.value.protocol
      port            = lookup(rule.value, "port", null)
      source_ips      = lookup(rule.value, "source_ips", [])
      destination_ips = lookup(rule.value, "destination_ips", [])
    }
  }
}
