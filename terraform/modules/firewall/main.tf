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

  # GitLab / alternate SSH (host port 2424 → container 22)
  dynamic "rule" {
    for_each = var.enable_ssh_high ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "2424"
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

  # HTTPS Traefik Manager
  dynamic "rule" {
    for_each = var.enable_https_traefik_manager ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "5000"
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

  # Outbound DNS (TCP)
  dynamic "rule" {
    for_each = var.enable_egress_dns ? [1] : []
    content {
      direction       = "out"
      protocol        = "tcp"
      port            = "53"
      destination_ips = var.egress_destination_ips
    }
  }

  # Outbound DNS (UDP)
  dynamic "rule" {
    for_each = var.enable_egress_dns ? [1] : []
    content {
      direction       = "out"
      protocol        = "udp"
      port            = "53"
      destination_ips = var.egress_destination_ips
    }
  }

  # Outbound HTTP
  dynamic "rule" {
    for_each = var.enable_egress_http ? [1] : []
    content {
      direction       = "out"
      protocol        = "tcp"
      port            = "80"
      destination_ips = var.egress_destination_ips
    }
  }

  # Outbound HTTPS
  dynamic "rule" {
    for_each = var.enable_egress_https ? [1] : []
    content {
      direction       = "out"
      protocol        = "tcp"
      port            = "443"
      destination_ips = var.egress_destination_ips
    }
  }

  # Outbound SMTP (GitLab gitlab.rb when gitlab_smtp_enabled)
  dynamic "rule" {
    for_each = var.enable_egress_smtp ? [1] : []
    content {
      direction       = "out"
      protocol        = "tcp"
      port            = tostring(var.egress_smtp_port)
      destination_ips = var.egress_destination_ips
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
