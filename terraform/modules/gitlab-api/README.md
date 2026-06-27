# Module `gitlab-api`

Optional GitLab Provider resources for a self-managed instance. Invoked from the root only when **`enable_gitlab_resources = true`** ([`gitlab.tf`](../../gitlab.tf)).

## Resources

| Resource | Description |
|----------|-------------|
| `gitlab_group.devops_group` | Group `devops` |
| `gitlab_project.devops` | Project `devops` in the group |
| `gitlab_project.terraform` | Project `terraform` (user namespace) |
| `gitlab_user.renovate_bot` | User `renovate-bot` |
| `gitlab_group_membership.renovate_bot` | Maintainer on `devops` group |
| `gitlab_project_hook.renovate_bot` | Webhook on project `terraform` (optional) |

## Prerequisites

- GitLab reachable at **`gitlab_api_url`** (root variable; use your instance URL, not `https://gitlab.com` for self-hosted).
- **`gitlab_api_token`** with rights to create groups, projects, users, and hooks.
- Provider alias `gitlab.gitlab` from root ([`provider.tf`](../../provider.tf)).

## Renovate webhook

`create_renovate_hook` is set in root when:

- `gitlab_install_mode = "docker_compose"`
- `gitlab_docker_renovate_enabled = true`
- `enable_gitlab_resources = true`

Webhook URL: `https://<renovate_dns_label>.<domain>/webhook`
Secret: `renovate_webhook_token` (must match `MEND_RNV_WEBHOOK_SECRET` on the Renovate container).

## Usage (root)

```hcl
module "gitlab_api" {
  count  = var.enable_gitlab_resources ? 1 : 0
  source = "./modules/gitlab-api"

  providers = {
    gitlab = gitlab.gitlab
  }

  domain = var.dns_domain

  create_renovate_hook   = var.gitlab_install_mode == "docker_compose" && var.gitlab_docker_renovate_enabled
  renovate_dns_label     = var.gitlab_docker_renovate_dns_label
  renovate_webhook_token = random_password.gitlab_renovate_webhook[0].result
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `domain` | string | — | Zone / mail domain (e.g. `example.com`) |
| `create_renovate_hook` | bool | `false` | Create `gitlab_project_hook` for Renovate |
| `renovate_dns_label` | string | `renovate` | DNS label for webhook host |
| `renovate_webhook_token` | string | `""` | Webhook secret (sensitive) |

## Outputs

| Name | Description |
|------|-------------|
| `devops_group_id` | GitLab group ID |
| `devops_project_id` | Project `devops` ID |
| `terraform_project_id` | Project `terraform` ID |
| `renovate_bot_user_id` | User `renovate-bot` ID |

Root outputs: `gitlab_devops_group_id`, `gitlab_devops_project_id`, `gitlab_terraform_project_id` in [`outputs.tf`](../../outputs.tf).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_gitlab"></a> [gitlab](#requirement\_gitlab) | ~> 18.11 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_gitlab"></a> [gitlab](#provider\_gitlab) | ~> 18.11 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_create_renovate_hook"></a> [create\_renovate\_hook](#input\_create\_renovate\_hook) | Create gitlab\_project\_hook for Renovate CE when docker\_compose + renovate are enabled | `bool` | `false` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | DNS zone / mail domain for bot email addresses | `string` | n/a | yes |
| <a name="input_renovate_dns_label"></a> [renovate\_dns\_label](#input\_renovate\_dns\_label) | DNS label for Renovate webhook host | `string` | `"renovate"` | no |
| <a name="input_renovate_webhook_token"></a> [renovate\_webhook\_token](#input\_renovate\_webhook\_token) | Webhook secret (must match MEND\_RNV\_WEBHOOK\_SECRET on Renovate) | `string` | `""` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_devops_group_id"></a> [devops\_group\_id](#output\_devops\_group\_id) | n/a |
| <a name="output_devops_project_id"></a> [devops\_project\_id](#output\_devops\_project\_id) | n/a |
| <a name="output_renovate_bot_user_id"></a> [renovate\_bot\_user\_id](#output\_renovate\_bot\_user\_id) | n/a |
| <a name="output_terraform_project_id"></a> [terraform\_project\_id](#output\_terraform\_project\_id) | n/a |
<!-- END_TF_DOCS -->
