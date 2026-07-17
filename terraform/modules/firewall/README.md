# Firewall Module

This Terraform module creates a Hetzner Cloud Firewall with configurable rules for common services.

## Features

- Configurable standard rules (SSH 22, SSH/GitLab 2424, HTTP, HTTPS, DNS, ICMP, Node Exporter)
- Custom rules support for additional firewall rules
- Configurable source IPs for each rule
- IPv4 and IPv6 support

## Usage

### Basic Usage

```hcl
module "firewall" {
  source = "./modules/firewall"

  firewall_name = "web1-firewall"
}
```

### Advanced Usage with Custom Source IPs

```hcl
module "firewall" {
  source = "./modules/firewall"

  firewall_name = "web1-firewall"

  # Restrict SSH to specific IPs
  enable_ssh     = true
  ssh_source_ips = ["1.2.3.4/32", "5.6.7.8/32"]

  # Public HTTP/HTTPS access
  enable_http  = true
  enable_https = true

  # Disable Node Exporter public access
  enable_node_exporter = false

  # Custom rules
  custom_rules = [
    {
      direction  = "in"
      protocol   = "tcp"
      port       = "8080"
      source_ips = ["10.0.0.0/8"]
    }
  ]
}
```

## Requirements

- Hetzner Cloud provider configured

## Inputs

| Name                       | Type           | Default                 | Required | Description                                 |
| -------------------------- | -------------- | ----------------------- | -------- | ------------------------------------------- |
| `firewall_name`            | `string`       | -                       | yes      | Name of the firewall                        |
| `enable_ssh`               | `bool`         | `true`                  | no       | Enable SSH access on port 22                |
| `enable_ssh_high`          | `bool`         | `true`                  | no       | Enable TCP port 2424 (e.g. GitLab `2424:22`) |
| `ssh_source_ips`           | `list(string)` | `["0.0.0.0/0", "::/0"]` | no       | Source IPs allowed for SSH and port 2424    |
| `enable_http`              | `bool`         | `true`                  | no       | Enable HTTP access on port 80               |
| `http_source_ips`          | `list(string)` | `["0.0.0.0/0", "::/0"]` | no       | Source IPs allowed for HTTP access          |
| `enable_https`             | `bool`         | `true`                  | no       | Enable HTTPS access on port 443             |
| `https_source_ips`         | `list(string)` | `["0.0.0.0/0", "::/0"]` | no       | Source IPs allowed for HTTPS access         |
| `enable_dns`               | `bool`         | `true`                  | no       | Enable DNS access on port 53 (TCP and UDP)  |
| `dns_source_ips`           | `list(string)` | `["0.0.0.0/0", "::/0"]` | no       | Source IPs allowed for DNS access           |
| `enable_egress_dns`        | `bool`         | `true`                  | no       | Outbound DNS (TCP/UDP 53)                   |
| `enable_egress_http`       | `bool`         | `true`                  | no       | Outbound HTTP (TCP 80)                      |
| `enable_egress_https`      | `bool`         | `true`                  | no       | Outbound HTTPS (TCP 443)                    |
| `egress_destination_ips`   | `list(string)` | `["0.0.0.0/0", "::/0"]` | no       | Destinations for outbound DNS/HTTP/HTTPS    |
| `enable_egress_smtp`       | `bool`         | `false`                 | no       | Outbound SMTP (TCP on `egress_smtp_port`)   |
| `egress_smtp_port`         | `number`       | `587`                   | no       | SMTP port when egress SMTP is enabled       |
| `enable_icmp`              | `bool`         | `true`                  | no       | Enable ICMP (ping) access                   |
| `icmp_source_ips`          | `list(string)` | `["0.0.0.0/0", "::/0"]` | no       | Source IPs allowed for ICMP access          |
| `enable_node_exporter`     | `bool`         | `true`                  | no       | Enable Node Exporter metrics access         |
| `node_exporter_source_ips` | `list(string)` | `["0.0.0.0/0", "::/0"]` | no       | Source IPs allowed for Node Exporter access |
| `node_exporter_port`       | `number`       | `9100`                  | no       | Port for Node Exporter metrics              |
| `custom_rules`             | `list(object)` | `[]`                    | no       | Additional custom firewall rules            |
| `enable_https_traefik_manager` | `bool`     | `false`                 | no       | Enable inbound TCP 5000 for Traefik Manager |

