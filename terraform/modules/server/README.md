# Server Module

This Terraform module creates a Hetzner Cloud server with SSH key management, firewall attachment, and optional reverse DNS configuration.

## Features

- Creates SSH key for server access
- Creates Hetzner Cloud server with configurable type, location, and image
- Attaches firewalls to the server
- Supports Cloud-Init user data
- Optional reverse DNS (PTR) records for IPv4 and IPv6
- Configurable labels and networking options

## Usage

### Basic Usage

```hcl
module "server" {
  source = "./modules/server"

  server_name  = "web1"
  server_type  = "cx23"
  location     = "nbg1"
  ssh_public_key = var.ssh_public_key
  firewall_ids = [module.firewall.firewall_id]
}
```

### Advanced Usage with User Data and Reverse DNS

```hcl
module "server" {
  source = "./modules/server"

  server_name  = "web1"
  server_type  = "cx23"
  location     = "nbg1"
  image        = "ubuntu-24.04"
  ssh_public_key = var.ssh_public_key

  firewall_ids = [module.firewall.firewall_id]

  labels = {
    environment = "prod"
    managed_by  = "terraform"
    project     = "astro-deploy"
  }

  user_data = var.user_data # e.g. templatefile from the root module (gitlab-docker-cloud-init.yaml.tpl)

  enable_rdns      = true
  rdns_ipv4_domain = "example.com"
  rdns_ipv6_domain = "example.com"
}
```

## Requirements

- Hetzner Cloud provider configured
- Valid SSH public key

## Inputs

| Name               | Type           | Default                      | Required | Description                                    |
| ------------------ | -------------- | ---------------------------- | -------- | ---------------------------------------------- |
| `server_name`      | `string`       | -                            | yes      | Name of the server                             |
| `server_type`      | `string`       | -                            | yes      | Server type (e.g., cx23, cpx21)                |
| `location`         | `string`       | -                            | yes      | Server location (e.g., nbg1, fsn1, hel1)       |
| `image`            | `string`       | `"ubuntu-24.04"`             | no       | Operating system image                         |
| `ssh_public_key`   | `string`       | -                            | yes      | Public SSH key for server access               |
| `ssh_key_name`     | `string`       | `""`                         | no       | Name for the SSH key (auto-generated if empty) |
| `firewall_ids`     | `list(string)` | `[]`                         | no       | List of firewall IDs to attach to the server   |
| `labels`           | `map(string)`  | `{managed_by = "terraform"}` | no       | Labels to apply to the server                  |
| `user_data`        | `string`       | `""`                         | no       | Cloud-Init user data script                    |
| `enable_ipv4`      | `bool`         | `true`                       | no       | Enable IPv4 networking                         |
| `enable_ipv6`      | `bool`         | `true`                       | no       | Enable IPv6 networking                         |
| `enable_rdns`      | `bool`         | `false`                      | no       | Enable reverse DNS records                     |
| `rdns_ipv4_domain` | `string`       | `""`                         | no       | Domain name for IPv4 reverse DNS (PTR record)  |
| `rdns_ipv6_domain` | `string`       | `""`                         | no       | Domain name for IPv6 reverse DNS (PTR record)  |

## Outputs

| Name             | Description                       |
| ---------------- | --------------------------------- |
| `server_id`      | ID of the created server          |
| `server_name`    | Name of the server                |
| `server_ipv4`    | Public IPv4 address of the server |
| `server_ipv6`    | Public IPv6 address of the server |
| `server_status`  | Status of the server              |
| `ssh_key_id`     | ID of the created SSH key         |
| `ssh_key_name`   | Name of the SSH key               |
| `ssh_connection` | SSH connection command            |

## SSH Key Management

The module automatically creates an SSH key resource. The key name is auto-generated using the server name and timestamp, unless `ssh_key_name` is explicitly provided.

**Note:** If an SSH key with the same name already exists in Hetzner Cloud, you may need to delete it manually or provide a different `ssh_key_name`.

## User Data

The `user_data` input accepts a Cloud-Init script as a string. You can use Terraform's `templatefile()` function to render templates:

```hcl
user_data = templatefile("${path.module}/cloud-init.yaml", {
  variable1 = "value1"
  variable2 = "value2"
})
```

## Reverse DNS

Reverse DNS (PTR records) can be configured by setting `enable_rdns = true` and providing domain names for IPv4 and/or IPv6:

```hcl
enable_rdns      = true
rdns_ipv4_domain = "example.com"
rdns_ipv6_domain = "example.com"
```

## Examples

### Minimal Server

```hcl
module "server" {
  source = "./modules/server"

  server_name    = "web1"
  server_type    = "cx23"
  location       = "nbg1"
  ssh_public_key = var.ssh_public_key
}
```

