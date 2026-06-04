# Terraform working directory

Run `terraform` / `tofu` and `make` targets from the repository root (`make` uses this directory). Copy `terraform.tfvars.example` to `terraform.tfvars` (not committed).

Extended documentation: [docs/README.md](../docs/README.md).

## GitLab Pages: „Support for domains and certificates is disabled“

This message appears on GitLab **18.1+** when Pages is enabled but **`custom_domain_mode`** is unset (defaults to disabled). The Docker Compose stack terminates TLS on **Traefik** and forwards HTTP to the Pages daemon on port **8090**, so Omnibus must use **`http`** mode (not Omnibus-managed HTTPS on Pages).

### What Terraform configures

With **`gitlab_docker_pages_enabled = true`**, Cloud-Init writes in **`/opt/gitlab/data/config/gitlab.rb`** (container: `/etc/gitlab/gitlab.rb`):

```ruby
pages_external_url 'https://pages.<zone>'
gitlab_pages['enable'] = true
gitlab_pages['listen_proxy'] = '0.0.0.0:8090'
gitlab_pages['custom_domain_mode'] = 'http'
pages_nginx['enable'] = false
```

After deploy or manual edits:

```bash
cd /opt/gitlab
docker compose exec gitlab gitlab-ctl reconfigure
docker compose exec gitlab grep -A2 '^pages:' /var/opt/gitlab/gitlab-rails/etc/gitlab.yml
```

Expect under **`pages:`** something like **`custom_domain_mode: http`** (exact key depends on GitLab version).

### Fix on an existing host (before re-apply)

1. Edit **`/opt/gitlab/data/config/gitlab.rb`** on the host and add or set:
   ```ruby
   gitlab_pages['custom_domain_mode'] = 'http'
   ```
   Use **`'https'`** only if Pages itself terminates TLS (not this module — you would need `gitlab_pages['ssl_certificate']` / `ssl_certificate_key` and no Traefik TLS on Pages).

2. Reconfigure and verify:
   ```bash
   cd /opt/gitlab
   docker compose exec gitlab gitlab-ctl reconfigure
   docker compose exec gitlab gitlab-ctl status
   ```

3. Re-run the Pages pipeline or open **Deploy → Pages** in the project.

### Do not use `https` mode here without extra certs

With **`custom_domain_mode = 'https'`**, GitLab expects Pages to serve HTTPS directly. This stack uses **`listen_proxy`** + Traefik wildcard certificates — keep **`http`** unless you add a separate full TLS setup on Omnibus Pages.

More detail: [docs/pages.md](../docs/pages.md).