### Custom Rules Object Structure

The `custom_rules` variable accepts a list of objects with the following structure:

```hcl
{
  direction       = "in" | "out"           # Required: Rule direction
  protocol        = "tcp" | "udp" | "icmp" # Required: Protocol
  port            = "8080"                  # Optional: Port (required for TCP/UDP)
  source_ips      = ["1.2.3.4/32"]         # Optional: Source IPs (default: [])
  destination_ips = ["5.6.7.8/32"]         # Optional: Destination IPs (default: [])
}
```

## Outputs

| Name            | Description                |
| --------------- | -------------------------- |
| `firewall_id`   | ID of the created firewall |
| `firewall_name` | Name of the firewall       |

## Default Rules

By default, the module creates the following firewall rules:

- **SSH** (TCP port 22) - Allowed from all IPs
- **SSH / GitLab** (TCP port 2424) - Allowed from same IPs as SSH when `enable_ssh_high` is true
- **HTTP** (TCP port 80) - Allowed from all IPs
- **HTTPS** (TCP port 443) - Allowed from all IPs
- **DNS** (TCP/UDP port 53) - Allowed from all IPs
- **ICMP** (Ping) - Allowed from all IPs
- **Node Exporter** (TCP port 9100) - Allowed from all IPs
- **Egress DNS** (TCP/UDP port 53) - Outbound to `egress_destination_ips`
- **Egress HTTP** (TCP port 80) - Outbound
- **Egress HTTPS** (TCP port 443) - Outbound
- **Egress SMTP** (TCP on `egress_smtp_port`, default 587) - Outbound when `enable_egress_smtp` is true

Inbound rules use `source_ips`; outbound rules use `destination_ips`. All can be toggled individually.

## Security Recommendations

- Restrict SSH access to specific IPs or IP ranges instead of `0.0.0.0/0`
- Consider restricting Node Exporter access to monitoring systems only
- Use custom rules for application-specific ports instead of opening all ports publicly
- Regularly review and update firewall rules based on actual requirements

## Examples

### Restrict SSH to Office IP

```hcl
module "firewall" {
  source = "./modules/firewall"

  firewall_name = "web1-firewall"
  ssh_source_ips = ["203.0.113.0/24"]  # Office IP range
}
```

### Add Custom Application Port

