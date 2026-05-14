# DNS Module

This Terraform module creates a Hetzner Cloud DNS zone and manages DNS records for a domain.

## Features

- Creates a primary DNS zone
- Manages various DNS record types (A, AAAA, CNAME, MX, TXT, CAA, TLSA, SRV)
- Automatic DKIM chunking for TXT records exceeding 255 characters
- Configurable CAA records for Let's Encrypt
- Mail server configuration (MX, A, AAAA, autoconfig, autodiscover)

## Usage

```hcl
module "dns" {
  source = "./modules/dns"

  domain_name = "example.com"
  server_ipv4 = "1.2.3.4"
  ipv4_a_record_name = "web1"

  # Mail server configuration
  mail_ipv4         = "91.107.238.126"
  mail_ipv6         = "2a01:4f8:1c0c:5bc1::1"
  mail_cname_target = "mail.example.com"
  mail_mx_value     = "10 mail.example.com"

  # Security records
  dmarc_value = "v=DMARC1;p=quarantine;pct=100;rua=mailto:info@example.com"
  dkim_value  = "v=DKIM1;k=rsa;t=s;s=email;p=..."
  spf_value   = "v=spf1 ip4:91.107.238.126 mx -all"

  # CAA records
  enable_caa_records = true
  iodef_value        = "mailto:info@example.com"
  contact_value      = "mailto:info@example.com"

  # TLSA and SRV records
  tlsa_name  = "_25._tcp.mail.example.com"
  tlsa_value = "3 1 1 aed2a71af8346edd13e4c0e36a9662a329cbb59cf1283573ea75d69ef9600b4f"
  srv_name   = "_autodiscover._tcp"
  srv_value  = "0 0 443 mail.example.com."
}

# Access outputs
output "dns_zone_id" {
  value = module.dns.zone_id
}
```

## Requirements

- Hetzner Cloud provider configured with `hcloud.dns` provider alias
- Required permissions: DNS zone and record management

## Provider Configuration

The module requires the `hcloud.dns` provider to be configured:

```hcl
provider "hcloud" {
  alias = "dns"
  token = var.hcloud_token
}
```

## Inputs

| Name                 | Type     | Default                                                       | Required | Description                                                 |
| -------------------- | -------- | ------------------------------------------------------------- | -------- | ----------------------------------------------------------- |
| `domain_name`        | `string` | -                                                             | yes      | Domain name for the DNS zone                                |
| `server_ipv4`        | `string` | -                                                             | yes      | IPv4 address for the application A record                   |
| `ipv4_a_record_name` | `string` | `"web1"`                                                      | no       | Relative DNS name for the A record (e.g. `web1`, `gitlab`)  |
| `dmarc_value`        | `string` | `"v=DMARC1;p=quarantine;pct=100;rua=mailto:info@example.com"` | no       | DMARC TXT record value                                      |
| `dkim_value`         | `string` | `""`                                                          | no       | DKIM TXT record value (automatically chunked if >255 chars) |
| `spf_value`          | `string` | `"v=spf1 mx -all"`                                            | no       | SPF TXT record value                                        |
| `mail_mx_value`      | `string` | `"10 mail.example.com"`                                       | no       | MX record value (priority and hostname)                     |
| `mail_ipv4`          | `string` | `""`                                                          | no       | Mail server IPv4 address for A record                       |
| `mail_ipv6`          | `string` | `""`                                                          | no       | Mail server IPv6 address for AAAA record                    |
| `mail_cname_target`  | `string` | `"mail.example.com"`                                          | no       | CNAME target for autoconfig and autodiscover                |
| `tlsa_value`         | `string` | `""`                                                          | no       | TLSA record value                                           |
| `tlsa_name`          | `string` | `"_25._tcp.mail.example.com"`                                 | no       | TLSA record name                                            |
| `srv_value`          | `string` | `"0 0 443 mail.example.com."`                                 | no       | SRV record value (priority weight port target)              |
| `srv_name`           | `string` | `"_autodiscover._tcp"`                                        | no       | SRV record name                                             |
| `iodef_value`        | `string` | `"mailto:info@example.com"`                                   | no       | CAA IODEF record value                                      |
| `contact_value`      | `string` | `"mailto:info@example.com"`                                   | no       | CAA contact record value                                    |
| `enable_caa_records` | `bool`   | `true`                                                        | no       | Whether to create CAA records                               |

## Outputs

| Name                             | Description                                |
| -------------------------------- | ------------------------------------------ |
| `zone_id`                        | ID of the created DNS zone                 |
| `zone_name`                      | Name of the DNS zone                       |
| `zone_authoritative_nameservers` | Authoritative nameservers for the DNS zone |
| `zone_primary_nameservers`       | Primary nameservers for the DNS zone       |

## DNS Records Created

The module creates the following DNS records:

- **A records**: `web1` (server), `mail` (if `mail_ipv4` provided)
- **AAAA records**: `mail` (if `mail_ipv6` provided)
- **CNAME records**: `autoconfig`, `autodiscover` (pointing to `mail_cname_target`)
- **MX records**: `mail` (if `mail_mx_value` provided)
- **TXT records**: `_dmarc`, `dkim` (chunked if needed), `@` (SPF)
- **CAA records**: `@` (issue, issuewild, iodef, contact) - if `enable_caa_records = true`
- **TLSA records**: Custom name (if `tlsa_value` provided)
- **SRV records**: Custom name (if `srv_value` provided)

## DKIM Chunking

DKIM TXT records exceeding 255 characters are automatically split into multiple records. The module handles this internally using a `locals` block that chunks the DKIM value and creates multiple `hcloud_zone_record` resources with `count`.

## Notes

- All TXT record values are automatically wrapped in double quotes as required by Hetzner DNS API
- SRV record values must follow the format: `priority weight port target` (target must end with a dot)
- CAA records are optional and can be disabled by setting `enable_caa_records = false`
- The module uses the `hcloud.dns` provider alias - ensure this is configured in your root module