### Server with Firewall and Labels

```hcl
module "server" {
  source = "./modules/server"

  server_name    = "web1"
  server_type    = "cx23"
  location       = "nbg1"
  ssh_public_key = var.ssh_public_key
  firewall_ids   = [module.firewall.firewall_id]

  labels = {
    environment = "production"
    role        = "web-server"
  }
}
```

### Server with Custom Image

```hcl
module "server" {
  source = "./modules/server"

  server_name    = "web1"
  server_type    = "cx23"
  location       = "nbg1"
  image          = "debian-12"
  ssh_public_key = var.ssh_public_key
}
```

## Notes

- The SSH key name includes a timestamp to ensure uniqueness
- The module uses `lifecycle { ignore_changes = [name] }` on the SSH key to prevent recreation on every apply
- User data is passed directly to Cloud-Init - ensure proper formatting
- Reverse DNS is optional and disabled by default
- Multiple firewalls can be attached by providing multiple IDs in `firewall_ids`

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_hcloud"></a> [hcloud](#requirement\_hcloud) | ~> 1.60 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_hcloud"></a> [hcloud](#provider\_hcloud) | ~> 1.60 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_attach_ssh_key_ids"></a> [attach\_ssh\_key\_ids](#input\_attach\_ssh\_key\_ids) | Existing Hetzner SSH key IDs to attach to the server when create\_ssh\_key is false | `list(string)` | `[]` | no |
| <a name="input_create_ssh_key"></a> [create\_ssh\_key](#input\_create\_ssh\_key) | If true, create an hcloud\_ssh\_key from ssh\_public\_key. If false, attach existing keys via attach\_ssh\_key\_ids (avoids Hetzner uniqueness\_error when the same key is reused). | `bool` | `true` | no |
| <a name="input_enable_ipv4"></a> [enable\_ipv4](#input\_enable\_ipv4) | Enable IPv4 networking | `bool` | `true` | no |
| <a name="input_enable_ipv6"></a> [enable\_ipv6](#input\_enable\_ipv6) | Enable IPv6 networking | `bool` | `true` | no |
| <a name="input_enable_rdns"></a> [enable\_rdns](#input\_enable\_rdns) | Enable reverse DNS records | `bool` | `false` | no |
| <a name="input_firewall_ids"></a> [firewall\_ids](#input\_firewall\_ids) | List of firewall IDs to attach to the server | `list(string)` | `[]` | no |
| <a name="input_image"></a> [image](#input\_image) | Operating system image | `string` | `"ubuntu-24.04"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the server | `map(string)` | <pre>{<br/>  "managed_by": "terraform"<br/>}</pre> | no |
| <a name="input_location"></a> [location](#input\_location) | Server location (e.g., nbg1, fsn1, hel1) | `string` | n/a | yes |
| <a name="input_rdns_ipv4_domain"></a> [rdns\_ipv4\_domain](#input\_rdns\_ipv4\_domain) | Domain name for IPv4 reverse DNS (PTR record) | `string` | `""` | no |
| <a name="input_rdns_ipv6_domain"></a> [rdns\_ipv6\_domain](#input\_rdns\_ipv6\_domain) | Domain name for IPv6 reverse DNS (PTR record) | `string` | `""` | no |
| <a name="input_server_name"></a> [server\_name](#input\_server\_name) | Name of the server | `string` | n/a | yes |
| <a name="input_server_type"></a> [server\_type](#input\_server\_type) | Server type (e.g., cx23, cpx21) | `string` | n/a | yes |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | Name for the SSH key (auto-generated if empty) | `string` | `""` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | Public SSH key for server access (used only when create\_ssh\_key is true) | `string` | `""` | no |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | Cloud-Init user data script | `string` | `""` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | ID of the created server |
| <a name="output_server_ipv4"></a> [server\_ipv4](#output\_server\_ipv4) | Public IPv4 address of the server |
| <a name="output_server_ipv6"></a> [server\_ipv6](#output\_server\_ipv6) | Public IPv6 address of the server |
| <a name="output_server_name"></a> [server\_name](#output\_server\_name) | Name of the server |
| <a name="output_server_status"></a> [server\_status](#output\_server\_status) | Status of the server |
| <a name="output_ssh_connection"></a> [ssh\_connection](#output\_ssh\_connection) | SSH connection command |
| <a name="output_ssh_key_id"></a> [ssh\_key\_id](#output\_ssh\_key\_id) | ID of the SSH key created in this module, or the first entry in attach\_ssh\_key\_ids when create\_ssh\_key is false |
| <a name="output_ssh_key_name"></a> [ssh\_key\_name](#output\_ssh\_key\_name) | Name of the created SSH key (empty when an existing key was attached) |
<!-- END_TF_DOCS -->