```hcl
module "firewall" {
  source = "./modules/firewall"

  firewall_name = "web1-firewall"

  custom_rules = [
    {
      direction  = "in"
      protocol   = "tcp"
      port       = "3000"
      source_ips = ["0.0.0.0/0", "::/0"]
    }
  ]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_hcloud"></a> [hcloud](#requirement\_hcloud) | ~> 1.66.1 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_hcloud"></a> [hcloud](#provider\_hcloud) | ~> 1.66.1 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_custom_rules"></a> [custom\_rules](#input\_custom\_rules) | Additional custom firewall rules | <pre>list(object({<br/>    direction       = string<br/>    protocol        = string<br/>    port            = optional(string)<br/>    source_ips      = optional(list(string), [])<br/>    destination_ips = optional(list(string), [])<br/>  }))</pre> | `[]` | no |
| <a name="input_dns_source_ips"></a> [dns\_source\_ips](#input\_dns\_source\_ips) | Source IPs allowed for DNS access | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_egress_destination_ips"></a> [egress\_destination\_ips](#input\_egress\_destination\_ips) | Destination IPs for outbound DNS, HTTP, and HTTPS rules | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_egress_smtp_port"></a> [egress\_smtp\_port](#input\_egress\_smtp\_port) | Outbound SMTP port when enable\_egress\_smtp is true | `number` | `587` | no |
| <a name="input_enable_dns"></a> [enable\_dns](#input\_enable\_dns) | Enable DNS access on port 53 (TCP and UDP) | `bool` | `true` | no |
| <a name="input_enable_egress_dns"></a> [enable\_egress\_dns](#input\_enable\_egress\_dns) | Allow outbound DNS (TCP and UDP port 53) | `bool` | `true` | no |
| <a name="input_enable_egress_http"></a> [enable\_egress\_http](#input\_enable\_egress\_http) | Allow outbound HTTP (TCP port 80) | `bool` | `true` | no |
| <a name="input_enable_egress_https"></a> [enable\_egress\_https](#input\_enable\_egress\_https) | Allow outbound HTTPS (TCP port 443) | `bool` | `true` | no |
| <a name="input_enable_egress_smtp"></a> [enable\_egress\_smtp](#input\_enable\_egress\_smtp) | Allow outbound SMTP (TCP on egress\_smtp\_port, e.g. 587 or 465) | `bool` | `false` | no |
| <a name="input_enable_http"></a> [enable\_http](#input\_enable\_http) | Enable HTTP access on port 80 | `bool` | `true` | no |
| <a name="input_enable_https"></a> [enable\_https](#input\_enable\_https) | Enable HTTPS access on port 443 | `bool` | `true` | no |
| <a name="input_enable_https_traefik_manager"></a> [enable\_https\_traefik\_manager](#input\_enable\_https\_traefik\_manager) | Enable inbound TCP 5000 for Traefik Manager UI | `bool` | `false` | no |
| <a name="input_enable_icmp"></a> [enable\_icmp](#input\_enable\_icmp) | Enable ICMP (ping) access | `bool` | `true` | no |
| <a name="input_enable_node_exporter"></a> [enable\_node\_exporter](#input\_enable\_node\_exporter) | Enable Node Exporter metrics access | `bool` | `true` | no |
| <a name="input_enable_ssh"></a> [enable\_ssh](#input\_enable\_ssh) | Enable SSH access on port 22 | `bool` | `true` | no |
| <a name="input_enable_ssh_high"></a> [enable\_ssh\_high](#input\_enable\_ssh\_high) | Enable SSH access on port 2424 (e.g. GitLab git/SSH via Docker 2424:22) | `bool` | `true` | no |
| <a name="input_firewall_name"></a> [firewall\_name](#input\_firewall\_name) | Name of the firewall | `string` | n/a | yes |
| <a name="input_http_source_ips"></a> [http\_source\_ips](#input\_http\_source\_ips) | Source IPs allowed for HTTP access | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_https_source_ips"></a> [https\_source\_ips](#input\_https\_source\_ips) | Source IPs allowed for HTTPS access | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_icmp_source_ips"></a> [icmp\_source\_ips](#input\_icmp\_source\_ips) | Source IPs allowed for ICMP access | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_node_exporter_port"></a> [node\_exporter\_port](#input\_node\_exporter\_port) | Port for Node Exporter metrics | `number` | `9100` | no |
| <a name="input_node_exporter_source_ips"></a> [node\_exporter\_source\_ips](#input\_node\_exporter\_source\_ips) | Source IPs allowed for Node Exporter access | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |
| <a name="input_ssh_source_ips"></a> [ssh\_source\_ips](#input\_ssh\_source\_ips) | Source IPs allowed for SSH access | `list(string)` | <pre>[<br/>  "0.0.0.0/0",<br/>  "::/0"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_firewall_id"></a> [firewall\_id](#output\_firewall\_id) | ID of the created firewall |
| <a name="output_firewall_name"></a> [firewall\_name](#output\_firewall\_name) | Name of the firewall |
<!-- END_TF_DOCS -->
