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
