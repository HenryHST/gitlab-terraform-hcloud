#cloud-config
# Automates GitLab Omnibus on Hetzner "gitlab" app image (skips interactive /opt/hcloud/gitlab_setup.sh).
write_files:
  - path: /var/lib/gitlab-terraform/bootstrap.sh
    permissions: "0755"
    owner: root:root
    content: |
      #!/bin/bash
      set -euo pipefail
      cloud-init status --wait --long || true
      sleep ${bootstrap_wait}
      if [[ -f /root/.bashrc ]]; then
        sed -i '/gitlab_setup\\.sh/d' /root/.bashrc
        sed -i '/chmod +x \\/opt\\/hcloud\\/gitlab_setup\\.sh/d' /root/.bashrc
      fi
      sed -i "s|^external_url .*|external_url 'https://${gitlab_fqdn}'|" /etc/gitlab/gitlab.rb
      if ! grep -qE "^letsencrypt\\['enable'\\]" /etc/gitlab/gitlab.rb; then
        {
          echo ""
          echo "letsencrypt['enable'] = true"
          echo "letsencrypt['contact_emails'] = ['${letsencrypt_email}']"
        } >> /etc/gitlab/gitlab.rb
      fi
      gitlab-ctl reconfigure

runcmd:
  - [bash, -lc, /var/lib/gitlab-terraform/bootstrap.sh]
