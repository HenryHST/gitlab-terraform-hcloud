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
| `create_zone`        | `bool`   | `true`                                                        | no       | If `false`, use existing zone `domain_name` (data source)   |
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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_hcloud"></a> [hcloud](#requirement\_hcloud) | ~> 1.60 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_hcloud.dns"></a> [hcloud.dns](#provider\_hcloud.dns) | ~> 1.60 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_contact_value"></a> [contact\_value](#input\_contact\_value) | CAA contact record value | `string` | `"mailto:info@example.com"` | no |
| <a name="input_create_zone"></a> [create\_zone](#input\_create\_zone) | If false, look up an existing Hetzner DNS zone with domain\_name (no new zone is created) | `bool` | `true` | no |
| <a name="input_dkim_value"></a> [dkim\_value](#input\_dkim\_value) | DKIM TXT record value (will be automatically chunked if >255 characters) | `string` | `""` | no |
| <a name="input_dmarc_value"></a> [dmarc\_value](#input\_dmarc\_value) | DMARC TXT record value | `string` | `"v=DMARC1;p=quarantine;pct=100;rua=mailto:info@example.com"` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Domain name for the DNS zone | `string` | n/a | yes |
| <a name="input_enable_caa_records"></a> [enable\_caa\_records](#input\_enable\_caa\_records) | Whether to create CAA records (issue, issuewild, iodef, contact) | `bool` | `true` | no |
| <a name="input_iodef_value"></a> [iodef\_value](#input\_iodef\_value) | CAA IODEF record value | `string` | `"mailto:info@example.com"` | no |
| <a name="input_ipv4_a_record_name"></a> [ipv4\_a\_record\_name](#input\_ipv4\_a\_record\_name) | Relative hostname (zone suffix) for the A record pointing at server\_ipv4 | `string` | `"web1"` | no |
| <a name="input_mail_cname_target"></a> [mail\_cname\_target](#input\_mail\_cname\_target) | CNAME target for autoconfig and autodiscover records | `string` | `"mail.example.com"` | no |
| <a name="input_mail_ipv4"></a> [mail\_ipv4](#input\_mail\_ipv4) | Mail server IPv4 address for A record | `string` | `""` | no |
| <a name="input_mail_ipv6"></a> [mail\_ipv6](#input\_mail\_ipv6) | Mail server IPv6 address for AAAA record | `string` | `""` | no |
| <a name="input_mail_mx_value"></a> [mail\_mx\_value](#input\_mail\_mx\_value) | MX record value (priority and hostname) | `string` | `"10 mail.example.com"` | no |
| <a name="input_server_ipv4"></a> [server\_ipv4](#input\_server\_ipv4) | IPv4 address for the application A record | `string` | n/a | yes |
| <a name="input_spf_value"></a> [spf\_value](#input\_spf\_value) | SPF TXT record value | `string` | `"v=spf1 mx -all"` | no |
| <a name="input_srv_name"></a> [srv\_name](#input\_srv\_name) | SRV record name | `string` | `"_autodiscover._tcp"` | no |
| <a name="input_srv_value"></a> [srv\_value](#input\_srv\_value) | SRV record value: priority weight port target (target must end with a dot) | `string` | `"0 0 443 mail.example.com."` | no |
| <a name="input_tlsa_name"></a> [tlsa\_name](#input\_tlsa\_name) | TLSA record name | `string` | `"_25._tcp.mail.example.com"` | no |
| <a name="input_tlsa_value"></a> [tlsa\_value](#input\_tlsa\_value) | TLSA record value | `string` | `""` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_zone_authoritative_nameservers"></a> [zone\_authoritative\_nameservers](#output\_zone\_authoritative\_nameservers) | Authoritative nameservers for the DNS zone |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | ID of the DNS zone (created or existing) |
| <a name="output_zone_name"></a> [zone\_name](#output\_zone\_name) | Name of the DNS zone |
| <a name="output_zone_primary_nameservers"></a> [zone\_primary\_nameservers](#output\_zone\_primary\_nameservers) | Primary nameservers for the DNS zone |
<!-- END_TF_DOCS -->
